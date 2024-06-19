//
//  ThreadScenarios.m
//  iOSTestApp
//
//  Created by Jamie Lynch on 12/06/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"

@interface UnhandledErrorThreadSendNeverScenario : Scenario
@end

@implementation UnhandledErrorThreadSendNeverScenario

- (void)configure {
    [super configure];
    self.config.autoTrackSessions = false;
    self.config.sendThreads = BSGThreadSendPolicyNever;
}

- (void)run {
    NSException *exc = [NSException exceptionWithName:@"UnhandledErrorThreadSendNeverScenario" reason:@"UnhandledErrorThreadSendNeverScenario" userInfo:nil];
    [exc raise];
}

@end
