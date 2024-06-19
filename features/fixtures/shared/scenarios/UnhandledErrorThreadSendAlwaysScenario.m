//
//  ThreadScenarios.m
//  iOSTestApp
//
//  Created by Jamie Lynch on 12/06/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"

@interface UnhandledErrorThreadSendAlwaysScenario : Scenario
@end

@implementation UnhandledErrorThreadSendAlwaysScenario

- (void)configure {
    [super configure];
    self.config.autoTrackSessions = false;
}

- (void)run {
    NSException *exc = [NSException exceptionWithName:@"UnhandledErrorThreadSendAlwaysScenario" reason:@"UnhandledErrorThreadSendAlwaysScenario" userInfo:nil];
    [exc raise];
}

@end
