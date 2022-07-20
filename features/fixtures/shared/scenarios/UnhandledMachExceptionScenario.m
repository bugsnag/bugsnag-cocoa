//
//  UnhandledMachExceptionScenario.m
//  iOSTestApp
//
//  Created by Jamie Lynch on 26/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "Scenario.h"

@interface UnhandledMachExceptionScenario : Scenario
@end

@implementation UnhandledMachExceptionScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = NO;
    [super startBugsnag];
}

- (void)run {
    [Bugsnag setUser:nil withEmail:nil andName:nil];
    void (*ptr)(void) = (void *)0xDEADBEEF;
    ptr();
}

@end
