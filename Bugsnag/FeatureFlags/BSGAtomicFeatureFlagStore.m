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

static _Atomic(struct bsg_feature_flag_list_item *) g_feature_flags_head;
static _Atomic(struct bsg_feature_flag_list_item *) g_feature_flags_tail;
static atomic_bool g_writing_crash_report;

// The list above is global, so all instances share this lock and this index.
static NSObject *g_lock;
static NSMutableDictionary<NSString *, NSValue *> *nameToFlag;

/**
 * Writers keep one rule: every pointer they publish (the head or an item's next) points at a fully
 * built item, and an item is only freed once no published pointer reaches it. The crash-time
 * reader, which takes no locks and allocates nothing, therefore always walks a complete list:
 * either the one from before an update or the one from after it.
 *
 * Duplicate names follow BSGMemoryFeatureFlagStore: adding a name that is already present replaces
 * its variant and keeps the flag in the position where the name was first added.
 */
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
        return atomic_load(&g_feature_flags_head) == NULL;
    }
}

- (void)addFeatureFlag:(nonnull NSString *)name withVariant:(nullable NSString *)variant {
    @synchronized (g_lock) {
        [self _setFeatureFlag:name withVariant:variant];
    }
}

- (void)addFeatureFlags:(nonnull NSArray<BugsnagFeatureFlag *> *)featureFlags {
    @synchronized (g_lock) {
        for (BugsnagFeatureFlag *flag in featureFlags) {
            [self _setFeatureFlag:flag.name withVariant:flag.variant];
        }
    }
}

- (void)clear:(nullable NSString *)name {
    @synchronized (g_lock) {
        if (name != nil) {
            [self _removeFeatureFlagWithName:name];
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
        // Apply the duplicate-name rule first so that the new list holds each name once.
        NSMutableArray<NSString *> *names = [NSMutableArray arrayWithCapacity:featureFlags.count];
        NSMutableDictionary<NSString *, id> *variants = [NSMutableDictionary dictionaryWithCapacity:featureFlags.count];
        for (BugsnagFeatureFlag *flag in featureFlags) {
            if (!variants[flag.name]) {
                [names addObject:flag.name];
            }
            variants[flag.name] = flag.variant ?: [NSNull null];
        }

        // Build the new list off to the side, where the crash-time reader cannot see it.
        struct bsg_feature_flag_list_item *newHead = NULL;
        struct bsg_feature_flag_list_item *newTail = NULL;
        NSMutableDictionary<NSString *, NSValue *> *newNameToFlag = [NSMutableDictionary dictionaryWithCapacity:names.count];
        for (NSString *name in names) {
            id variant = variants[name];
            struct bsg_feature_flag_list_item *item =
            [self _newItemForFeatureFlagWithName:name variant:variant == [NSNull null] ? nil : variant];
            if (!item) {
                continue;
            }
            item->previous = newTail;
            if (newTail) {
                atomic_store(&newTail->next, item);
            } else {
                newHead = item;
            }
            newTail = item;
            newNameToFlag[name] = [NSValue valueWithPointer:item];
        }

        // Publish the new list with a single pointer swap, then free the old one, which is no longer reachable.
        [self _awaitAtomicFeatureFlagsLockIfNeeded];
        struct bsg_feature_flag_list_item *oldHead = atomic_exchange(&g_feature_flags_head, newHead);
        atomic_store(&g_feature_flags_tail, newTail);
        nameToFlag = newNameToFlag;
        [self _freeList:oldHead];
    }
}

#pragma mark - Private methods

- (void)_awaitAtomicFeatureFlagsLockIfNeeded {
    while (atomic_load(&g_writing_crash_report)) { continue; }
}

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

- (void)_setFeatureFlag:(nonnull NSString *)name withVariant:(nullable NSString *)variant {
    struct bsg_feature_flag_list_item *newItem = [self _newItemForFeatureFlagWithName:name variant:variant];
    if (!newItem) {
        return;
    }
    struct bsg_feature_flag_list_item *oldItem = [nameToFlag[name] pointerValue];
    if (oldItem) {
        // Swap the new item into the old item's position. The new item is fully linked before the
        // single store that makes it reachable, and the old item becomes unreachable in that same store.
        struct bsg_feature_flag_list_item *previous = oldItem->previous;
        struct bsg_feature_flag_list_item *next = atomic_load(&oldItem->next);
        newItem->previous = previous;
        atomic_store(&newItem->next, next);
        [self _awaitAtomicFeatureFlagsLockIfNeeded];
        if (previous) {
            atomic_store(&previous->next, newItem);
        } else {
            atomic_store(&g_feature_flags_head, newItem);
        }
        if (next) {
            next->previous = newItem;
        } else {
            atomic_store(&g_feature_flags_tail, newItem);
        }
        [self _awaitAtomicFeatureFlagsLockIfNeeded];
        free(oldItem);
    } else {
        struct bsg_feature_flag_list_item *tail = atomic_load(&g_feature_flags_tail);
        newItem->previous = tail;
        [self _awaitAtomicFeatureFlagsLockIfNeeded];
        if (tail) {
            atomic_store(&tail->next, newItem);
        } else {
            atomic_store(&g_feature_flags_head, newItem);
        }
        atomic_store(&g_feature_flags_tail, newItem);
    }
    nameToFlag[name] = [NSValue valueWithPointer:newItem];
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

- (void)_removeFeatureFlagWithName:(NSString *)name {
    struct bsg_feature_flag_list_item *flag = [nameToFlag[name] pointerValue];
    if (flag) {
        struct bsg_feature_flag_list_item *previous = flag->previous;
        struct bsg_feature_flag_list_item *next = atomic_load(&flag->next);
        [self _awaitAtomicFeatureFlagsLockIfNeeded];
        if (previous) {
            atomic_store(&previous->next, next);
        } else {
            atomic_store(&g_feature_flags_head, next);
        }
        if (next) {
            next->previous = previous;
        } else {
            atomic_store(&g_feature_flags_tail, previous);
        }
        [self _awaitAtomicFeatureFlagsLockIfNeeded];
        free(flag);
        nameToFlag[name] = nil;
    }
}

- (void)_clearAll {
    [self _awaitAtomicFeatureFlagsLockIfNeeded];
    struct bsg_feature_flag_list_item *item = atomic_exchange(&g_feature_flags_head, NULL);
    atomic_store(&g_feature_flags_tail, NULL);
    nameToFlag = [NSMutableDictionary dictionary];
    [self _freeList:item];
}

- (void)_freeList:(struct bsg_feature_flag_list_item *)item {
    [self _awaitAtomicFeatureFlagsLockIfNeeded];
    while (item) {
        struct bsg_feature_flag_list_item *next = atomic_load(&item->next);
        free(item);
        item = next;
    }
}

@end

void BugsnagFeatureFlagsWriteCrashReport(const BSG_KSCrashReportWriter *writer,
                                        bool __unused requiresAsyncSafety) {
    atomic_store(&g_writing_crash_report, true);
    
    writer->beginArray(writer, "featureFlags");
    
    struct bsg_feature_flag_list_item *item = atomic_load(&g_feature_flags_head);
    while (item) {
        writer->addJSONElement(writer, NULL, item->jsonData);
        item = atomic_load(&item->next);
    }
    
    writer->endContainer(writer);
    
    atomic_store(&g_writing_crash_report, false);
}
