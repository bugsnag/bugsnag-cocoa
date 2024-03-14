//
// Created by Jamie Lynch on 07/06/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"

@interface DisabledSessionTrackingScenario : Scenario
@end

@implementation DisabledSessionTrackingScenario

- (void)configure {
    [super configure];
   self.config.autoTrackSessions = NO;
}

- (void)run {
}

@end
