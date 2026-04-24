//
//  BSGMetricsHandler.m
//  BugsnagMetricKitPlugin
//
//  Created by Robert Bartoszewski on 09/03/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import "BSGMetricsHandler.h"

#if __has_include(<MetricKit/MetricKit.h>)

@implementation BSGMetricsHandler

- (void)handleMetricsPayload:(MXMetricPayload *)payload {}

@end

#endif
