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
#import "Logging.h"

@interface DisableSignalsExceptionScenario : Scenario
@end

@implementation DisableSignalsExceptionScenario

- (void)configure {
    [super configure];
    BugsnagErrorTypes *errorTypes = [BugsnagErrorTypes new];
    errorTypes.signals = false;
    errorTypes.ooms = false;
    self.config.enabledErrorTypes = errorTypes;
    self.config.autoTrackSessions = NO;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-noreturn"
- (void)run  __attribute__((noreturn)) {
    [self waitForEventDelivery:^{
        // Notify error so that mazerunner sees something
        [Bugsnag notifyError:[NSError errorWithDomain:@"com.bugsnag" code:833 userInfo:nil]];
    } andThen:^{
        raise(SIGINT);
    }];
}
#pragma  clang pop

@end
