//
//  BSGPlugin.h
//  Bugsnag
//
//  Created by Robert Bartoszewski on 17/03/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BugsnagConfiguration;

NS_ASSUME_NONNULL_BEGIN

/**
 * Protocol for Bugsnag plugins that are automatically discovered and loaded at runtime.
 * Plugins are discovered using NSClassFromString and initialized if present.
 */
@protocol BSGPlugin<NSObject>

/**
 * Installs the plugin and initializes any required resources.
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

@end

NS_ASSUME_NONNULL_END
