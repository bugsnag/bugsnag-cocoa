//
//  BSGMemoryFeatureFlagStore.m
//  Bugsnag
//
//  Created by Nick Dowell on 11/11/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "BSGMemoryFeatureFlagStore.h"

#import "BSGKeys.h"
#import "BugsnagFeatureFlag.h"

NSArray<NSDictionary *> *BSGFeatureFlagStoreToJSON(id<BSGFeatureFlagStore> store) {
    NSMutableArray<NSDictionary *> *result = [NSMutableArray array];

    for (BugsnagFeatureFlag *flag in [store allFlags]) {
        if ([flag isKindOfClass:[BugsnagFeatureFlag class]]) {
            if (flag.variant) {
                [result addObject:@{BSGKeyFeatureFlag:flag.name, BSGKeyVariant:(NSString *_Nonnull)flag.variant}];
            } else {
                [result addObject:@{BSGKeyFeatureFlag:flag.name}];
            }
        }
    }
    return result;
}

BSGMemoryFeatureFlagStore * BSGFeatureFlagStoreFromJSON(id json) {
    return [BSGMemoryFeatureFlagStore fromJSON:json];
}

BSGMemoryFeatureFlagStore * BSGFeatureFlagStoreWithFlags(NSArray<BugsnagFeatureFlag *> *flags) {
    return [BSGMemoryFeatureFlagStore withFlags:flags];
}

/**
 * Stores feature flags as a dictionary containing the flag name as a key, with the
 * value being the index into an array containing the complete feature flag.
 *
 * Removals leave holes in the array, which gets rebuilt on clear once there are too many holes.
 *
 * This gives the access speed of a dictionary while keeping ordering intact.
 */
BSG_OBJC_DIRECT_MEMBERS
@interface BSGMemoryFeatureFlagStore ()

@property(nonatomic, readwrite) NSMutableArray *flags;
@property(nonatomic, readwrite) NSMutableDictionary *indices;

@end

static const int REBUILD_AT_HOLE_COUNT = 1000;

BSG_OBJC_DIRECT_MEMBERS
@implementation BSGMemoryFeatureFlagStore

+ (nonnull BSGMemoryFeatureFlagStore *)fromJSON:(nonnull id)json {
    BSGMemoryFeatureFlagStore *store = [BSGMemoryFeatureFlagStore new];
    if ([json isKindOfClass:[NSArray class]]) {
        for (id item in json) {
            if ([item isKindOfClass:[NSDictionary class]]) {
                NSString *featureFlag = item[BSGKeyFeatureFlag];
                if ([featureFlag isKindOfClass:[NSString class]]) {
                    id variant = item[BSGKeyVariant];
                    if (![variant isKindOfClass:[NSString class]]) {
                        variant = nil;
                    }
                    [store addFeatureFlag:featureFlag withVariant:variant];
                }
            }
        }
    }
    return store;
}

+ (nonnull BSGMemoryFeatureFlagStore *)withFlags:(NSArray<BugsnagFeatureFlag *> *)flags {
    BSGMemoryFeatureFlagStore *store = [BSGMemoryFeatureFlagStore new];
    
    for (BugsnagFeatureFlag *flag in flags) {
        [store addFeatureFlag:flag.name withVariant:flag.variant];
    }
    
    return store;
}

- (nonnull instancetype)init {
    if ((self = [super init]) != nil) {
        _flags = [NSMutableArray new];
        _indices = [NSMutableDictionary new];
    }
    return self;
}

static inline int getIndexFromDict(NSDictionary *dict, NSString *name) {
    NSNumber *boxedIndex = dict[name];
    if (boxedIndex == nil) {
        return -1;
    }
    return boxedIndex.intValue;
}

- (void)rebuildIfTooManyHoles {
    int holeCount = (int)self.flags.count - (int)self.indices.count;
    if (holeCount < REBUILD_AT_HOLE_COUNT) {
        return;
    }

    NSMutableArray *newFlags = [NSMutableArray arrayWithCapacity:self.indices.count];
    NSMutableDictionary *newIndices = [NSMutableDictionary new];
    for (BugsnagFeatureFlag *flag in self.flags) {
        if ([flag isKindOfClass:[BugsnagFeatureFlag class]]) {
            [newFlags addObject:flag];
        }
    }

    for (NSUInteger i = 0; i < newFlags.count; i++) {
        BugsnagFeatureFlag *flag = newFlags[i];
        newIndices[flag.name] = @(i);
    }
    self.flags = newFlags;
    self.indices = newIndices;
}

- (id)copyWithZone:(NSZone *)zone {
    BSGMemoryFeatureFlagStore *store = [[BSGMemoryFeatureFlagStore allocWithZone:zone] init];
    store.flags = [self.flags mutableCopy];
    store.indices = [self.indices mutableCopy];
    return store;
}

#pragma mark - BSGFeatureFlagStore

- (nonnull NSArray<BugsnagFeatureFlag *> *)allFlags {
    NSMutableArray<BugsnagFeatureFlag *> *flags = [NSMutableArray arrayWithCapacity:self.indices.count];
    for (BugsnagFeatureFlag *flag in self.flags) {
        if ([flag isKindOfClass:[BugsnagFeatureFlag class]]) {
            [flags addObject:flag];
        }
    }
    return flags;
}

- (BOOL)isEmpty {
    return self.indices.count == 0;
}

- (void)addFeatureFlag:(nonnull NSString *)name withVariant:(nullable NSString *)variant {
    BugsnagFeatureFlag *flag = [BugsnagFeatureFlag flagWithName:name variant:variant];

    int index = getIndexFromDict(self.indices, name);
    if (index >= 0) {
        self.flags[(unsigned)index] = flag;
    } else {
        index = (int)self.flags.count;
        [self.flags addObject:flag];
        self.indices[name] = @(index);
    }
}

- (void)addFeatureFlags:(nonnull NSArray<BugsnagFeatureFlag *> *)featureFlags {
    for (BugsnagFeatureFlag *flag in featureFlags) {
        [self addFeatureFlag:flag.name withVariant:flag.variant];
    }
}

- (void)clear:(nullable NSString *)name {
    if (name != nil) {
        int index = getIndexFromDict(self.indices, name);
        if (index >= 0) {
            self.flags[(unsigned)index] = [NSNull null];
            [self.indices removeObjectForKey:(id)name];
            [self rebuildIfTooManyHoles];
        }
    } else {
        [self clear];
    }
}

- (void)clear {
    [self.indices removeAllObjects];
    [self.flags removeAllObjects];
}

@end
