//
//  AsyncSafeMallocScenario.m
//  iOSTestApp
//
//  Created by Nick Dowell on 22/02/2021.
//  Copyright © 2021 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#include "spin_malloc.h"

@interface AsyncSafeMallocScenario : Scenario

@end

@implementation AsyncSafeMallocScenario

- (void)run {
    // Override malloc() with an implementation that will cause a deadlock for any thread that calls malloc()
    install_spin_malloc();
    
    // If the signal handler calls malloc(), the app will hang instead of terminating immediately.
    abort();
}

@end
