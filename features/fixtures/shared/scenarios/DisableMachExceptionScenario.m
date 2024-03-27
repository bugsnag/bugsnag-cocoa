//
//  DisableMachExceptionScenario.m
//  iOSTestApp
//
//  Created by Robin Macharg on 27/02/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//
// Test that enabling/disabling certain classes of crashes works as expected.
// C++ crashes are handled in a separate scenario, and OOM is not tested for.

#import "Scenario.h"
#import "Logging.h"

@interface DisableMachExceptionScenario : Scenario
@end

@implementation DisableMachExceptionScenario

- (void)configure {
    [super configure];
    BugsnagErrorTypes *errorTypes = [BugsnagErrorTypes new];
    errorTypes.machExceptions = false;
    errorTypes.ooms = false;
    self.config.enabledErrorTypes = errorTypes;
    self.config.autoTrackSessions = NO;
    [self.config addOnSendErrorBlock:^BOOL(BugsnagEvent * _Nonnull event) {
        // Suppress the SIGSEGV caused by EXC_BAD_ACCESS (https://flylib.com/books/en/3.126.1.110/1/)
        return ![@"SIGSEGV" isEqualToString:event.errors[0].errorClass];
    }];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-noreturn"
- (void)run  __attribute__((noreturn)) {
    [self waitForEventDelivery:^{
        // Notify error so that mazerunner sees something
        [Bugsnag notifyError:[NSError errorWithDomain:@"com.bugsnag" code:833 userInfo:nil]];
    } andThen:^{
        strcmp(0, ""); // Generate EXC_BAD_ACCESS (see e.g. https://stackoverflow.com/q/22488358/2431627)
    }];
}
#pragma clang diagnostic pop

@end
