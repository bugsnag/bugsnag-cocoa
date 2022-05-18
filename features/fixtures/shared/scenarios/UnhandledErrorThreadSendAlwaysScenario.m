//
//  ThreadScenarios.m
//  iOSTestApp
//
//  Created by Jamie Lynch on 12/06/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "Scenario.h"

@interface UnhandledErrorThreadSendAlwaysScenario : Scenario
@end

@implementation UnhandledErrorThreadSendAlwaysScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = false;
    [super startBugsnag];
}

- (void)run {
    NSException *exc = [NSException exceptionWithName:@"UnhandledErrorThreadSendAlwaysScenario" reason:@"UnhandledErrorThreadSendAlwaysScenario" userInfo:nil];
    [exc raise];
}

@end
