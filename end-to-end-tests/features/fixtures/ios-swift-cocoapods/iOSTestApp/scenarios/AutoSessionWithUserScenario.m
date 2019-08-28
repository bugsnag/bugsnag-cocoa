//
//  AutoSessionWithUserScenario.m
//  iOSTestApp
//
//  Created by Delisa on 7/13/18.
//  Copyright © 2018 Bugsnag. All rights reserved.
//

#import "AutoSessionWithUserScenario.h"

@implementation AutoSessionWithUserScenario

- (void)startBugsnag {
    [self.config setUser:@"123" withName:@"Joe Bloggs" andEmail:@"joe@example.com"];
    [super startBugsnag];
}

- (void) run {
    
}

@end
