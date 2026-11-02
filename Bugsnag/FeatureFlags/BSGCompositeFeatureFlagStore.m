//
//  BSGCompositeFeatureFlagStore.m
//  Bugsnag
//
//  Created by Robert B on 16/12/2024.
//  Copyright © 2024 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BSGCompositeFeatureFlagStore.h"

@interface BSGCompositeFeatureFlagStore ()

@property(nonatomic, strong) id<BSGFeatureFlagStore, NSCopying> memoryStore;
@property(nonatomic, strong) id<BSGFeatureFlagStore> persistentStore;
@property(nonatomic, strong) id<BSGFeatureFlagStore> atomicStore;

@end

@implementation BSGCompositeFeatureFlagStore

+ (instancetype)storeWithMemoryStore:(id<BSGFeatureFlagStore, NSCopying>)memoryStore
                     persistentStore:(id<BSGFeatureFlagStore>)persistentStore
                         atomicStore:(id<BSGFeatureFlagStore>)atomicStore {
    BSGCompositeFeatureFlagStore *store = [self new];
    store.memoryStore = memoryStore;
    store.persistentStore = persistentStore;
    store.atomicStore = atomicStore;
    return store;
}

- (nonnull NSArray<BugsnagFeatureFlag *> *)persistedFlags {
    return [self.persistentStore allFlags];
}

- (id<BSGFeatureFlagStore>)copyMemoryStore {
    return [self.memoryStore copyWithZone:nil];
}

- (void)synchronizeFlagsWithMemoryStore {
    NSArray<BugsnagFeatureFlag *> *featureFlags = [self.memoryStore allFlags];
    [self.atomicStore replaceAllFlags:featureFlags];
    // Replaced in one update so that a kill during startup cannot leave an empty set persisted
    [self.persistentStore replaceAllFlags:featureFlags];
}

#pragma mark - BSGFeatureFlagStore

- (nonnull NSArray<BugsnagFeatureFlag *> *)allFlags {
    return [self.memoryStore allFlags];
}

- (BOOL)isEmpty {
    return [self.memoryStore isEmpty];
}

- (void)addFeatureFlag:(nonnull NSString *)name withVariant:(nullable NSString *)variant {
    [self.atomicStore addFeatureFlag:name withVariant:variant];
    [self.memoryStore addFeatureFlag:name withVariant:variant];
    [self.persistentStore addFeatureFlag:name withVariant:variant];
}

- (void)addFeatureFlags:(nonnull NSArray<BugsnagFeatureFlag *> *)featureFlags {
    [self.atomicStore addFeatureFlags:featureFlags];
    [self.memoryStore addFeatureFlags:featureFlags];
    [self.persistentStore addFeatureFlags:featureFlags];
}

- (void)clear:(nullable NSString *)name {
    [self.atomicStore clear:name];
    [self.memoryStore clear:name];
    [self.persistentStore clear:name];
}

- (void)clear {
    [self.atomicStore clear];
    [self.memoryStore clear];
    [self.persistentStore clear];
}

- (void)replaceAllFlags:(nonnull NSArray<BugsnagFeatureFlag *> *)featureFlags {
    [self.atomicStore replaceAllFlags:featureFlags];
    [self.memoryStore replaceAllFlags:featureFlags];
    [self.persistentStore replaceAllFlags:featureFlags];
}

@end
