//
//  BSGMetricKitStacktraceConverter.h
//  BugsnagMetricKitPlugin
//
//  Created by Robert Bartoszewski on 09/03/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<MetricKit/MetricKit.h>)

#import <MetricKit/MetricKit.h>

@class BugsnagStackframe;

NS_ASSUME_NONNULL_BEGIN

@interface BSGMetricKitStacktraceConverter : NSObject

/**
 * Converts a MetricKit MXCallStackTree into an array of BugsnagStackframe objects.
 *
 * @param callStackTree The MetricKit call stack tree to convert
 * @return An array of BugsnagStackframe objects representing the stack trace
 */
+ (NSArray<BugsnagStackframe *> *)stackframesFromCallStackTree:(MXCallStackTree *)callStackTree API_AVAILABLE(ios(14.0), macosx(12.0));

@end

NS_ASSUME_NONNULL_END

#endif
