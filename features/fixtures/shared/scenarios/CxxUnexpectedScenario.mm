//
//  CxxUnexpectedScenario.mm
//  iOSTestApp
//
//  Created by Delisa Fuller on 2/24/22.
//  Copyright © 2022 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#import <stdexcept>

@interface CxxUnexpectedScenario : Scenario
@end

@implementation CxxUnexpectedScenario

- (void)run {
    std::unexpected();
}

@end
