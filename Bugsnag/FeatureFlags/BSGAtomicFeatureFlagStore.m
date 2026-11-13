//
//  BSGAtomicFeatureFlagStore.m
//  Bugsnag
//
//  Created by Robert B on 16/12/2024.
//  Copyright © 2024 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BSGAtomicFeatureFlagStore.h"
#import "BSGJSONSerialization.h"
#import "BugsnagLogger.h"
#import "BSGKeys.h"

#import <stdatomic.h>

struct bsg_feature_flag_list_item {
    // Only "next" is followed by the crash-time reader, so it is the only link that has to be atomic.
    _Atomic(struct bsg_feature_flag_list_item *) next;
    struct bsg_feature_flag_list_item *previous;
    char jsonData[]; // MUST be null terminated
};

// A doubly linked list of items. Only the global list (g_list) is ever visible to the crash-time reader;
// replaceAllFlags: builds a new list off to the side before publishing it.
struct bsg_feature_flag_list {
    _Atomic(struct bsg_feature_flag_list_item *) head;
    _Atomic(struct bsg_feature_flag_list_item *) tail;
};

static struct bsg_feature_flag_list g_list;
// The number of crash-time readers walking the list. It is a count rather than a flag because several
// reports can be written at the same time (e.g. a crash while an app hang report is being written), and
// an item must not be freed until the last of them has finished.
static atomic_int g_crash_report_readers;

// The crash-time reader must not take locks, so these atomics must be lock-free on every platform.
_Static_assert(ATOMIC_POINTER_LOCK_FREE == 2, "Feature flag list pointers must be lock-free");
_Static_assert(ATOMIC_INT_LOCK_FREE == 2, "g_crash_report_readers must be lock-free");

// The list above is global, so all instances share this lock and this index.
static NSObject *g_lock;
static NSMutableDictionary<NSString *, NSValue *> *nameToFlag;

/**
 * Writers keep one rule: every pointer they publish (the head or an item's next) points at a fully
 * built item, and an item is only freed once no published pointer reaches it. The crash-time
 * reader, which takes no locks and allocates nothing, therefore always walks a complete list:
 * either the one from before an update or the one from after it.
 *
 * Publishing needs no wait. An item is fully built (including its next pointer) before the single
 * atomic store that makes it reachable, so a reader that loads the pointer before that store sees the
 * old list and one that loads it afterwards sees the new item; both are complete lists, and nothing the
 * reader can reach has been freed. A reader on an item that is being unlinked keeps following that
 * item's next pointer, which is not changed, so it also stays on a complete list.
 *
 * Freeing is the only step that waits, and it is safe because of the order of the sequentially consistent
 * operations on each side. A reader increments g_crash_report_readers before it loads the head and
 * decrements it once it has finished with the list, and a writer makes an item unreachable before it
 * checks that the count is zero (in BSGAwaitCrashReportReaders) and frees it. So either the writer sees a
 * reader that may still reach the item and waits until every reader has finished, or the reader's
 * increment comes after the writer's check in the total order, so all of its loads come after the store
 * that unlinked the item and it can never reach it. Because readers are counted, one reader finishing does
 * not let a writer free an item that another reader is still walking.
 *
 * Duplicate names follow BSGMemoryFeatureFlagStore: adding a name that is already present replaces
 * its variant and keeps the flag in the position where the name was first added. That rule is applied in
 * one place, BSGListSetItem, which every method (including replaceAllFlags:, which builds its new list with
 * it) uses, because any of them can be passed duplicate names: addFeatureFlags: is passed the app's array.
 */

/// Waits until no crash-time reader is walking the list. Called between unlinking items and freeing them.
static void BSGAwaitCrashReportReaders(void) {
    while (atomic_load(&g_crash_report_readers) > 0) { continue; }
}

/// Frees an item that has been unlinked. If the list is published, crash-time readers may still be on it.
static void BSGFreeUnlinkedItem(struct bsg_feature_flag_list_item *item, BOOL published) {
    if (published) {
        BSGAwaitCrashReportReaders();
    }
    free(item);
}

