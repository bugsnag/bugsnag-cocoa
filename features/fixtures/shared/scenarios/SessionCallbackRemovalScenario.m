//
//  SessionCallbackRemovalScenario.m
//  iOSTestApp
//
//  Created by Jamie Lynch on 27/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "SessionCallbackRemovalScenario.h"

#import <Bugsnag/Bugsnag.h>


@implementation SessionCallbackRemovalScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = false;

    [self.config addOnSessionBlock:^BOOL(BugsnagSession * _Nonnull session) {
        session.app.id = @"customAppId";
        session.device.id = @"customDeviceId";
        return true;
    }];

    id block = ^BOOL(BugsnagSession * _Nonnull session) {
        session.app.id = nil;
        session.device.id = nil;
        return true;
    };
    [self.config addOnSessionBlock:block];
    [self.config removeOnSessionBlock:block];
    [super startBugsnag];
}

- (void)run {
    [Bugsnag startSession];
}

@end
