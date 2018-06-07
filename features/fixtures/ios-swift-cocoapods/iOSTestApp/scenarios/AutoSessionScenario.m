//
// Created by Jamie Lynch on 07/06/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

#import "AutoSessionScenario.h"


@implementation AutoSessionScenario

- (void)startBugsnag {
    self.config.shouldAutoCaptureSessions = YES;
    [super startBugsnag];
}

- (void)run {
    [self flushAllSessions];
}

@end
