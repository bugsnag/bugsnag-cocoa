//
//  ManualSessionWithUserScenario.m
//  iOSTestApp
//
//  Created by Delisa on 7/13/18.
//  Copyright © 2018 Bugsnag. All rights reserved.
//

#import "ManualSessionWithUserScenario.h"

@implementation ManualSessionWithUserScenario

- (void)startBugsnag {
    [self.config setUser:@"123" withEmail:@"joe@example.com" andName:@"Joe Bloggs"];
    self.config.autoTrackSessions = NO;
    [super startBugsnag];
}

- (void)run {
    [Bugsnag startSession];
}

@end
