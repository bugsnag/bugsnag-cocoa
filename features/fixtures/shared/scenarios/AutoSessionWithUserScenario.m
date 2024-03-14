//
//  AutoSessionWithUserScenario.m
//  iOSTestApp
//
//  Created by Delisa on 7/13/18.
//  Copyright © 2018 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"

@interface AutoSessionWithUserScenario : Scenario
@end

@implementation AutoSessionWithUserScenario

- (void)configure {
    [super configure];
    [self.config setUser:@"123" withEmail:@"joe@example.com" andName:@"Joe Bloggs"];
}

- (void)run {
}

@end
