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

@property MainWindowController *mainWindowController;

@end

#pragma mark -

@implementation AppDelegate

- (BOOL)launchedByMazeRunner {
    return [[[NSProcessInfo processInfo] environment] objectForKey:@"MAZE_RUNNER"] != nil;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.mainWindowController = [[MainWindowController alloc] initWithWindowNibName:@"MainWindowController"];
    [self.mainWindowController showWindow:self];
    
    if ([self launchedByMazeRunner]) {
        [NSApp activateIgnoringOtherApps:YES];
    }
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    static BOOL once;
    if (!once && [self launchedByMazeRunner]) {
        once = YES;
        [self.mainWindowController executeMazeRunnerCommand:self];
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end
