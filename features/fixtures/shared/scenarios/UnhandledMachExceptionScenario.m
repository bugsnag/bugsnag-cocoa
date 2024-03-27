//
//  UnhandledMachExceptionScenario.m
//  iOSTestApp
//
//  Created by Jamie Lynch on 26/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"

@interface UnhandledMachExceptionScenario : Scenario
@end

@implementation UnhandledMachExceptionScenario

- (void)configure {
    [super configure];
    self.config.autoTrackSessions = NO;
}

- (void)run {
    [Bugsnag setUser:nil withEmail:nil andName:nil];
    void (*ptr)(void) = (void *)0xDEADBEEF;
    ptr();
}

@end
