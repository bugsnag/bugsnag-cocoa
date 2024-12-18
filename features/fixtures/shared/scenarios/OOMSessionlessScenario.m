//
//  OOMSessionlessScenario.m
//  iOSTestApp
//
//  Created by Nick Dowell on 10/01/2022.
//  Copyright © 2022 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"

@interface OOMSessionlessScenario : Scenario

@end

@implementation OOMSessionlessScenario

- (void)configure {
    [super configure];
    self.config.autoTrackSessions = NO;
    self.config.enabledErrorTypes.ooms = YES;
}

- (void)run {
    [Bugsnag addFeatureFlagWithName:@"Feature Flag1" variant: @"Variant1"];
    // Allow time for state metadata to be flushed to disk
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [Bugsnag addFeatureFlagWithName:@"Feature Flag2" variant: @"Variant2"];
        [Bugsnag addFeatureFlagWithName:@"Feature Flag3"];
        // Fake an OOM
        kill(getpid(), SIGKILL);
    });
}

@end
