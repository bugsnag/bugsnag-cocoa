//
//  CxxBareThrowScenario.mm
//  macOSTestApp
//
//  Created by Delisa Fuller on 2/24/22.
//  Copyright © 2022 Bugsnag Inc. All rights reserved.
//

#import "Scenario.h"
#import <stdexcept>

@interface CxxBareThrowScenario : Scenario
@end

@implementation CxxBareThrowScenario

- (void)run {
    try {
        throw;
    } catch (...) {
        // hmm!
    }
}

@end
