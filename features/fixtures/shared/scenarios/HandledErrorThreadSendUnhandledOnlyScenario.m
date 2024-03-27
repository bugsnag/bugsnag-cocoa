//
//  ThreadScenarios.m
//  iOSTestApp
//
//  Created by Jamie Lynch on 12/06/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"

@interface HandledErrorThreadSendUnhandledOnlyScenario : Scenario
@end

@implementation HandledErrorThreadSendUnhandledOnlyScenario

- (void)configure {
    [super configure];
    self.config.autoTrackSessions = false;
    self.config.sendThreads = BSGThreadSendPolicyUnhandledOnly;
}

- (void)run {
    NSException *exc = [NSException exceptionWithName:@"HandledErrorThreadSendUnhandledOnlyScenario" reason:@"HandledErrorThreadSendUnhandledOnlyScenario" userInfo:nil];
    [Bugsnag notify:exc];
}
@end
