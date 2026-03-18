//
//  BSGPluginRegistry.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 17/03/2026.
//

#import "BSGPluginRegistry.h"
#import "BSGPlugin.h"
#import "BugsnagConfiguration.h"

@implementation BSGPluginRegistry

+ (void)loadPluginsWithConfiguration:(BugsnagConfiguration *)configuration {
    // Check for MetricKit plugin
    Class<BSGPlugin> metricKitPlugin = NSClassFromString(@"BugsnagMetricKitPlugin");
    if ([metricKitPlugin conformsToProtocol:@protocol(BSGPlugin)]) {
        if ([metricKitPlugin respondsToSelector:@selector(install)]) {
            [metricKitPlugin performSelector:@selector(install)];
            
            // Configure the plugin if it supports configuration
            if (configuration && [metricKitPlugin respondsToSelector:@selector(configure:)]) {
                [metricKitPlugin performSelector:@selector(configure:) withObject:configuration];
            }
        }
    }
    
    // Future plugins can be added here
}

@end
