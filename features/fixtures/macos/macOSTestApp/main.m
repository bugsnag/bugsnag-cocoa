//
//  main.m
//  macOSTestApp
//
//  Created by Nick on 29/10/2020.
//  Copyright (c) 2020 Bugsnag Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

void NotificationCallback(CFNotificationCenterRef center, void *observer, CFNotificationName cfName, const void *object, CFDictionaryRef userInfo) {
    NSString *name = (__bridge NSString *)cfName;
    // Ignore high-frequency notifications
    if (name == NSMenuDidAddItemNotification ||
        name == NSMenuDidChangeItemNotification ||
        name == NSViewDidUpdateTrackingAreasNotification ||
        name == NSViewFrameDidChangeNotification ||
        [name hasSuffix:@"UpdateNotification"] ||
        false) {
        return;
    }
    NSLog(@"%@", name);
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
    
    // Log (almost) all notifications to aid in diagnosing Appium test flakes
    CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(),
                                    NULL, NotificationCallback, NULL, NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    
    return NSApplicationMain(argc, argv);
}
