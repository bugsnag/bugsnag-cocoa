//
//  SIGSYSScenario.m
//  iOSTestApp
//
//  Created by Jamie Lynch on 26/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"

@interface SIGSYSScenario : Scenario
@end

@implementation SIGSYSScenario

- (void)configure {
    [super configure];
    self.config.autoTrackSessions = NO;
}

- (void)run {
    raise(SIGSYS);
}

@end
