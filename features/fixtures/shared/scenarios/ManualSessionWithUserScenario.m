//
//  ManualSessionWithUserScenario.m
//  iOSTestApp
//
//  Created by Delisa on 7/13/18.
//  Copyright © 2018 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"

@interface ManualSessionWithUserScenario : Scenario
@end

@implementation ManualSessionWithUserScenario

- (void)configure {
    [super configure];
    [self.config setUser:@"123" withEmail:@"joe@example.com" andName:@"Joe Bloggs"];
    self.config.autoTrackSessions = NO;
}

- (void)run {
    [Bugsnag startSession];
}

@end
