//
//  DisableNSExceptionScenario.m
//  iOSTestApp
//
//  Created by Robin Macharg on 27/02/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//
// Test that enabling/disabling certain classes of crashes works as expected.
// C++ crashes are handled in a separate scenario, and OOM is not tested for.

#import "Scenario.h"
#import "Logging.h"

@interface DisableNSExceptionScenario : Scenario
@end

@implementation DisableNSExceptionScenario

- (void)configure {
    [super configure];
    BugsnagErrorTypes *errorTypes = [BugsnagErrorTypes new];
    errorTypes.unhandledExceptions = false;
    errorTypes.ooms = false;
    self.config.enabledErrorTypes = errorTypes;
    self.config.autoTrackSessions = NO;
}

// Suppress the warning.  The async confuses the compiler.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-noreturn"
- (void)run  __attribute__((noreturn)) {
    @throw [NSException exceptionWithName:NSGenericException reason:@"An uncaught exception! SCREAM."
                                userInfo:@{NSLocalizedDescriptionKey: @"I'm in your program, catching your exceptions!"}];
}
#pragma clang diagnostic pop

@end
