//
//  BSGAtomicFeatureFlagStore.h
//  Bugsnag
//
//  Created by Robert B on 16/12/2024.
//  Copyright © 2024 Bugsnag Inc. All rights reserved.
//

#import "BugsnagInternals.h"
#import "BSGDefines.h"
#import "BSGFeatureFlagStore.h"

NS_ASSUME_NONNULL_BEGIN


BSG_OBJC_DIRECT_MEMBERS
@interface BSGAtomicFeatureFlagStore ()

+ (instancetype)store;

@end

#pragma mark - Crash reporting

/**
 * Inserts the current feature flags into a crash report.
 *
 */
void BugsnagFeatureFlagsWriteCrashReport(const BSG_KSCrashReportWriter * _Nonnull writer,
                                         bool requiresAsyncSafety);
NS_ASSUME_NONNULL_END
