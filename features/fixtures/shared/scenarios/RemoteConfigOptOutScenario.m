//
//  RemoteConfigOptOutScenario.m
//  iOSTestApp
//
//  Created on 09/07/2026.
//  Copyright © 2026 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"

@interface RemoteConfigOptOutScenario : Scenario
@end

@implementation RemoteConfigOptOutScenario

- (void)configure {
    [super configure];
    // Set configuration endpoint to nil to opt out of remote config
    self.config.endpoints.configuration = nil;
    // Ensure stored events are uploaded immediately
    self.config.launchDurationMillis = 0;
}

- (void)run {
    // Wait a moment to ensure stored events are processed and uploaded
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Do nothing - just let the stored events from previous run be delivered
        NSLog(@"RemoteConfigOptOutScenario: Waiting for stored events to upload");
    });
}

@end
