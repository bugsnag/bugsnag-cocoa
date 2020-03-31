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

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [Bugsnag startBugsnagWithApiKey:@"33b6f0317a8c802940da6dbeabd6fed3"];
    //[self startBugsnagWithConfiguration];
    return YES;
}

@end
