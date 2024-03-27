//
//  DisableAllExceptManualExceptionsAndCrashScenario.m
//  iOSTestApp
//
//  Created by Robin Macharg on 27/02/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//
// Test that enabling/disabling certain classes of crashes works as expected.
// C++ crashes are handled in a separate scenario, and OOM is not tested for.

#import "Scenario.h"
#import "Logging.h"

/**
 * Disable all crash reporting (except, implicitly, manual) and crash the app
 * (no report should be sent)
 */
@interface DisableAllExceptManualExceptionsAndCrashScenario : Scenario
@end

@implementation DisableAllExceptManualExceptionsAndCrashScenario

- (void)configure {
    [super configure];
    BugsnagErrorTypes *errorTypes = [BugsnagErrorTypes new];
    errorTypes.cppExceptions = false;
    errorTypes.machExceptions = false;
    errorTypes.unhandledExceptions = false;
    errorTypes.signals = false;
    errorTypes.ooms = false;
    self.config.enabledErrorTypes = errorTypes;
    self.config.autoTrackSessions = NO;
}

- (void)run {
    [self waitForEventDelivery:^{
        // Notify error so that mazerunner sees something
        [Bugsnag notifyError:[NSError errorWithDomain:@"com.bugsnag" code:833 userInfo:nil]];
    } andThen:^{
        // From null ptr scenario
        volatile char *ptr = NULL;
        (void) *ptr;
    }];
}

@end
