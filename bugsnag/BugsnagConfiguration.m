//
//  BugsnagConfiguration.m
//  bugsnag
//
//  Created by Simon Maynard on 8/28/13.
//  Copyright (c) 2013 Simon Maynard. All rights reserved.
//

#import "BugsnagConfiguration.h"

@implementation BugsnagConfiguration

- (id) init {
    if(self = [super init]) {
        self.enableSSL = YES;
        self.autoNotify = YES;
        self.collectMAU = YES;
        self.metaData = [[BugsnagMetaData alloc] init];
        self.userData = [[NSMutableDictionary alloc] init];
        
        self.uuidPath = @"bugsnag-user-id";
        self.beforeBugsnagNotifyBlocks = [NSMutableArray array];
#if DEBUG
        self.releaseStage = @"development";
#else
        self.releaseStage = @"production";
#endif
    }
    return self;
}

- (NSURL*) metricsURL {
    return [self.notifyURL URLByAppendingPathComponent:@"metrics"];
}

- (NSURL*) notifyURL {
    if(self.notifyEndpoint) {
        return [NSURL URLWithString:self.notifyEndpoint];
    } else if (self.enableSSL) {
        return [NSURL URLWithString:@"https://notify.bugsnag.com"];
    } else {
        return [NSURL URLWithString:@"http://notify.bugsnag.com"];
    }
}

- (void) setUser: (NSString*)userId withName:(NSString *)userName andEmail:(NSString*)userEmail {
    self.userId = userId;
    self.userName = userName;
    self.userEmail = userEmail;
}

- (NSString*) userEmail {
    return [self.userData objectForKey: @"email"];
}
- (void) setUserEmail:(NSString*) userEmail {
    [self.userData setValue:userEmail forKey: @"email"];
}

- (NSString*) userId {
    return [self.userData objectForKey: @"id"];
}
- (void) setUserId:(NSString*) userId {
    [self.userData setValue:userId forKey: @"id"];
}

- (NSString*) userName {
    return [self.userData objectForKey: @"name"];
}
- (void) setUserName:(NSString*) userName {
    [self.userData setValue:userName forKey: @"name"];
}

@end
