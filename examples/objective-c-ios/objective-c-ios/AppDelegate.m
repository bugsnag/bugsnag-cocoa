//
//  AppDelegate.m
//  Bugsnag Test App
//
//  Created by Simon Maynard on 1/18/13.
//  Copyright (c) 2013 Simon Maynard. All rights reserved.
//

#import "AppDelegate.h"
#import <Bugsnag/Bugsnag.h>

@import CrashReporter;


// Copied from BSG_KSCrashType.h
typedef CF_ENUM(unsigned, BSG_KSCrashType) {
    BSG_KSCrashTypeMachException = 0x01,
    BSG_KSCrashTypeSignal = 0x02,
    BSG_KSCrashTypeCPPException = 0x04,
    BSG_KSCrashTypeNSException = 0x08,
};

// Copied from BSG_KSCrashC.h
BSG_KSCrashType bsg_kscrash_setHandlingCrashTypes(BSG_KSCrashType crashTypes);


@interface AppDelegate ()

@property(nonatomic, strong) PLCrashReporter *crashReporter;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self startCrashHandlers];

    return YES;
}

- (void)startCrashHandlers {
    // Start Bugsnag first. startBugsnag will only install the handler for Mach exceptions.
    [self startBugsnag];

    // Next start PLCrashReporter. It becomes the first handler for everything.
    [self startPLCrashReporter];

    // Now install the rest of the Bugsnag handlers so that THEY become the first handlers.
    // Since Bugsnag's Mach handler is already installed, it won't be installed when we call this.
    bsg_kscrash_setHandlingCrashTypes(~0);

    // At this point, the first handlers for each type are:
    //
    // | Type           | First Handler                                          |
    // | -------------- | ------------------------------------------------------ |
    // | Mach Exception | PLCrashReporter                                        |
    // | Signal         | Bugsnag                                                |
    // | C++ Exception  | Bugsnag (PLCrashReporter will report these as signals) |
    // | NSException    | Bugsnag                                                |


    [self fetchAndPrintPLCrashReport];
}

- (void)startBugsnag {
    BugsnagConfiguration *config = [BugsnagConfiguration loadConfig];
    
    // We only enable Mach exceptions when installing Bugsnag so that PLCrashReporter can become the first handler.
    // We'll become first handler for the rest in a later call.
    config.enabledErrorTypes.unhandledExceptions = NO;
    config.enabledErrorTypes.cppExceptions = NO;
    config.enabledErrorTypes.signals = NO;
    config.enabledErrorTypes.machExceptions = YES;
    config.apiKey = @"791ac5ad5a73e2409c395a9db2ba033c";

    [config addOnSendErrorBlock:^BOOL(BugsnagEvent * _Nonnull event) {
        NSLog(@"BUGSNAG: Reporting crash: %@: %@", event.errors[0].errorClass, event.errors[0].errorMessage);
        return YES;
    }];

    [Bugsnag startWithConfiguration:config];
}

- (void)startPLCrashReporter {
    // Copied from https://github.com/microsoft/plcrashreporter/blob/master/README.md
    PLCrashReporterConfig *config = [[PLCrashReporterConfig alloc] initWithSignalHandlerType: PLCrashReporterSignalHandlerTypeMach
                                                                       symbolicationStrategy: PLCrashReporterSymbolicationStrategyAll];
    self.crashReporter = [[PLCrashReporter alloc] initWithConfiguration: config];

    NSError *error;
    if (![self.crashReporter enableCrashReporterAndReturnError: &error]) {
        NSLog(@"PLCRASHREPORTER: Could not enable crash reporter: %@", error);
    }
}

- (void)fetchAndPrintPLCrashReport {
    // Copied from https://github.com/microsoft/plcrashreporter/blob/master/README.md
    NSLog(@"PLCRASHREPORTER: Checking for crash report");
    if ([self.crashReporter hasPendingCrashReport]) {
        NSError *error;

        NSData *data = [self.crashReporter loadPendingCrashReportDataAndReturnError: &error];
        if (data == nil) {
            NSLog(@"PLCRASHREPORTER: Failed to load crash report data: %@", error);
            return;
        }

        PLCrashReport *report = [[PLCrashReport alloc] initWithData: data error: &error];
        if (report == nil) {
            NSLog(@"PLCRASHREPORTER: Failed to parse crash report: %@", error);
            return;
        }

        NSString *text = [PLCrashReportTextFormatter stringValueForCrashReport: report withTextFormat: PLCrashReportTextFormatiOS];
        NSLog(@"PLCRASHREPORTER: Reporting crash:\n%@", text);

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
