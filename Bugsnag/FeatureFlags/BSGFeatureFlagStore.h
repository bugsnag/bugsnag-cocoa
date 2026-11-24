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

/// BSGMemoryFeatureFlagStore, BSGAtomicFeatureFlagStore and BSGPersistentFeatureFlagStore treat duplicate names the same
/// way: adding a flag whose name is already present replaces its variant and keeps the flag in the position where that
/// name was first added. For example, adding A:1, B, A:2 gives A:2, B. Clearing a name and adding it again puts it at
/// the end.
/// One exception: when a flag's latest variant cannot be converted to JSON (for example, a string that is not valid
/// UTF-16), BSGAtomicFeatureFlagStore leaves the flag out of crash reports, and BSGPersistentFeatureFlagStore out of the
/// file used for OOM and thermal kill events, rather than report a variant that the app has replaced, whether the
/// earlier variant was given in the same call or an earlier one. BSGMemoryFeatureFlagStore keeps the flag as the app
/// set it.
@protocol BSGFeatureFlagStore

@property(nonatomic,nonnull,readonly) NSArray<BugsnagFeatureFlag *> *allFlags;
@property(nonatomic,readonly) BOOL isEmpty;

- (void)addFeatureFlag:(nonnull NSString *)name withVariant:(nullable NSString *)variant;
- (void)addFeatureFlags:(nonnull NSArray<BugsnagFeatureFlag *> *)featureFlags;
- (void)clear:(nullable NSString *)name;
- (void)clear;

@end

/// A store whose flags can all be replaced at once. BSGCompositeFeatureFlagStore uses this to copy the
/// memory store's flags to the crash-time and persistent stores when Bugsnag starts (see -synchronizeFlagsWithMemoryStore).
@protocol BSGReplaceableFeatureFlagStore <BSGFeatureFlagStore>

/// Replaces all of the flags, applying the duplicate-name rule above to featureFlags.
/// BSGAtomicFeatureFlagStore publishes the new list with a single pointer swap, so that a crash report written part
/// way through never sees an empty or partial set. BSGPersistentFeatureFlagStore saves the new set in a single update,
/// so that a process killed part way through never leaves an empty or partial set persisted.
- (void)replaceAllFlags:(nonnull NSArray<BugsnagFeatureFlag *> *)featureFlags;

@end

/// A persistent store that keeps a copy of the flags it read when it was created, i.e. the flags of the previous
/// launch, so that an OOM or thermal kill event for that launch is not given flags that the app added (or cleared)
/// after creating the client but before calling start.
@protocol BSGPreviousLaunchFeatureFlagStore <NSObject>

/// The flags read when the store was created (empty if there were none, or the store did not hold the lock). An
/// immutable copy: later changes to the store do not affect it. Released (empty) after replaceAllFlags:, which
/// BSGCompositeFeatureFlagStore calls when Bugsnag starts, after the event for the previous launch has been built.
@property(nonatomic,nonnull,readonly) NSArray<BugsnagFeatureFlag *> *previousLaunchFlags;

@end

NS_ASSUME_NONNULL_END
