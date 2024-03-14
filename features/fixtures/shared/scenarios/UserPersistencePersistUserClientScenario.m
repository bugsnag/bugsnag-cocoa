//
//  UserPersistencePersistUserClientScenario.m
//  iOSTestApp
//
//  Created by Robin Macharg on 24/02/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"

/**
 * Set a user on the client and persist it
 */
@interface UserPersistencePersistUserClientScenario : Scenario
@end

@implementation UserPersistencePersistUserClientScenario

- (void)configure {
    [super configure];
    self.config.persistUser = YES;
}

- (void)run {
    [Bugsnag setUser:@"foo" withEmail:@"baz@grok.com" andName:@"bar"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [Bugsnag notifyError:[NSError errorWithDomain:@"com.bugsnag" code:833 userInfo:nil]];
    });
}

@end
