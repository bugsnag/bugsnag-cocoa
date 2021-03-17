//
// Created by Jamie Lynch on 12/04/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

#import "BuiltinTrapScenario.h"
#include "spin_malloc.h"

/**
 * Calls __builtin_trap
 */
@implementation BuiltinTrapScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = NO;
    [super startBugsnag];
}


- (void)run {
    install_spin_malloc();
    __builtin_trap();
}

@end
