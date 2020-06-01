//
//  AppDelegate.m
//  Bugsnag Test App
//
//  Created by Simon Maynard on 1/18/13.
//  Copyright (c) 2013 Simon Maynard. All rights reserved.
//

#import "AppDelegate.h"
#import <Bugsnag/Bugsnag.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    /**
     This is the minimum amount of setup required for Bugsnag to work.  Simply input your apiKey and the application will deliver all error and session notifications to the appropriate dashboard.
     */
    NSString *apiKey = @"<YOUR_APIKEY_HERE>";
    [Bugsnag startWithApiKey:apiKey];
    
    /**
     All subsequent setup is optional, and will configure your Bugsnag setup in different ways. A few common examples are included here, for more detailed explanations please look at the documented configuration options at https://docs.bugsnag.com/platforms/ios/configuration-options/
     */
//     BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:apiKey];
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
//    BugsnagErrorTypes *enabledErrorTypes = [BugsnagErrorTypes alloc];
//    enabledErrorTypes.ooms = NO;
//    enabledErrorTypes.unhandledExceptions = YES;
//    enabledErrorTypes.machExceptions = YES;
//    [config setEnabledErrorTypes:enabledErrorTypes];
    
    /**
     If there's information that you do not wish sent to your Bugsnag dashboard, such as passwords or user information, you can set the keys as redacted. When a notification is sent to Bugsnag all keys matching your set filters will be redacted before they leave your application.
     All automatically captured data can be found here: https://docs.bugsnag.com/platforms/ios/automatically-captured-data/.
     */
//    [config setRedactedKeys:[NSSet setWithArray:@[@"filter_me", @"firstName", @"lastName"]]];
    //[Bugsnag startWithConfiguration:config];
    
    return YES;
}

@end
