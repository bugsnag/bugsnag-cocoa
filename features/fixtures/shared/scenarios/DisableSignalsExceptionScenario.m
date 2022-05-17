//
//  DisableSignalsExceptionScenario.m
//  iOSTestApp
//
//  Created by Robin Macharg on 27/02/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//
// Test that enabling/disabling certain classes of crashes works as expected.
// C++ crashes are handled in a separate scenario, and OOM is not tested for.

#import "Scenario.h"

@interface DisableSignalsExceptionScenario : Scenario
@end

@implementation DisableSignalsExceptionScenario

- (void)startBugsnag {
    BugsnagErrorTypes *errorTypes = [BugsnagErrorTypes new];
    errorTypes.signals = false;
    errorTypes.ooms = false;
    self.config.enabledErrorTypes = errorTypes;
    self.config.autoTrackSessions = NO;
    [super startBugsnag];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-noreturn"
- (void)run  __attribute__((noreturn)) {
    // Notify error so that mazerunner sees something
    [self performBlockAndWaitForEventDelivery:^{
        [Bugsnag notifyError:[NSError errorWithDomain:@"com.bugsnag" code:833 userInfo:nil]];
    }];

    raise(SIGINT);
}
#pragma  clang pop

@end
