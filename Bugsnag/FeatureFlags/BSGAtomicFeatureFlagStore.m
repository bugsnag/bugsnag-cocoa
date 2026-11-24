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
    // The only link the crash-time reader follows, so the only one that must be atomic.
    _Atomic(struct bsg_feature_flag_list_item *) next;
    // Writers only: the previous item or, once retired (BSGRetireItem), the item retired before it.
    struct bsg_feature_flag_list_item *previous;
    char jsonData[]; // MUST be null terminated
};

// Only g_list is visible to the crash-time reader; replaceAllFlags: builds its new list privately, then publishes it.
struct bsg_feature_flag_list {
    _Atomic(struct bsg_feature_flag_list_item *) head;
    _Atomic(struct bsg_feature_flag_list_item *) tail;
};

static struct bsg_feature_flag_list g_list;
// Crash-time readers walking the list. A count, not a flag: several reports can be written at once (crashes on two
// threads, or a crash inside the crash handler), and items are freed only after the last one finishes.
static atomic_int g_crash_report_readers;

// The crash-time reader must not take locks, so these atomics must be lock-free on every platform.
_Static_assert(ATOMIC_POINTER_LOCK_FREE == 2, "Feature flag list pointers must be lock-free");
_Static_assert(ATOMIC_INT_LOCK_FREE == 2, "g_crash_report_readers must be lock-free");

// The list above is global, so all instances share this lock and this index.
static NSObject *g_lock;
static NSMutableDictionary<NSString *, NSValue *> *nameToFlag;

// Items unlinked from g_list but not yet freed, as a crash-time reader may be on them. Guarded by g_lock. Chained
// through `previous`, which readers never follow, so chaining changes nothing a reader can see.
static struct bsg_feature_flag_list_item *g_retired;
#if defined(DEBUG) && DEBUG
// Length of g_retired, for BSGAtomicFeatureFlagStoreRetiredItemCount. Guarded by g_lock; freeing does not use it.
static size_t g_retiredCount;
#endif

/**
 * The crash-time reader (BugsnagFeatureFlagsWriteCrashReport) takes no locks and allocates nothing. Writers, holding
 * g_lock, keep these invariants so that it never reads a partly built or freed item:
 *
 * 1. Every published pointer (the head or an item's next) points at a fully built item, and each store that makes a
 *    new item reachable is preceded by BSGPublishFence.
 * 2. An unlinked item's next is never changed, and no write stores a pointer to an already unlinked item.
 * 3. Items unlinked from g_list are retired (BSGRetireItem), not freed. Each write ends with
 *    BSGFreeRetiredItemsIfNoReaders, which loads g_crash_report_readers after the unlinking stores of this and every
 *    earlier write (g_lock serializes them) and frees all retired items only if it reads 0, so writers never wait.
 *    Items of a list that replaceAllFlags: is still building are unreachable, so are freed at once.
 * 4. A reader increments g_crash_report_readers before loading the head and decrements it after its last item.
 * 5. Every operation on g_crash_report_readers, the head and next pointers is sequentially consistent (the atomic_*
 *    default); acquire/release alone is not enough. In that total order, a count of 0 means every reader counted
 *    before the load has finished. A reader counted after it loads only pointers stored after the unlinking, so by
 *    (2) it reaches only items still linked then, and later writes do not free those while it is counted.
 *
 * A reader is not guaranteed one consistent list: on an unlinked item it keeps following that item's next, so a flag
 * cleared (or dropped as unserializable) and added again during a read can appear twice. The crash handler stops
 * other threads while writing, so this needs two simultaneous crashes.
 *
 * The argument above uses C11's rules for threads, so it covers readers on other threads. Two cases fall outside
 * them; in both the reader is expected to see a prefix of the writer's steps, each of which leaves the list safe to
 * walk:
 * - A signal handler interrupting a writer on its own thread. C11 does not order a thread's operations with its own
 *   handler (and leaves non-atomic values unspecified there), but atomic_signal_fence (BSGPublishFence) guarantees
 *   that the item's contents are ordered before the publishing store for it. The fence only constrains the compiler
 *   and costs nothing at run time.
 * - A writer suspended mid-write by the crash handler. C11 does not describe suspending a thread, so this is not
 *   formally covered; it relies on the Mach behaviour KSCrash depends on throughout: a suspended thread's completed
 *   stores are visible to the thread that suspended it.
 *
 * If a reader never decrements (e.g. the app crashes again while writing a report), retired items are never freed:
 * memory is kept until exit, never reused.
 *
 * The duplicate-name rule (see BSGFeatureFlagStore.h) is applied only in BSGListSetItem, which every method uses,
 * including replaceAllFlags:, because any of them can be passed the app's duplicate names.
 */

/// Adds an item unlinked from g_list to g_retired, to be freed once no reader can be on it. Requires g_lock.
static void BSGRetireItem(struct bsg_feature_flag_list_item *item) {
    item->previous = g_retired;
    g_retired = item;
#if defined(DEBUG) && DEBUG
    g_retiredCount++;
#endif
}

/// Frees the retired items unless a crash-time reader is counted. Call at the end of every write, with g_lock held.
static void BSGFreeRetiredItemsIfNoReaders(void) {
    if (!g_retired || atomic_load(&g_crash_report_readers) != 0) {
        return;
    }
    while (g_retired) {
        struct bsg_feature_flag_list_item *previous = g_retired->previous;
        free(g_retired);
        g_retired = previous;
    }
#if defined(DEBUG) && DEBUG
    g_retiredCount = 0;
#endif
}

