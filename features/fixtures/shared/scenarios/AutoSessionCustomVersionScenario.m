//
//  AutoSessionCustomVersionScenario.m
//  iOSTestApp
//
//  Created by Delisa on 7/16/18.
//  Copyright © 2018 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"

@interface AutoSessionCustomVersionScenario : Scenario
@end

@implementation AutoSessionCustomVersionScenario

- (void)configure {
    [super configure];
    [self.config addOnSessionBlock:^BOOL(BugsnagSession * _Nonnull session) {
        session.app.version = @"2.0.14";
        return true;
    }];
}

- (void)run {

}

@end
