//
// Created by Jamie Lynch on 28/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

#import "MinimalCrashReportScenario.h"

void HandleCrashedThread(const BSG_KSCrashReportWriter *writer) {
    abort();
}


/**
 * Triggers a crash in the crash reporter, which should result in generation of a minimal crash report
 */
@implementation MinimalCrashReportScenario

- (void)run {
    @throw [NSException exceptionWithName:NSGenericException
                                   reason:@"Minimal crash"
                                 userInfo:nil];
}

- (void)startBugsnag {
    self.config.onCrashHandler = HandleCrashedThread;
    self.config.shouldAutoCaptureSessions = NO;
    [super startBugsnag];
}


@end