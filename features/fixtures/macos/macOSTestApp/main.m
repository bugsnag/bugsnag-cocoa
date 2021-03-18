//
//  main.m
//  macOSTestApp
//
//  Created by Nick on 29/10/2020.
//  Copyright (c) 2020 Bugsnag Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

void sigterm(int signum) {
    NSLog(@"Received SIGTERM");
    exit(0);
}

int main(int argc, const char * argv[]) {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        // Disable state restoration to prevent the following dialog being shown after crashes
        // "The last time you opened macOSTestApp, it unexpectedly quit while reopening windows.
        //  Do you want to try to reopen its windows again?"
        // https://developer.apple.com/library/archive/releasenotes/AppKit/RN-AppKitOlderNotes/index.html#10_7StateRestoration
        @"ApplePersistenceIgnoreState": @YES,
        // Stop NSApplication swallowing NSExceptions thrown on the main thread.
        @"NSApplicationCrashOnExceptions": @YES,
    }];
    
    sigaction(SIGTERM, &(struct sigaction){ .sa_handler = &sigterm }, NULL);
    
    return NSApplicationMain(argc, argv);
}
