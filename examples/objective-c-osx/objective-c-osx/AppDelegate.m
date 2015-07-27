//
//  AppDelegate.m
//  objective-c-osx
//
//  Created by Simon Maynard on 7/24/15.
//  Copyright (c) 2015 Bugsnag. All rights reserved.
//

#import "AppDelegate.h"
#import <Bugsnag/Bugsnag.h>

@interface AppDelegate ()

@end

void exceptionHandler(NSException *ex) {
    NSLog(@"%@", [ex reason]);
}

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    //NSSetUncaughtExceptionHandler(&exceptionHandler);
    [Bugsnag startBugsnagWithApiKey:@"f35a2472bd230ac0ab0f52715bbdc65d"];
    // Insert code here to initialize your application
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
