//
//  UserPersistenceScenarios.m
//  iOSTestApp
//
//  Created by Robin Macharg on 24/02/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UserPersistenceScenarios.h"

/**
 * Set a user and persist it
 */
@implementation UserPersistencePersistUserScenario

- (void)startBugsnag {
    self.config.persistUser = YES;
    [self.config setUser:@"foo" withName:@"bar" andEmail:@"baz@grok.com"];
    [super startBugsnag];
}

- (void)run {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [Bugsnag notifyError:[NSError errorWithDomain:@"com.bugsnag" code:833 userInfo:nil]];
    });
}

@end

/**
 * Set a user but don't persist it
 */
@implementation UserPersistenceDontPersistUserScenario

- (void)startBugsnag {
    self.config.persistUser = NO;
    [self.config setUser:@"john" withName:@"paul" andEmail:@"george@ringo.com"];
    [super startBugsnag];
}

- (void)run {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [Bugsnag notifyError:[NSError errorWithDomain:@"com.bugsnag" code:833 userInfo:nil]];
    });
}

@end

/**
 * Don't set a user, don't change persistence (defaults to True).
 */
@implementation UserPersistenceNoUserScenario

- (void)startBugsnag {
    [super startBugsnag];
}

- (void)run {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [Bugsnag notifyError:[NSError errorWithDomain:@"com.bugsnag" code:833 userInfo:nil]];
    });
}

@end
