//
//  main.m
//  macOSTestApp
//
//  Created by Nick on 29/10/2020.
//  Copyright (c) 2020 Bugsnag Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

int main(int argc, const char * argv[]) {
    NSString *tmpdir = [[[NSProcessInfo processInfo] environment] objectForKey:@"TMPDIR"];
    [[NSFileManager defaultManager] removeItemAtPath:
     // Avoids a crash observed in -[NSPersistentUICrashHandler inspectCrashDataWithModification:handler:]
     // that seems to occur if "$TMPDIR/com.bugsnag.fixtures.macOSTestApp.savedState" is corrupted
     [tmpdir stringByAppendingPathComponent:@"com.bugsnag.fixtures.macOSTestApp.savedState"] error:nil];
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        // Disable state restoration to prevent the following dialog being shown after crashes
        // "The last time you opened macOSTestApp, it unexpectedly quit while reopening windows.
        //  Do you want to try to reopen its windows again?"
        // https://developer.apple.com/library/archive/releasenotes/AppKit/RN-AppKitOlderNotes/index.html#10_7StateRestoration
        @"ApplePersistenceIgnoreState": @YES,
        // Stop NSApplication swallowing NSExceptions thrown on the main thread.
        @"NSApplicationCrashOnExceptions": @YES,
    }];
    
    return NSApplicationMain(argc, argv);
}
