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
    
    NSString *apiKey = @"<YOUR_APIKEY_HERE>";
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:apiKey];
    [Bugsnag startBugsnagWithConfiguration:configuration];
    
    return YES;
}

@end
