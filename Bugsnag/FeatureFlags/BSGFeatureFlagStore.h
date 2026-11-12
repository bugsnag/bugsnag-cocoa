//
//  BSGFeatureFlagStore.h
//  Bugsnag
//
//  Created by Robert B on 16/12/2024.
//  Copyright © 2024 Bugsnag Inc. All rights reserved.
//

#import "BugsnagInternals.h"
#import "../Helpers/BSGDefines.h"

NS_ASSUME_NONNULL_BEGIN

/// All stores treat duplicate names the same way: adding a flag whose name is already present
/// replaces its variant and keeps the flag in the position where that name was first added. For
/// example, adding A:1, B, A:2 gives A:2, B. Clearing a name and adding it again puts it at the end.
@protocol BSGFeatureFlagStore

@property(nonatomic,nonnull,readonly) NSArray<BugsnagFeatureFlag *> *allFlags;
@property(nonatomic,readonly) BOOL isEmpty;

- (void)addFeatureFlag:(nonnull NSString *)name withVariant:(nullable NSString *)variant;
- (void)addFeatureFlags:(nonnull NSArray<BugsnagFeatureFlag *> *)featureFlags;
- (void)clear:(nullable NSString *)name;
- (void)clear;

@end

/// A store whose flags can all be replaced at once. BSGCompositeFeatureFlagStore uses this to copy the
/// memory store's flags to its other stores when Bugsnag starts (see -synchronizeFlagsWithMemoryStore).
@protocol BSGReplaceableFeatureFlagStore <BSGFeatureFlagStore>

/// Replaces all of the flags, applying the duplicate-name rule above to featureFlags.
/// BSGPersistentFeatureFlagStore saves the new set in a single update and BSGAtomicFeatureFlagStore
/// publishes the new list with a single pointer swap, so that neither a crash report nor a process
/// killed part way through can observe an empty or partial set.
- (void)replaceAllFlags:(nonnull NSArray<BugsnagFeatureFlag *> *)featureFlags;

@end

NS_ASSUME_NONNULL_END
