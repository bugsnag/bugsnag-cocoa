//
// Created by Jamie Lynch on 12/04/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

#import "BuiltinTrapScenario.h"

/**
 * Calls __builtin_trap
 */
@implementation BuiltinTrapScenario


- (void)run {
    __builtin_trap();
}

@end