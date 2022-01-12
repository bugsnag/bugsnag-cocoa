//
//  OOMSessionlessScenario.m
//  iOSTestApp
//
//  Created by Nick Dowell on 10/01/2022.
//  Copyright © 2022 Bugsnag. All rights reserved.
//

#import "Scenario.h"

@interface OOMSessionlessScenario : Scenario

@end

@implementation OOMSessionlessScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = NO;
    self.config.enabledErrorTypes.ooms = YES;
    [super startBugsnag];
}

- (void)run {
    // Allow time for state metadata to be flushed to disk
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        // Fake an OOM
        kill(getpid(), SIGKILL);
    });
}

@end
