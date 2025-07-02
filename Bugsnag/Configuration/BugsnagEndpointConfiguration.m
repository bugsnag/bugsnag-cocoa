//
//  BugsnagEndpointConfiguration.m
//  Bugsnag
//
//  Created by Jamie Lynch on 15/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "BugsnagEndpointConfiguration.h"

static NSString *const BSGHubNotifyURL   = @"https://notify.insighthub.smartbear.com";
static NSString *const BSGHubSessionURL  = @"https://sessions.insighthub.smartbear.com";
static NSString *const BSGHubPrefix      = @"00000";

@implementation BugsnagEndpointConfiguration

- (instancetype)init {
    if ((self = [super init])) {
        _notify = @"https://notify.bugsnag.com";
        _sessions = @"https://sessions.bugsnag.com";
    }
    return self;
}

- (instancetype)initWithNotify:(NSString *)notify sessions:(NSString *)sessions {
    if ((self = [super init])) {
        _notify = notify;
        _sessions = sessions;
    }
    return self;
}

+ (instancetype)defaultForApiKey:(NSString *)apiKey {
    BugsnagEndpointConfiguration *endpoints = [BugsnagEndpointConfiguration new];
    if ([apiKey hasPrefix:BSGHubPrefix]) {
        endpoints.notify   = BSGHubNotifyURL;
        endpoints.sessions = BSGHubSessionURL;
    }
    return endpoints;
}

- (BOOL)isCustom {
    static NSSet<NSString *> *knownNotify;
    static NSSet<NSString *> *knownSessions;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        knownNotify = [NSSet setWithObjects:
            @"https://notify.bugsnag.com",
            BSGHubNotifyURL,
            nil];
        knownSessions = [NSSet setWithObjects:
            @"https://sessions.bugsnag.com",
            BSGHubSessionURL,
            nil];
    });

    return !([knownNotify containsObject:self.notify] &&
             [knownSessions containsObject:self.sessions]);
}
@end
