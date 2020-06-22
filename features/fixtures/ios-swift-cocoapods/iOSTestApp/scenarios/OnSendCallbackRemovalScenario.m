//
//  OnSendCallbackRemovalScenario.m
//  iOSTestApp
//
//  Created by Jamie Lynch on 26/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "OnSendCallbackRemovalScenario.h"

/**
 * Verifies that removing an OnSend callback does not affect other OnSend callbacks
 */
@implementation OnSendCallbackRemovalScenario

- (void)startBugsnag {
    id block = ^BOOL(BugsnagEvent * _Nonnull event) {
        [event addMetadata:@"this should never happen" withKey:@"config" toSection:@"callbacks"];
        return true;
    };
    self.config.autoTrackSessions = false;
    [self.config addOnSendErrorBlock:block];

    [self.config addOnSendErrorBlock:^BOOL(BugsnagEvent * _Nonnull event) {
        [event addMetadata:@"adding metadata" withKey:@"config2" toSection:@"callbacks"];
        return true;
    }];
    [self.config removeOnSendErrorBlock:block];
    [super startBugsnag];
}

- (void)run {
    [Bugsnag notifyError:[NSError errorWithDomain:@"com.bugsnag" code:833 userInfo:nil]];
}
@end
