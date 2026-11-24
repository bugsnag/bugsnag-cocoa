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

/// Duplicate names (all three stores): adding a name already present replaces its variant and keeps the name's first
/// position (A:1, B, A:2 gives A:2, B); clearing a name and re-adding it puts it at the end.
/// If a flag's latest variant cannot be converted to JSON (e.g. invalid UTF-16), BSGAtomicFeatureFlagStore drops it from
/// crash reports and BSGPersistentFeatureFlagStore from the OOM file, rather than report a replaced variant, from the
/// same call or an earlier one; BSGMemoryFeatureFlagStore keeps it as set.
@protocol BSGFeatureFlagStore

@property(nonatomic,nonnull,readonly) NSArray<BugsnagFeatureFlag *> *allFlags;
@property(nonatomic,readonly) BOOL isEmpty;

- (void)addFeatureFlag:(nonnull NSString *)name withVariant:(nullable NSString *)variant;
- (void)addFeatureFlags:(nonnull NSArray<BugsnagFeatureFlag *> *)featureFlags;
- (void)clear:(nullable NSString *)name;
- (void)clear;

@end

/// A store whose flags can all be replaced at once, used to copy the memory store's flags to the crash-time and
/// persistent stores when Bugsnag starts (see -[BSGCompositeFeatureFlagStore synchronizeFlagsWithMemoryStore]).
@protocol BSGReplaceableFeatureFlagStore <BSGFeatureFlagStore>

/// Replaces all flags, applying the duplicate-name rule above, in one update: a single pointer swap in
/// BSGAtomicFeatureFlagStore, a single log in BSGPersistentFeatureFlagStore, so a crash report or a kill meanwhile never
/// sees an empty or partial set.
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
