//
//  UserPersistenceDontPersistUserScenario.m
//  iOSTestApp
//
//  Created by Robin Macharg on 24/02/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"

/**
 * Set a user but don't persist it
 */
@interface UserPersistenceDontPersistUserScenario : Scenario
@end

@implementation UserPersistenceDontPersistUserScenario

- (void)configure {
    [super configure];
    self.config.persistUser = NO;
    [self.config setUser:@"john" withEmail:@"george@ringo.com" andName:@"paul"];
}

- (void)run {
    [Bugsnag notifyError:[NSError errorWithDomain:@"com.bugsnag" code:833 userInfo:nil]];
}

@end
