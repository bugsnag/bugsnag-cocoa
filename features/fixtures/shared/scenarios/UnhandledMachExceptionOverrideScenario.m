//
//  UnhandledMachExceptionScenario.m
//  iOSTestApp
//
//  Created by Jamie Lynch on 26/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "MarkUnhandledHandledScenario.h"

@interface UnhandledMachExceptionOverrideScenario : MarkUnhandledHandledScenario
@end

@implementation UnhandledMachExceptionOverrideScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = NO;
    [super startBugsnag];
}

- (void)run {
    void (*ptr)(void) = (void *)0xDEADBEEF;
    ptr();
}

@end
