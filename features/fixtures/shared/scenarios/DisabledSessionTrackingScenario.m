//
// Created by Jamie Lynch on 07/06/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

#import "DisabledSessionTrackingScenario.h"


@implementation DisabledSessionTrackingScenario

- (void)startBugsnag {
   self.config.autoTrackSessions = NO;
   [super startBugsnag];
}

- (void)run {
}

@end
