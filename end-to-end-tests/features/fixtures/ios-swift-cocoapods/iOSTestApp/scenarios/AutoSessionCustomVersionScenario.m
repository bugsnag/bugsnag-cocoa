//
//  AutoSessionCustomVersionScenario.m
//  iOSTestApp
//
//  Created by Delisa on 7/16/18.
//  Copyright © 2018 Bugsnag. All rights reserved.
//

#import "AutoSessionCustomVersionScenario.h"

@implementation AutoSessionCustomVersionScenario

- (void)startBugsnag {
    self.config.appVersion = @"2.0.14";
    [super startBugsnag];
}

- (void)run {

}

@end
