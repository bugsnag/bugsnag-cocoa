//
//  ThreadScenarios.m
//  iOSTestApp
//
//  Created by Jamie Lynch on 12/06/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "Scenario.h"

@interface HandledErrorThreadSendAlwaysScenario : Scenario
@end

@implementation HandledErrorThreadSendAlwaysScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = false;
    [super startBugsnag];
}

- (void)run {
    NSException *exc = [NSException exceptionWithName:@"HandledErrorThreadSendAlwaysScenario" reason:@"HandledErrorThreadSendAlwaysScenario" userInfo:nil];
    [Bugsnag notify:exc];
}

@end
