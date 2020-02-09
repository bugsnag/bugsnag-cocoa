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
    NSString *apiKey = @"<YOUR_APIKEY_HERE>";
    NSError *error;
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:apiKey
                                                                                 error:&error];
    [Bugsnag startBugsnagWithConfiguration:configuration];
    
    if (error) {
        NSLog(@"There was an error while starting Bugsnag: %@", [error localizedDescription]);
    }
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
