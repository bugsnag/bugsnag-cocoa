//
//  AutoSessionUnhandledScenario.m
//  iOSTestApp
//
//  Created by Delisa on 7/13/18.
//  Copyright © 2018 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"

@interface AutoSessionUnhandledScenario : Scenario
@end

@implementation AutoSessionUnhandledScenario

- (void)configure {
    [super configure];
    // Only track sessions on the first launch
    self.config.autoTrackSessions = self.launchCount == 1;
}

- (void)run {
    // Wait for the session to be sent
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        @throw [NSException exceptionWithName:@"Kaboom" reason:@"The connection exploded" userInfo:nil];
    });
}

@end
