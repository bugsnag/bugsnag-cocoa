//
//  BugsnagKSCrashSysInfoParser.m
//  Bugsnag
//
//  Created by Jamie Lynch on 28/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import "BugsnagKSCrashSysInfoParser.h"
#import "Bugsnag.h"
#import "BugsnagCollections.h"
#import "BugsnagKeys.h"
#import "BugsnagConfiguration.h"
#import "BugsnagLogger.h"

NSDictionary *BSGParseDevice(NSDictionary *report) {
    NSMutableDictionary *device = [NSMutableDictionary dictionary];
    
    BSGDictSetSafeObject(device, @"Apple", @"manufacturer");
    BSGDictSetSafeObject(device, [[NSLocale currentLocale] localeIdentifier],
                         @"locale");
    
    BSGDictSetSafeObject(device, report[@"device_app_hash"], @"id");
    BSGDictSetSafeObject(device, report[@"time_zone"], @"timezone");
    BSGDictSetSafeObject(device, report[@"model"], @"modelNumber");
    BSGDictSetSafeObject(device, report[@"machine"], @"model");
    BSGDictSetSafeObject(device, report[@"system_name"], @"osName");
    BSGDictSetSafeObject(device, report[@"system_version"], @"osVersion");
    BSGDictSetSafeObject(device, report[@"memory"][@"usable"],
                         @"totalMemory");
    return device;
}

NSDictionary *BSGParseApp(NSDictionary *report) {
    NSMutableDictionary *app = [NSMutableDictionary dictionary];
    NSString *appVersion = [Bugsnag configuration].appVersion;
    
    BSGDictSetSafeObject(app, report[@"CFBundleVersion"], @"bundleVersion");
    BSGDictSetSafeObject(app, report[@"CFBundleIdentifier"], BSGKeyId);
    BSGDictSetSafeObject(app, report[BSGKeyExecutableName], BSGKeyName);
    BSGDictSetSafeObject(app, [Bugsnag configuration].releaseStage,
                         BSGKeyReleaseStage);
    if ([appVersion isKindOfClass:[NSString class]]) {
        BSGDictSetSafeObject(app, appVersion, BSGKeyVersion);
    } else {
        BSGDictSetSafeObject(app, report[@"CFBundleShortVersionString"],
                             BSGKeyVersion);
    }
    
    return app;
}

NSDictionary *BSGParseAppState(NSDictionary *report) {
    NSMutableDictionary *appState = [NSMutableDictionary dictionary];
    NSInteger activeTimeSinceLaunch =
    [report[@"active_time_since_launch"] doubleValue] * 1000.0;
    NSInteger backgroundTimeSinceLaunch =
    [report[@"background_time_since_launch"] doubleValue] * 1000.0;
    
    BSGDictSetSafeObject(appState, @(activeTimeSinceLaunch),
                         @"durationInForeground");
    BSGDictSetSafeObject(appState,
                         @(activeTimeSinceLaunch + backgroundTimeSinceLaunch),
                         @"duration");
    BSGDictSetSafeObject(appState, report[@"application_in_foreground"],
                         @"inForeground");
    BSGDictSetSafeObject(appState, report, @"stats");
    
    return appState;
}

NSDictionary *BSGParseDeviceState(NSDictionary *report) { // FIXME support for non-crash reports!
    NSMutableDictionary *deviceState = [[report valueForKeyPath:@"user.state.deviceState"] mutableCopy];
    BSGDictSetSafeObject(deviceState,
                         [report valueForKeyPath:@"system.memory.free"],
                         @"freeMemory");
    
    BSGDictSetSafeObject(deviceState,
                         [report valueForKeyPath:@"system.jailbroken"], @"jailbroken");
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(
                                                               NSDocumentDirectory, NSUserDomainMask, true);
    NSString *path = [searchPaths lastObject];
    
    NSError *error;
    NSDictionary *fileSystemAttrs =
    [fileManager attributesOfFileSystemForPath:path error:&error];
    
    if (error) {
        bsg_log_warn(@"Failed to read free disk space: %@", error);
    }
    
    NSNumber *freeBytes = [fileSystemAttrs objectForKey:NSFileSystemFreeSize];
    BSGDictSetSafeObject(deviceState, freeBytes, @"freeDisk");
    return deviceState;
}

