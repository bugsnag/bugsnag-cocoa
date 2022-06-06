//
//  InvalidCrashReportScenario.m
//  macOSTestApp
//
//  Created by Nick Dowell on 07/05/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "Scenario.h"

@interface InvalidCrashReportScenario : Scenario
@end

static void CrashHandler(const BSG_KSCrashReportWriter *writer) {
    writer->addJSONElement(writer, "something", "{1: \"Not valid JSON\"}");
    sleep(1);
}

@implementation InvalidCrashReportScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = NO;
    self.config.onCrashHandler = CrashHandler;
    if ([self.eventMode isEqualToString:@"internalErrorsDisabled"]) {
        self.config.telemetry &= ~BSGTelemetryInternalErrors;
    }
    [super startBugsnag];
}

- (void)run {
    __builtin_trap();
}

@end
