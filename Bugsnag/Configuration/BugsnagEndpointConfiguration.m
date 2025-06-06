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
    BugsnagEndpointConfiguration *cfg = [BugsnagEndpointConfiguration new];
    if ([apiKey hasPrefix:BSGHubPrefix]) {
        cfg.notify   = BSGHubNotifyURL;
        cfg.sessions = BSGHubSessionURL;
    }
    return cfg;
}
@end
