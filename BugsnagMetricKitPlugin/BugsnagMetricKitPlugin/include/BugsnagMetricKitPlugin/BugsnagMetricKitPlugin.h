//
//  BugsnagMetricKitPlugin.h
//  BugsnagMetricKitPlugin
//
//  Created by Robert Bartoszewski on 17/03/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Bugsnag/BSGPlugin.h>

@class BugsnagConfiguration;

NS_ASSUME_NONNULL_BEGIN

/**
 * Plugin that integrates Apple's MetricKit framework with Bugsnag.
 * Automatically registers for MetricKit callbacks and reports diagnostics as Bugsnag events.
 *
 * The plugin is automatically discovered and loaded by Bugsnag when linked.
 * No additional setup is required beyond linking the plugin framework.
 */
@interface BugsnagMetricKitPlugin : NSObject <BSGPlugin>

/**
 * Installs the MetricKit plugin and registers for MetricKit callbacks.
 * This method is automatically called by Bugsnag during startup if the plugin is linked.
 */
+ (void)install;

/**
 * Configures the plugin with the Bugsnag configuration.
 * This method is automatically called by Bugsnag after install.
 *
 * @param configuration The Bugsnag configuration object
 */
+ (void)configure:(BugsnagConfiguration *)configuration;

/**
 * Returns the current configuration for the plugin.
 * Used internally by the plugin's components.
 *
 * @return The stored configuration, or nil if not yet configured
 */
+ (nullable BugsnagConfiguration *)configuration;

@end

NS_ASSUME_NONNULL_END
