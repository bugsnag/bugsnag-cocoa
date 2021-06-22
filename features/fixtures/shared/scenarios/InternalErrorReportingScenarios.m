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

static void InternalErrorReportingScenarios_KSCrashReport_CrashHandler(const BSG_KSCrashReportWriter *writer) {
    writer->addJSONElement(writer, "something", "{1: \"Not valid JSON\"}");
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
