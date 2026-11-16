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
    struct bsg_feature_flag_list_item *next;
    struct bsg_feature_flag_list_item *previous;
    char jsonData[]; // MUST be null terminated
};

static _Atomic(struct bsg_feature_flag_list_item *) g_feature_flags_head;
static _Atomic(struct bsg_feature_flag_list_item *) g_feature_flags_tail;
static atomic_bool g_writing_crash_report;
static NSMutableDictionary<NSString *, NSValue *> *nameToFlag;

@implementation BSGAtomicFeatureFlagStore

+ (instancetype)store {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        nameToFlag = [NSMutableDictionary dictionary];
    });
    return [self new];
}

#pragma mark - BSGFeatureFlagStore

- (nonnull NSArray<BugsnagFeatureFlag *> *)allFlags {
    return @[]; // This method should never be used with an atomic store. Please use BugsnagFeatureFlagsWriteCrashReport to serialize the data with a writer instead
}

- (BOOL)isEmpty {
    @synchronized (self) {
        return atomic_load(&g_feature_flags_head) == NULL;
    }
}

- (void)addFeatureFlag:(nonnull NSString *)name withVariant:(nullable NSString *)variant {
    @synchronized (self) {
        [self _removeFeatureFlagWithName:name];
        [self _addFeatureFlag:name withVariant:variant];
    }
}

- (void)addFeatureFlags:(nonnull NSArray<BugsnagFeatureFlag *> *)featureFlags {
    @synchronized (self) {
        for (BugsnagFeatureFlag *flag in featureFlags) {
            [self _addFeatureFlag:flag.name withVariant:flag.variant];
        }
    }
}

- (void)clear:(nullable NSString *)name {
    @synchronized (self) {
        if (name != nil) {
            [self _removeFeatureFlagWithName:name];
        } else {
            [self _clearAll];
        }
    }
}

- (void)clear {
    @synchronized (self) {
        [self _clearAll];
    }
}

#pragma mark - Private methods

- (void)_awaitAtomicFeatureFlagsLockIfNeeded {
    while (atomic_load(&g_writing_crash_report)) { continue; }
}

- (void)_addFeatureFlag:(nonnull NSString *)name withVariant:(nullable NSString *)variant {
    [self _awaitAtomicFeatureFlagsLockIfNeeded];
    NSData *data = [self _dataForFeatureFlagWithName:name variant:variant];
    struct bsg_feature_flag_list_item *head = atomic_load(&g_feature_flags_head);
    struct bsg_feature_flag_list_item *tail = atomic_load(&g_feature_flags_tail);
    struct bsg_feature_flag_list_item *newItem = calloc(1, sizeof(struct bsg_feature_flag_list_item) + data.length + 1);
    if (!newItem) {
        return;
    }
    [data getBytes:newItem->jsonData length:data.length];
    
    if (head == NULL) {
        [self _awaitAtomicFeatureFlagsLockIfNeeded];
        atomic_store(&g_feature_flags_head, newItem);
    }
    if (tail) {
        [self _awaitAtomicFeatureFlagsLockIfNeeded];
        tail->next = newItem;
    }
    [self _awaitAtomicFeatureFlagsLockIfNeeded];
    newItem->previous = tail;
    atomic_store(&g_feature_flags_tail, newItem);
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
    [self _awaitAtomicFeatureFlagsLockIfNeeded];
    struct bsg_feature_flag_list_item *flag = [nameToFlag[name] pointerValue];
    if (flag) {
        if (flag->previous) {
            flag->previous->next = flag->next;
        }
        if (flag->next) {
            flag->next->previous = flag->previous;
        }
        if (flag == atomic_load(&g_feature_flags_head)) {
            atomic_store(&g_feature_flags_head, flag->next);
        }
        if (flag == atomic_load(&g_feature_flags_tail)) {
            atomic_store(&g_feature_flags_tail, flag->previous);
        }
        free(flag);
        nameToFlag[name] = nil;
    }
}

- (void)_clearAll {
    [self _awaitAtomicFeatureFlagsLockIfNeeded];
    struct bsg_feature_flag_list_item *item = atomic_exchange(&g_feature_flags_head, NULL);
    while (item) {
        struct bsg_feature_flag_list_item *next = item->next;
        free(item);
        item = next;
    }
    atomic_store(&g_feature_flags_tail, NULL);
    nameToFlag = [NSMutableDictionary dictionary];
}

@end

void BugsnagFeatureFlagsWriteCrashReport(const BSG_KSCrashReportWriter *writer,
                                        bool __unused requiresAsyncSafety) {
    atomic_store(&g_writing_crash_report, true);
    
    writer->beginArray(writer, "featureFlags");
    
    struct bsg_feature_flag_list_item *item = atomic_load(&g_feature_flags_head);
    while (item) {
        writer->addJSONElement(writer, NULL, item->jsonData);
        item = item->next;
    }
    
    writer->endContainer(writer);
    
    atomic_store(&g_writing_crash_report, false);
}
