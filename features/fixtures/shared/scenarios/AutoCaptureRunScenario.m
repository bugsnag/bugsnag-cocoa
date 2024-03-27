//
//  AutoCaptureRunScenario.m
//  iOSTestApp
//
//  Created by Robin Macharg on 06/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"

@interface AutoCaptureRunScenario : Scenario
@end

@implementation AutoCaptureRunScenario

- (void)configure {
    [super configure];
    self.config.autoTrackSessions = YES;
}

- (void)run {}

@end
