//
//  MaxPersistedSessionsScenario.m
//  macOSTestApp
//
//  Created by Nick Dowell on 13/05/2022.
//  Copyright © 2022 Bugsnag Inc. All rights reserved.
//

#import "Scenario.h"

@interface MaxPersistedSessionsScenario : Scenario
@end

@implementation MaxPersistedSessionsScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = NO;
    self.config.maxPersistedSessions = 1;

    [super startBugsnag];

    [Bugsnag setUser:[self nextUserId] withEmail:nil andName:nil];
    [Bugsnag startSession];
}

- (void)run {
    [Bugsnag setUser:[self nextUserId] withEmail:nil andName:nil];
    [Bugsnag startSession];
}

- (NSString *)nextUserId {
    NSString *key = @"sessionCounter";
    NSInteger sessionCounter = [NSUserDefaults.standardUserDefaults integerForKey:key] + 1;
    [NSUserDefaults.standardUserDefaults setInteger:sessionCounter forKey:key];
    return [NSString stringWithFormat:@"%ld", sessionCounter];
}

@end
