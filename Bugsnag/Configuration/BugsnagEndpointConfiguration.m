//
//  BugsnagEndpointConfiguration.m
//  Bugsnag
//
//  Created by Jamie Lynch on 15/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "BugsnagEndpointConfiguration.h"

static NSString *const BSGBugsnagNotifyURL   = @"https://notify.bugsnag.com";
static NSString *const BSGBugsnagSessionURL  = @"https://sessions.bugsnag.com";
static NSString *const BSGHubNotifyURL   = @"https://notify.bugsnag.smartbear.com";
static NSString *const BSGHubSessionURL  = @"https://sessions.bugsnag.smartbear.com";
static NSString *const BSGBugsnagConfigurationURL  = @"https://config.bugsnag.com/error-config";
static NSString *const BSGHubPrefix      = @"00000";

@implementation BugsnagEndpointConfiguration

- (instancetype)init {
    return [self initWithNotify:BSGBugsnagNotifyURL
                       sessions:BSGBugsnagSessionURL
                  configuration:BSGBugsnagConfigurationURL];
}

- (instancetype)initWithNotify:(NSString *)notify sessions:(NSString *)sessions {
    return [self initWithNotify:notify
                       sessions:sessions
                  configuration:nil];
}

- (instancetype)initWithNotify:(NSString *)notify
                      sessions:(NSString *)sessions
                 configuration:(NSString * __nullable)configuration {
    if ((self = [super init])) {
        _notify = notify;
        _sessions = sessions;
        _configuration = configuration;
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
            BSGBugsnagNotifyURL,
            BSGHubNotifyURL,
            nil];
        knownSessions = [NSSet setWithObjects:
            BSGBugsnagSessionURL,
            BSGHubSessionURL,
            nil];
    });

    return !([knownNotify containsObject:self.notify] &&
             [knownSessions containsObject:self.sessions]);
}
@end
