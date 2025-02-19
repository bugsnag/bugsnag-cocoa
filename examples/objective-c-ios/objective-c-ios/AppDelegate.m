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

@import CrashReporter;

@interface AppDelegate ()

@property(nonatomic, strong) PLCrashReporter *crashReporter;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self startPLCrashReporter];
    [self startBugsnag];

    [self fetchPLCrashReport];

    return YES;
}

- (void)startBugsnag {
    /**
     This is the minimum amount of setup required for Bugsnag to work.  Simply add your API key to the app's .plist (Supporting Files/Bugsnag Test App-Info.plist) and the application will deliver all error and session notifications to the appropriate dashboard.
     
     You can find your API key in your Bugsnag dashboard under the settings menu.
     */
//    [Bugsnag start];
    
    /**
     Bugsnag behavior can be configured through the plist and/or further extended in code by creating a BugsnagConfiguration object and passing it to [Bugsnag startWithConfiguration].
     
     All subsequent setup is optional, and will configure your Bugsnag setup in different ways. A few common examples are included here, for more detailed explanations please look at the documented configuration options at https://docs.bugsnag.com/platforms/ios/configuration-options/
     */
    
    // Create config object from the application plist
    BugsnagConfiguration *config = [BugsnagConfiguration loadConfig];
    
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
    
    [config addOnSendErrorBlock:^BOOL(BugsnagEvent * _Nonnull event) {
        return [self receiveBugsnagReport:event];
    }];

    /**
     Finally, start Bugsnag with the specified configuration:
     */
    [Bugsnag startWithConfiguration:config];
}

- (BOOL)receiveBugsnagReport:(BugsnagEvent * _Nonnull)event {
    NSLog(@"BUGSNAG: REPORT:\n%@: %@", event.errors[0].errorClass, event.errors[0].errorMessage);
    return YES;
}

- (void)startPLCrashReporter {
    PLCrashReporterConfig *config = [[PLCrashReporterConfig alloc] initWithSignalHandlerType: PLCrashReporterSignalHandlerTypeMach
                                                                       symbolicationStrategy: PLCrashReporterSymbolicationStrategyAll];
    self.crashReporter = [[PLCrashReporter alloc] initWithConfiguration: config];

    // Enable the Crash Reporter.
    NSError *error;
    if (![self.crashReporter enableCrashReporterAndReturnError: &error]) {
        NSLog(@"PLCRASHREPORTER: Could not enable crash reporter: %@", error);
    }
}

- (void)fetchPLCrashReport {
    NSLog(@"PLCRASHREPORTER: Checking for crash report");
    if ([self.crashReporter hasPendingCrashReport]) {
        NSError *error;

        // Try loading the crash report.
        NSData *data = [self.crashReporter loadPendingCrashReportDataAndReturnError: &error];
        if (data == nil) {
            NSLog(@"PLCRASHREPORTER: Failed to load crash report data: %@", error);
            return;
        }

        // Retrieving crash reporter data.
        PLCrashReport *report = [[PLCrashReport alloc] initWithData: data error: &error];
        if (report == nil) {
            NSLog(@"PLCRASHREPORTER: Failed to parse crash report: %@", error);
            return;
        }

        // We could send the report from here, but we'll just print out some debugging info instead.
        NSString *text = [PLCrashReportTextFormatter stringValueForCrashReport: report withTextFormat: PLCrashReportTextFormatiOS];
        NSLog(@"PLCRASHREPORTER: REPORT:\n%@", text);

        // Purge the report.
        [self.crashReporter purgePendingCrashReport];
    }
}

#if defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_13_0

- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options API_AVAILABLE(ios(13.0)) {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}

#endif

@end
