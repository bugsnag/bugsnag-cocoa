//
//  OnSendErrorPersistenceScenario.m
//  macOSTestApp
//
//  Created by Nick Dowell on 16/12/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "Scenario.h"

NSString * const HasNotifiedKey = @"OnSendErrorPersistenceScenario.hasNotified";

@interface OnSendErrorPersistenceScenario : Scenario
@property BOOL hasNotified;
@end

@implementation OnSendErrorPersistenceScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = NO;
    
    if (!self.hasNotified) {
        [self.config addOnSendErrorBlock:^BOOL(BugsnagEvent *event) {
            [event addMetadata:@"Hello" withKey:@"message" toSection:@"unexpected"];
            return YES;
        }];
    }
    
    [super startBugsnag];
}

- (void)run {
    if (!self.hasNotified) {
        [Bugsnag notifyError:[NSError errorWithDomain:@"NotAnError" code:0 userInfo:nil]];
        self.hasNotified = YES;
    }
}

- (BOOL)hasNotified {
    return [NSUserDefaults.standardUserDefaults boolForKey:HasNotifiedKey];
}

- (void)setHasNotified:(BOOL)hasNotified {
    [NSUserDefaults.standardUserDefaults setBool:hasNotified forKey:HasNotifiedKey];
}

@end
