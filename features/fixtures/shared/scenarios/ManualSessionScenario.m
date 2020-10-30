//
// Created by Jamie Lynch on 07/06/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

#import "ManualSessionScenario.h"
#import <Bugsnag/Bugsnag.h>

@interface BugsnagConfiguration ()
- (void)deletePersistedUserData;
@end

@implementation ManualSessionScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = NO;
    [super startBugsnag];
}

- (void)run {
    [Bugsnag startSession];
}

@end
