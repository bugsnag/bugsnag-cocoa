//
//  EnabledErrorTypesScenario.m
//  iOSTestApp
//
//  Created by Robin Macharg on 27/02/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//
// Test that enabling/disabling certain classes of crashes works as expected.
// C++ crashes are handled in a separate scenario, and OOM is not tested for.

#import "EnabledErrorTypesScenario.h"

// MARK: -

/**
 * Disable all crash reporting (except, implicitly, manual) and crash the app
 * (no report should be sent)
 */
@implementation DisableAllExceptManualExceptionsAndCrashScenario

- (void)startBugsnag {
    BugsnagErrorTypes *errorTypes = [BugsnagErrorTypes new];
    errorTypes.cppExceptions = false;
    errorTypes.machExceptions = false;
    errorTypes.unhandledExceptions = false;
    errorTypes.signals = false;
    errorTypes.ooms = false;
    self.config.enabledErrorTypes = errorTypes;
    self.config.autoTrackSessions = NO;
    [super startBugsnag];
}

- (void)run {
    // Notify error so that mazerunner sees something
    [self performBlockAndWaitForEventDelivery:^{
        [Bugsnag notifyError:[NSError errorWithDomain:@"com.bugsnag" code:833 userInfo:nil]];
    }];

    // From null prt scenario
    volatile char *ptr = NULL;
    (void) *ptr;
}

@end

// MARK: -

@implementation DisableNSExceptionScenario

- (void)startBugsnag {
    BugsnagErrorTypes *errorTypes = [BugsnagErrorTypes new];
    errorTypes.unhandledExceptions = false;
    errorTypes.ooms = false;
    self.config.enabledErrorTypes = errorTypes;
    self.config.autoTrackSessions = NO;
    [super startBugsnag];
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

// MARK: -

@implementation DisableMachExceptionScenario

- (void)startBugsnag {
    BugsnagErrorTypes *errorTypes = [BugsnagErrorTypes new];
    errorTypes.machExceptions = false;
    errorTypes.ooms = false;
    self.config.enabledErrorTypes = errorTypes;
    self.config.autoTrackSessions = NO;
    [self.config addOnSendErrorBlock:^BOOL(BugsnagEvent * _Nonnull event) {
        // Suppress the SIGSEGV caused by EXC_BAD_ACCESS (https://flylib.com/books/en/3.126.1.110/1/)
        return ![@"SIGSEGV" isEqualToString:event.errors[0].errorClass];
    }];
    [super startBugsnag];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-noreturn"
- (void)run  __attribute__((noreturn)) {
    // Notify error so that mazerunner sees something
    [self performBlockAndWaitForEventDelivery:^{
        [Bugsnag notifyError:[NSError errorWithDomain:@"com.bugsnag" code:833 userInfo:nil]];
    }];

    strcmp(0, ""); // Generate EXC_BAD_ACCESS (see e.g. https://stackoverflow.com/q/22488358/2431627)
}
#pragma clang diagnostic pop

@end

// MARK: -

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
