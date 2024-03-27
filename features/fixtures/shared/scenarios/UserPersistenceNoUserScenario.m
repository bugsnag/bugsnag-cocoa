//
//  UserPersistenceNoUserScenario.m
//  iOSTestApp
//
//  Created by Robin Macharg on 24/02/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"

/**
 * Don't set a user, don't change persistence (defaults to True).
 */
@interface UserPersistenceNoUserScenario : Scenario
@end

@implementation UserPersistenceNoUserScenario

- (void)run {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [Bugsnag notifyError:[NSError errorWithDomain:@"com.bugsnag" code:833 userInfo:nil]];
    });
}

@end
