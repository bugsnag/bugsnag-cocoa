//
// Created by Jamie Lynch on 07/06/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"

/**
 * Sends a manual session payload to Bugsnag.
 */
@interface ManualSessionScenario : Scenario
@end

@implementation ManualSessionScenario

- (void)configure {
    [super configure];
    self.config.autoTrackSessions = NO;
}

- (void)run {
    [Bugsnag startSession];
}

@end
