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

/// Duplicate names (BSGMemoryFeatureFlagStore and BSGAtomicFeatureFlagStore): adding a name already present replaces
/// its variant and keeps the name's first position (A:1, B, A:2 gives A:2, B); clearing a name and re-adding it puts it
/// at the end. BSGPersistentFeatureFlagStore (OOM and thermal kill events) moves a re-added flag to the end.
/// If a flag's latest variant cannot be converted to JSON (e.g. invalid UTF-16), BSGAtomicFeatureFlagStore drops the
/// flag from crash reports rather than report a replaced variant, from the same call or an earlier one;
/// BSGMemoryFeatureFlagStore keeps it as set.
@protocol BSGFeatureFlagStore

@property(nonatomic,nonnull,readonly) NSArray<BugsnagFeatureFlag *> *allFlags;
@property(nonatomic,readonly) BOOL isEmpty;

- (void)addFeatureFlag:(nonnull NSString *)name withVariant:(nullable NSString *)variant;
- (void)addFeatureFlags:(nonnull NSArray<BugsnagFeatureFlag *> *)featureFlags;
- (void)clear:(nullable NSString *)name;
- (void)clear;

@end

/// A store whose flags can all be replaced at once, used to copy the memory store's flags to the crash-time store when
/// Bugsnag starts (see -[BSGCompositeFeatureFlagStore synchronizeFlagsWithMemoryStore]).
@protocol BSGReplaceableFeatureFlagStore <BSGFeatureFlagStore>

/// Replaces all flags, applying the duplicate-name rule above. In BSGAtomicFeatureFlagStore this is a single pointer
/// swap, so a crash report written meanwhile never sees an empty or partial set.
- (void)replaceAllFlags:(nonnull NSArray<BugsnagFeatureFlag *> *)featureFlags;

@end

NS_ASSUME_NONNULL_END
