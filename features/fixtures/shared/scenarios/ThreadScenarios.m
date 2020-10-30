//
//  ThreadScenarios.m
//  iOSTestApp
//
//  Created by Jamie Lynch on 12/06/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "ThreadScenarios.h"

@implementation HandledErrorThreadSendAlwaysScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = false;
    [super startBugsnag];
}

- (void)run {
    NSException *exc = [NSException exceptionWithName:@"HandledErrorThreadSendAlwaysScenario" reason:@"HandledErrorThreadSendAlwaysScenario" userInfo:nil];
    [Bugsnag notify:exc];
}

@end

@implementation UnhandledErrorThreadSendAlwaysScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = false;
    [super startBugsnag];
}

- (void)run {
    NSException *exc = [NSException exceptionWithName:@"UnhandledErrorThreadSendAlwaysScenario" reason:@"UnhandledErrorThreadSendAlwaysScenario" userInfo:nil];
    [exc raise];
}

@end

@implementation HandledErrorThreadSendUnhandledOnlyScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = false;
    self.config.sendThreads = BSGThreadSendPolicyUnhandledOnly;
    [super startBugsnag];
}

- (void)run {
    NSException *exc = [NSException exceptionWithName:@"HandledErrorThreadSendUnhandledOnlyScenario" reason:@"HandledErrorThreadSendUnhandledOnlyScenario" userInfo:nil];
    [Bugsnag notify:exc];
}
@end

@implementation UnhandledErrorThreadSendNeverScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = false;
    self.config.sendThreads = BSGThreadSendPolicyNever;
    [super startBugsnag];
}

- (void)run {
    NSException *exc = [NSException exceptionWithName:@"UnhandledErrorThreadSendNeverScenario" reason:@"UnhandledErrorThreadSendNeverScenario" userInfo:nil];
    [exc raise];
}

@end
