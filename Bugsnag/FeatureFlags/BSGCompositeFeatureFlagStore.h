//
//  BSGCompositeFeatureFlagStore.h
//  Bugsnag
//
//  Created by Robert B on 16/12/2024.
//  Copyright © 2024 Bugsnag Inc. All rights reserved.
//

#import "BugsnagInternals.h"
#import "BSGDefines.h"
#import "BSGFeatureFlagStore.h"

NS_ASSUME_NONNULL_BEGIN



@interface BSGCompositeFeatureFlagStore ()

/// The flags in the persistent store, decoded from its records each time. For unit tests only: the SDK uses
/// previousLaunchFlags for OOM and thermal kill events.
@property(nonatomic,nonnull,readonly) NSArray<BugsnagFeatureFlag *> *persistedFlags;

/// The flags of the previous launch, for its OOM or thermal kill event: those the persistent store read when it was
/// created, not including changes made since (e.g. flags the app added between creating the client and starting it).
/// Empty once synchronizeFlagsWithMemoryStore has run. A persistent store that does not keep them gives its current
/// flags.
@property(nonatomic,nonnull,readonly) NSArray<BugsnagFeatureFlag *> *previousLaunchFlags;

+ (instancetype)storeWithMemoryStore:(id<BSGFeatureFlagStore, NSCopying>)memoryStore
                     persistentStore:(id<BSGReplaceableFeatureFlagStore>)persistentStore
                         atomicStore:(id<BSGReplaceableFeatureFlagStore>)atomicStore;

/// Replaces the flags in the persistent and crash-time stores with the memory store's flags.
- (void)synchronizeFlagsWithMemoryStore;

@end

NS_ASSUME_NONNULL_END
