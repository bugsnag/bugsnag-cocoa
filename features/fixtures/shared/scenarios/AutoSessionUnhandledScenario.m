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
    if ([self.args[0] isEqualToString:@"noevent"]) {
        self.config.autoTrackSessions = NO;
    } else {
        self.config.autoTrackSessions = YES;
    }
}

- (void)run {
    if (![self.args[0] isEqualToString:@"noevent"]) {
        // Just sleep because dispatching the code never runs.
        sleep(2);
        NSException *ex = [NSException exceptionWithName:@"Kaboom" reason:@"The connection exploded" userInfo:nil];
        @throw ex;
    }
}

@end
