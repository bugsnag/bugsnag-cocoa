//
//  AppDelegate.m
//  Bugsnag Test App
//
//  Created by Simon Maynard on 1/18/13.
//  Copyright (c) 2013 Simon Maynard. All rights reserved.
//

#import "AppDelegate.h"
#import <Bugsnag/Bugsnag.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    NSString *apiKey = @"e508b95352442d9f550bbc7053b93969";
    BugsnagConfiguration *config = [BugsnagConfiguration new];
    config.apiKey = apiKey;
    [Bugsnag startBugsnagWithConfiguration:config];
    
    return YES;
}

@end
