//
//  InternalErrorReportingScenarios.m
//  macOSTestApp
//
//  Created by Nick Dowell on 07/05/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "Scenario.h"

@interface InternalErrorReportingScenarios_KSCrashReport : Scenario

@end

static void InternalErrorReportingScenarios_KSCrashReport_CrashHandler() {
    // Terminate the process without running atexit handlers. This should leave
    // a partically written KSCrashReport which will fail to parse as JSON.
    _exit(0);
}

@implementation InternalErrorReportingScenarios_KSCrashReport

- (void)startBugsnag {
    self.config.autoTrackSessions = NO;
    self.config.onCrashHandler = InternalErrorReportingScenarios_KSCrashReport_CrashHandler;
    
    [super startBugsnag];
}

- (void)run {
    __builtin_trap();
}

@end
