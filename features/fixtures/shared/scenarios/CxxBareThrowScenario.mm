//
//  CxxBareThrowScenario.mm
//  macOSTestApp
//
//  Created by Delisa Fuller on 2/24/22.
//  Copyright © 2022 Bugsnag Inc. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"
#import <stdexcept>

@interface CxxBareThrowScenario : Scenario
@end

@implementation CxxBareThrowScenario

- (void)run {
    [[NSThread mainThread] setName:@"œ´¨ø“‘"];
    try {
        throw;
    } catch (...) {
        // hmm!
    }
}

@end

@interface CxxBareThrowAfterCatchScenario : CxxBareThrowScenario
@end

@implementation CxxBareThrowAfterCatchScenario

- (void)run {
    // A caught exception must not supply the trace for a later bare throw.
    try {
        [self throwCaughtException];
    } catch (const std::exception &) {
    }
    [super run];
}

- (void)throwCaughtException __attribute__((noreturn)) {
    throw std::runtime_error("Previously caught exception");
}

@end
