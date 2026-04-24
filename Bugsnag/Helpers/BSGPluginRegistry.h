//
//  BSGPluginRegistry.h
//  Bugsnag
//
//  Created by Robert Bartoszewski on 17/03/2026.
//

#import <Foundation/Foundation.h>

@class BugsnagConfiguration;
@protocol BSGPlugin;

NS_ASSUME_NONNULL_BEGIN

/**
 * Registry for discovering and loading Bugsnag plugins at runtime.
 * Plugins are discovered using NSClassFromString and automatically initialized if present.
 * Plugins should conform to the BSGPlugin protocol.
 */
@interface BSGPluginRegistry : NSObject

/**
 * Loads all available Bugsnag plugins with configuration.
 * Plugins must implement a +install class method to be loaded.
 * If plugins implement +configure: they will receive the configuration.
 *
 * @param configuration The Bugsnag configuration to pass to plugins
 */
+ (void)loadPluginsWithConfiguration:(nullable BugsnagConfiguration *)configuration;

@end

NS_ASSUME_NONNULL_END