/// Unlinks an item from a list, without freeing it.
static void BSGListUnlink(struct bsg_feature_flag_list *list, struct bsg_feature_flag_list_item *item) {
    struct bsg_feature_flag_list_item *previous = item->previous;
    struct bsg_feature_flag_list_item *next = atomic_load(&item->next);
    if (previous) {
        atomic_store(&previous->next, next);
    } else {
        atomic_store(&list->head, next);
    }
    if (next) {
        next->previous = previous;
    } else {
        atomic_store(&list->tail, previous);
    }
}

/// Adds a new item to a list, or swaps it into the position of the item with the same name.
static void BSGListSetItem(struct bsg_feature_flag_list *list, NSMutableDictionary<NSString *, NSValue *> *index,
                           NSString *name, struct bsg_feature_flag_list_item *newItem, BOOL published) {
    struct bsg_feature_flag_list_item *oldItem = [index[name] pointerValue];
    if (oldItem) {
        // The new item is fully linked before the single store that makes it reachable, and the old item
        // becomes unreachable in that same store.
        struct bsg_feature_flag_list_item *previous = oldItem->previous;
        struct bsg_feature_flag_list_item *next = atomic_load(&oldItem->next);
        newItem->previous = previous;
        atomic_store(&newItem->next, next);
        if (previous) {
            atomic_store(&previous->next, newItem);
        } else {
            atomic_store(&list->head, newItem);
        }
        if (next) {
            next->previous = newItem;
        } else {
            atomic_store(&list->tail, newItem);
        }
        BSGFreeUnlinkedItem(oldItem, published);
    } else {
        struct bsg_feature_flag_list_item *tail = atomic_load(&list->tail);
        newItem->previous = tail;
        if (tail) {
            atomic_store(&tail->next, newItem);
        } else {
            atomic_store(&list->head, newItem);
        }
        atomic_store(&list->tail, newItem);
    }
    index[name] = [NSValue valueWithPointer:newItem];
}

/// Removes the item with a name from a list, if there is one, and frees it.
static void BSGListRemove(struct bsg_feature_flag_list *list, NSMutableDictionary<NSString *, NSValue *> *index,
                          NSString *name, BOOL published) {
    struct bsg_feature_flag_list_item *item = [index[name] pointerValue];
    if (item) {
        BSGListUnlink(list, item);
        BSGFreeUnlinkedItem(item, published);
        index[name] = nil;
    }
}

/// Frees a list of items that is no longer reachable from a published pointer, after waiting for any
/// crash-time readers that may still be walking it.
static void BSGFreeList(struct bsg_feature_flag_list_item *item) {
    BSGAwaitCrashReportReaders();
    while (item) {
        struct bsg_feature_flag_list_item *next = atomic_load(&item->next);
        free(item);
        item = next;
    }
}

@implementation BSGAtomicFeatureFlagStore

+ (void)initialize {
    if (self == [BSGAtomicFeatureFlagStore class]) {
        g_lock = [NSObject new];
        nameToFlag = [NSMutableDictionary dictionary];
    }
}

+ (instancetype)store {
    return [self new];
}

#pragma mark - BSGFeatureFlagStore

- (nonnull NSArray<BugsnagFeatureFlag *> *)allFlags {
    return @[]; // This method should never be used with an atomic store. Please use BugsnagFeatureFlagsWriteCrashReport to serialize the data with a writer instead
}

- (BOOL)isEmpty {
    @synchronized (g_lock) {
        return atomic_load(&g_list.head) == NULL;
    }
}

- (void)addFeatureFlag:(nonnull NSString *)name withVariant:(nullable NSString *)variant {
    @synchronized (g_lock) {
        [self _setFeatureFlag:name withVariant:variant inList:&g_list index:nameToFlag published:YES];
    }
}

- (void)addFeatureFlags:(nonnull NSArray<BugsnagFeatureFlag *> *)featureFlags {
    @synchronized (g_lock) {
        for (BugsnagFeatureFlag *flag in featureFlags) {
            [self _setFeatureFlag:flag.name withVariant:flag.variant inList:&g_list index:nameToFlag published:YES];
        }
    }
}

