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

/// The persistent store's flags, decoded each time. For unit tests only.
@property(nonatomic,nonnull,readonly) NSArray<BugsnagFeatureFlag *> *persistedFlags;

/// The previous launch's flags, for its OOM or thermal kill event: those the persistent store read at creation,
/// excluding later changes (e.g. flags added before Bugsnag starts). Empty after synchronizeFlagsWithMemoryStore. A
/// persistent store that does not keep them gives its current flags.
@property(nonatomic,nonnull,readonly) NSArray<BugsnagFeatureFlag *> *previousLaunchFlags;

+ (instancetype)storeWithMemoryStore:(id<BSGFeatureFlagStore, NSCopying>)memoryStore
                     persistentStore:(id<BSGReplaceableFeatureFlagStore>)persistentStore
                         atomicStore:(id<BSGReplaceableFeatureFlagStore>)atomicStore;

/// Replaces the flags in the persistent and crash-time stores with the memory store's flags.
- (void)synchronizeFlagsWithMemoryStore;

@end

NS_ASSUME_NONNULL_END
