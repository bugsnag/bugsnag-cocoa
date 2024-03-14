//
// Created by Jamie Lynch on 12/04/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"

#import "spin_malloc.h"

/**
 * Calls __builtin_trap
 */
@interface BuiltinTrapScenario : Scenario
@end

@implementation BuiltinTrapScenario

- (void)configure {
    [super configure];
    self.config.autoTrackSessions = NO;
}


- (void)run {
    install_spin_malloc();
    __builtin_trap();
}

@end
