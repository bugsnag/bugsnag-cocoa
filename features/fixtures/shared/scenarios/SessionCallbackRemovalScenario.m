//
//  SessionCallbackRemovalScenario.m
//  iOSTestApp
//
//  Created by Jamie Lynch on 27/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"

@interface SessionCallbackRemovalScenario : Scenario
@end

@implementation SessionCallbackRemovalScenario

- (void)configure {
    [super configure];
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
    BugsnagOnSessionRef onSession = [self.config addOnSessionBlock:block];
    [self.config removeOnSession:onSession];
}

- (void)run {
    [Bugsnag startSession];
}

@end
