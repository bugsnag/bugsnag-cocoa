//
//  BugsnagMetricKitTypes.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 09/03/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import "BugsnagMetricKitTypes.h"

@implementation BugsnagMetricKitTypes

- (instancetype)init {
    if ((self = [super init])) {
        // MetricKit is opt-in and disabled by default
        _enabled = NO;
        // All diagnostic types are enabled by default when MetricKit is enabled
        _crashDiagnostics = YES;
        _cpuExceptionDiagnostics = YES;
        _appLaunchDiagnostics = YES;
        _hangDiagnostics = YES;
        _diskWriteExceptionDiagnostics = YES;
    }
    return self;
}

@end