- (void)clear:(nullable NSString *)name {
    @synchronized (g_lock) {
        if (name != nil) {
            BSGListRemove(&g_list, nameToFlag, (NSString *_Nonnull)name, YES);
        } else {
            [self _clearAll];
        }
    }
}

- (void)clear {
    @synchronized (g_lock) {
        [self _clearAll];
    }
}

- (void)replaceAllFlags:(nonnull NSArray<BugsnagFeatureFlag *> *)featureFlags {
    @synchronized (g_lock) {
        // Build the new list off to the side, where the crash-time reader cannot see it, applying the
        // duplicate-name rule as addFeatureFlags: does, so that the new list holds each name once.
        struct bsg_feature_flag_list newList = {NULL, NULL};
        NSMutableDictionary<NSString *, NSValue *> *newNameToFlag = [NSMutableDictionary dictionaryWithCapacity:featureFlags.count];
        for (BugsnagFeatureFlag *flag in featureFlags) {
            [self _setFeatureFlag:flag.name withVariant:flag.variant inList:&newList index:newNameToFlag published:NO];
        }

        // Publish the new list with a single pointer swap, then free the old one, which is no longer reachable.
        struct bsg_feature_flag_list_item *oldHead = atomic_exchange(&g_list.head, atomic_load(&newList.head));
        atomic_store(&g_list.tail, atomic_load(&newList.tail));
        nameToFlag = newNameToFlag;
        BSGFreeList(oldHead);
    }
}

#pragma mark - Private methods

- (struct bsg_feature_flag_list_item *)_newItemForFeatureFlagWithName:(nonnull NSString *)name variant:(nullable NSString *)variant {
    NSData *data = [self _dataForFeatureFlagWithName:name variant:variant];
    if (!data) {
        return NULL;
    }
    struct bsg_feature_flag_list_item *item = calloc(1, sizeof(struct bsg_feature_flag_list_item) + data.length + 1);
    if (!item) {
        return NULL;
    }
    [data getBytes:item->jsonData length:data.length];
    return item;
}

- (void)_setFeatureFlag:(nonnull NSString *)name withVariant:(nullable NSString *)variant
                 inList:(struct bsg_feature_flag_list *)list
                  index:(NSMutableDictionary<NSString *, NSValue *> *)index
              published:(BOOL)published {
    struct bsg_feature_flag_list_item *newItem = [self _newItemForFeatureFlagWithName:name variant:variant];
    if (!newItem) {
        // The new value cannot be serialized. Remove any earlier value so that a crash report leaves the flag
        // out rather than reporting a variant the app has replaced. This matches the persistent store.
        BSGListRemove(list, index, name, published);
        return;
    }
    BSGListSetItem(list, index, name, newItem, published);
}

- (NSData *)_dataForFeatureFlagWithName:(nonnull NSString *)name variant:(nullable NSString *)variant {
    NSData *data = nil;
    NSError *error = nil;
    NSMutableDictionary *json = [NSMutableDictionary new];
    json[BSGKeyFeatureFlag] = name;
    if (variant) {
        json[BSGKeyVariant] = variant;
    }
    if (!json || !(data = BSGJSONDataFromDictionary(json, &error))) {
        bsg_log_err(@"Unable to serialize feature flag: %@", error);
    }
    return data;
}

- (void)_clearAll {
    struct bsg_feature_flag_list_item *item = atomic_exchange(&g_list.head, NULL);
    atomic_store(&g_list.tail, NULL);
    nameToFlag = [NSMutableDictionary dictionary];
    BSGFreeList(item);
}

@end

void BugsnagFeatureFlagsWriteCrashReport(const BSG_KSCrashReportWriter *writer,
                                        bool __unused requiresAsyncSafety) {
    atomic_fetch_add(&g_crash_report_readers, 1);

    writer->beginArray(writer, "featureFlags");
    
    struct bsg_feature_flag_list_item *item = atomic_load(&g_list.head);
    while (item) {
        writer->addJSONElement(writer, NULL, item->jsonData);
        item = atomic_load(&item->next);
    }
    
    writer->endContainer(writer);

    atomic_fetch_sub(&g_crash_report_readers, 1);
}
