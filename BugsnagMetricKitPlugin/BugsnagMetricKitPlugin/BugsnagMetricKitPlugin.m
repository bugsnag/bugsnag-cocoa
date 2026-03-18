//
//  BugsnagMetricKitPlugin.m
//  BugsnagMetricKitPlugin
//
//  Created by Robert Bartoszewski on 17/03/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import "BugsnagMetricKitPlugin.h"
#import "BSGMetricKit.h"
#import <Bugsnag/BugsnagConfiguration.h>

#if __has_include(<MetricKit/MetricKit.h>)
#import <MetricKit/MetricKit.h>

static BugsnagConfiguration *pluginConfiguration = nil;

@implementation BugsnagMetricKitPlugin

+ (void)install {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Check if MetricKit is available on this platform
        if (@available(iOS 13.0, macOS 12.0, *)) {
            // Install MetricKit subscriber
            [[BSGMetricKit sharedInstance] installMetricKit];
        }
    });
}

+ (void)configure:(BugsnagConfiguration *)configuration {
    pluginConfiguration = configuration;
    
    // Pass configuration to BSGMetricKit which will pass it to the diagnostics handler
    [[BSGMetricKit sharedInstance] configure:configuration];
}

+ (BugsnagConfiguration *)configuration {
    return pluginConfiguration;
}

@end

#else

// Stub implementation when MetricKit is not available
@implementation BugsnagMetricKitPlugin

+ (void)install {
    // No-op if MetricKit not available
}

+ (void)configure:(BugsnagConfiguration *)configuration {
    // No-op if MetricKit not available
}

@end

#endif
