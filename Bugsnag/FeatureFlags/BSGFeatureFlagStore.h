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

@protocol BSGFeatureFlagStore

@property(nonatomic,nonnull,readonly) NSArray<BugsnagFeatureFlag *> *allFlags;
@property(nonatomic,readonly) BOOL isEmpty;

- (void)addFeatureFlag:(nonnull NSString *)name withVariant:(nullable NSString *)variant;
- (void)addFeatureFlags:(nonnull NSArray<BugsnagFeatureFlag *> *)featureFlags;
- (void)clear:(nullable NSString *)name;
- (void)clear;

/// Replaces all of the flags. BSGPersistentFeatureFlagStore saves the new set in a single update so
/// that an empty or partial set cannot be observed if the process is killed part way through; the
/// other stores clear their flags and then add the new ones.
- (void)replaceAllFlags:(nonnull NSArray<BugsnagFeatureFlag *> *)featureFlags;

@end

NS_ASSUME_NONNULL_END
