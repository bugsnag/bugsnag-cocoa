//
//  AppDelegate.m
//  macOSTestApp
//
//  Created by Nick on 29/10/2020.
//  Copyright (c) 2020 Bugsnag Inc. All rights reserved.
//

#import "AppDelegate.h"

#import "MainWindowController.h"


@interface AppDelegate ()

@property NSWindowController *mainWindowController;

@end

#pragma mark -

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.mainWindowController = [[MainWindowController alloc] initWithWindowNibName:@"MainWindowController"];
    [self.mainWindowController showWindow:self];
    [NSApp activateIgnoringOtherApps:YES];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (void)application:(NSApplication *)application openURLs:(NSArray<NSURL *> *)urls {
    NSLog(@"%s %@", __PRETTY_FUNCTION__, urls);
    for (NSURL *url in urls) {
        if ([url.scheme isEqualToString:@"macOSTestApp"] &&
            [url.path isEqualToString:@"/mainWindowController"]) {
            NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
            for (NSURLQueryItem *queryItem in components.queryItems) {
                [self.mainWindowController setValue:queryItem.value forKeyPath:queryItem.name];
            }
        }
    }
}

@end
