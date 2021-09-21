//
//  AppDelegate.m
//  Bugsnag Test App
//
//  Created by Simon Maynard on 1/18/13.
//  Copyright (c) 2013 Simon Maynard. All rights reserved.
//

#import "AppDelegate.h"
#import <Bugsnag/Bugsnag.h>

/**
 * To enable network breadcrumbs, import the plugin and then add to your config (see configuration section further down).
 * You must also update your Podfile to include pod BugsnagNetworkRequestPlugin.
 */
#import <BugsnagNetworkRequestPlugin/BugsnagNetworkRequestPlugin.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    /**
     This is the minimum amount of setup required for Bugsnag to work.  Simply add your API key to the app's .plist (Supporting Files/Bugsnag Test App-Info.plist) and the application will deliver all error and session notifications to the appropriate dashboard.
     
     You can find your API key in your Bugsnag dashboard under the settings menu.
     */
    [Bugsnag start];
    
    /**
     Bugsnag behavior can be configured through the plist and/or further extended in code by creating a BugsnagConfiguration object and passing it to [Bugsnag startWithConfiguration].
     
     All subsequent setup is optional, and will configure your Bugsnag setup in different ways. A few common examples are included here, for more detailed explanations please look at the documented configuration options at https://docs.bugsnag.com/platforms/ios/configuration-options/
     */
    
    // Create config object from the application plist
//    BugsnagConfiguration *config = [BugsnagConfiguration loadConfig];
    
    // ... or construct an empty object
//    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:@"YOUR-API-KEY"];
    
    /**
     This sets some user information that will be attached to each error.
     */
//    [config setUser:@"DefaultUser" withEmail:@"Not@real.fake" andName:@"Default User"];
    
    /**
     The appVersion will let you see what release an error is present in.  This will be picked up automatically from your build settings, but can be manually overwritten as well.
     */
//    [config setAppVersion:@"1.5.0"];
    
    /**
     When persisting a user you won't need to set the user information everytime the app opens, instead it will be persisted between each app session.
     */
//    [config setPersistUser:YES];
    
    /**
     This option allows you to send more or less detail about errors to Bugsnag.  Setting it to Always or Unhandled means you'll have detailed stacktraces of all app threads available when debugging unexpected errors.
     */
//    [config setSendThreads:BSGThreadSendPolicyAlways];
    
    /**
     Enabled error types allow you to customize exactly what errors are automatically captured and delivered to your Bugsnag dashboard.  A detailed breakdown of each error type can be found in the configuration option documentation.
     */
//    config.enabledErrorTypes.ooms = NO;
//    config.enabledErrorTypes.unhandledExceptions = YES;
//    config.enabledErrorTypes.machExceptions = YES;
    
    /**
     * To enable network breadcrumbs, add the BugsnagNetworkRequestPlugin plugin to your config.
     */
//    [config addPlugin:[[BugsnagNetworkRequestPlugin alloc] init]];

    /**
     If there's information that you do not wish sent to your Bugsnag dashboard, such as passwords or user information, you can set the keys as redacted. When a notification is sent to Bugsnag all keys matching your set filters will be redacted before they leave your application.
     All automatically captured data can be found here: https://docs.bugsnag.com/platforms/ios/automatically-captured-data/.
     */
//    [config setRedactedKeys:[NSSet setWithArray:@[@"filter_me", @"firstName", @"lastName"]]];
    
    /**
     Finally, start Bugsnag with the specified configuration:
     */
//    [Bugsnag startWithConfiguration:config];
    
    return YES;
}

#if defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_13_0

- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options API_AVAILABLE(ios(13.0)) {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}

#endif

@end
