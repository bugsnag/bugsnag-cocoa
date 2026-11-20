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

#if defined(DEBUG) && DEBUG
/// For unit tests only (debug builds): the number of items that have been unlinked from the list but not freed yet,
/// because a crash-time reader may still be on them.
size_t BSGAtomicFeatureFlagStoreRetiredItemCount(void);
#endif
NS_ASSUME_NONNULL_END