/// Frees an unlinked item, or retires it if it came from g_list, where crash-time readers may still be on it.
static void BSGFreeUnlinkedItem(struct bsg_feature_flag_list *list, struct bsg_feature_flag_list_item *item) {
    if (list == &g_list) {
        BSGRetireItem(item);
    } else {
        free(item);
    }
}

/// Call before each store that makes an item reachable, for a crash-time reader in a signal handler on this thread.
static inline void BSGPublishFence(void) {
    atomic_signal_fence(memory_order_seq_cst);
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
                           NSString *name, struct bsg_feature_flag_list_item *newItem) {
    struct bsg_feature_flag_list_item *oldItem = [index[name] pointerValue];
    if (oldItem) {
        // One store both publishes the fully linked new item and unlinks the old one.
        struct bsg_feature_flag_list_item *previous = oldItem->previous;
        struct bsg_feature_flag_list_item *next = atomic_load(&oldItem->next);
        newItem->previous = previous;
        atomic_store(&newItem->next, next);
        BSGPublishFence();
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
        BSGFreeUnlinkedItem(list, oldItem);
    } else {
        struct bsg_feature_flag_list_item *tail = atomic_load(&list->tail);
        newItem->previous = tail;
        BSGPublishFence();
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
                          NSString *name) {
    struct bsg_feature_flag_list_item *item = [index[name] pointerValue];
    if (item) {
        BSGListUnlink(list, item);
        BSGFreeUnlinkedItem(list, item);
        index[name] = nil;
    }
}

/// Retires a list that is no longer published but that crash-time readers may still be walking.
static void BSGRetireList(struct bsg_feature_flag_list_item *item) {
    while (item) {
        // Retiring reuses previous and leaves next unchanged
        struct bsg_feature_flag_list_item *next = atomic_load(&item->next);
        BSGRetireItem(item);
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

/// Always the same instance: the crash handler reads one list, so the list, index and lock are process-wide.
+ (instancetype)store {
    static BSGAtomicFeatureFlagStore *store;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        store = [self new];
    });
    return store;
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
        [self _setFeatureFlag:name withVariant:variant inList:&g_list index:nameToFlag];
        BSGFreeRetiredItemsIfNoReaders();
    }
}

- (void)addFeatureFlags:(nonnull NSArray<BugsnagFeatureFlag *> *)featureFlags {
    @synchronized (g_lock) {
        for (BugsnagFeatureFlag *flag in featureFlags) {
            [self _setFeatureFlag:flag.name withVariant:flag.variant inList:&g_list index:nameToFlag];
        }
        BSGFreeRetiredItemsIfNoReaders();
    }
}

- (void)clear:(nullable NSString *)name {
    @synchronized (g_lock) {
        if (name != nil) {
            BSGListRemove(&g_list, nameToFlag, (NSString *_Nonnull)name);
        } else {
            [self _clearAll];
        }
        BSGFreeRetiredItemsIfNoReaders();
    }
}

- (void)clear {
    @synchronized (g_lock) {
        [self _clearAll];
        BSGFreeRetiredItemsIfNoReaders();
    }
}

- (void)replaceAllFlags:(nonnull NSArray<BugsnagFeatureFlag *> *)featureFlags {
    @synchronized (g_lock) {
        // Built unpublished, with the duplicate-name rule, so it holds each name once.
        struct bsg_feature_flag_list newList = {NULL, NULL};
        NSMutableDictionary<NSString *, NSValue *> *newNameToFlag = [NSMutableDictionary dictionaryWithCapacity:featureFlags.count];
        for (BugsnagFeatureFlag *flag in featureFlags) {
            [self _setFeatureFlag:flag.name withVariant:flag.variant inList:&newList index:newNameToFlag];
        }

        // Publish with a single pointer swap, then retire the old list.
        BSGPublishFence();
        struct bsg_feature_flag_list_item *oldHead = atomic_exchange(&g_list.head, atomic_load(&newList.head));
        atomic_store(&g_list.tail, atomic_load(&newList.tail));
        nameToFlag = newNameToFlag;
        BSGRetireList(oldHead);
        BSGFreeRetiredItemsIfNoReaders();
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
    atomic_init(&item->next, NULL);
    [data getBytes:item->jsonData length:data.length];
    return item;
}

- (void)_setFeatureFlag:(nonnull NSString *)name withVariant:(nullable NSString *)variant
                 inList:(struct bsg_feature_flag_list *)list
                  index:(NSMutableDictionary<NSString *, NSValue *> *)index {
    struct bsg_feature_flag_list_item *newItem = [self _newItemForFeatureFlagWithName:name variant:variant];
    if (!newItem) {
        // Unserializable: drop any earlier value rather than report a replaced variant. BSGPersistentFeatureFlagStore
        // instead logs an error and keeps any file written for an earlier value.
        BSGListRemove(list, index, name);
        return;
    }
    BSGListSetItem(list, index, name, newItem);
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
    BSGRetireList(item);
}

@end

#if defined(DEBUG) && DEBUG
size_t BSGAtomicFeatureFlagStoreRetiredItemCount(void) {
    (void)[BSGAtomicFeatureFlagStore class]; // Makes sure that g_lock exists
    @synchronized (g_lock) {
        return g_retiredCount;
    }
}
#endif

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
