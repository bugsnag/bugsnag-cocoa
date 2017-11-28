//
//  BugsnagSessionTrackingPayload.m
//  Bugsnag
//
//  Created by Jamie Lynch on 27/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import "BugsnagSessionTrackingPayload.h"
#import "BugsnagCollections.h"
#import "BugsnagNotifier.h"
#import "Bugsnag.h"
#import "BugsnagKeys.h"
#import "BSG_KSSystemInfo.h"

@interface Bugsnag ()
+ (BugsnagNotifier *)notifier;
@end

@implementation BugsnagSessionTrackingPayload

- (NSDictionary *)toJson {
    
    NSMutableDictionary *dict = [NSMutableDictionary new];
    NSMutableArray *sessionData = [NSMutableArray new];
    
    for (BugsnagSession *session in self.sessions) {
        [sessionData addObject:[session toJson]];
    }
    BSGDictInsertIfNotNil(dict, sessionData, @"sessions");
    BSGDictSetSafeObject(dict, [Bugsnag notifier].details, BSGKeyNotifier);
    
    NSDictionary *systemInfo = [BSG_KSSystemInfo systemInfo];
    
    NSLog(@"%@", systemInfo);
//    BSGDictSetSafeObject(dict, systemInfo, @"todo");
    
    
//    Printing description of report:
//    {
//        CFBundleExecutable = "<null>";
//        CFBundleExecutablePath = "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/Xcode/Agents";
//        CFBundleIdentifier = "<null>";
//        CFBundleName = "<null>";
//        CFBundleShortVersionString = "<null>";
//        CFBundleVersion = "<null>";
//        "app_start_time" = "2017-11-28 14:46:08 +0000";
//        "app_uuid" = "E216CDBF-CFC7-34F0-8BF5-09DA1445D2A3";
//        "binary_cpu_subtype" = 3;
//        "binary_cpu_type" = 16777223;
//        "boot_time" = "2017-10-19 08:20:09 +0000";
//        "build_type" = simulator;
//        "cpu_arch" = x86;
//        "cpu_subtype" = 8;
//        "cpu_type" = 7;
//        "device_app_hash" = 5881e6949dd40c698505a75d57ece5ce8105d53e;
//        jailbroken = 0;
//        "kernel_version" = "Darwin Kernel Version 17.0.0: Thu Aug 24 21:48:19 PDT 2017; root:xnu-4570.1.46~2/RELEASE_X86_64";
//        machine = "iPhone10,5";
//        memory =     {
//            size = 17179869184;
//        };
//        model = simulator;
//        "os_version" = 17A405;
//        "parent_process_id" = 68060;
//        "process_id" = 68059;
//        "process_name" = xctest;
//        "system_name" = iOS;
//        "system_version" = "11.1";
//        "time_zone" = GMT;
//    }
    
    
    
    
//    NSDictionary *BSGParseApp(NSDictionary *report, NSString *appVersion) {
//        NSDictionary *system = report[BSGKeySystem];
//        NSMutableDictionary *app = [NSMutableDictionary dictionary];
//
//        BSGDictSetSafeObject(app, system[@"CFBundleVersion"], @"bundleVersion");
//        BSGDictSetSafeObject(app, system[@"CFBundleIdentifier"], BSGKeyId);
//        BSGDictSetSafeObject(app, system[BSGKeyExecutableName], BSGKeyName);
//        BSGDictSetSafeObject(app, [Bugsnag configuration].releaseStage,
//                             BSGKeyReleaseStage);
//        if ([appVersion isKindOfClass:[NSString class]]) {
//            BSGDictSetSafeObject(app, appVersion, BSGKeyVersion);
//        } else {
//            BSGDictSetSafeObject(app, system[@"CFBundleShortVersionString"],
//                                 BSGKeyVersion);
//        }
//
//        return app;
//    }
//
//    NSDictionary *BSGParseAppState(NSDictionary *report) {
//        NSDictionary *appStats = report[BSGKeySystem][@"application_stats"];
//        NSMutableDictionary *appState = [NSMutableDictionary dictionary];
//        NSInteger activeTimeSinceLaunch =
//        [appStats[@"active_time_since_launch"] doubleValue] * 1000.0;
//        NSInteger backgroundTimeSinceLaunch =
//        [appStats[@"background_time_since_launch"] doubleValue] * 1000.0;
//
//        BSGDictSetSafeObject(appState, @(activeTimeSinceLaunch),
//                             @"durationInForeground");
//        BSGDictSetSafeObject(appState,
//                             @(activeTimeSinceLaunch + backgroundTimeSinceLaunch),
//                             @"duration");
//        BSGDictSetSafeObject(appState, appStats[@"application_in_foreground"],
//                             @"inForeground");
//        BSGDictSetSafeObject(appState, appStats, @"stats");
//
//        return appState;
//    }
//
//    NSDictionary *BSGParseDeviceState(NSDictionary *report) {
//        NSMutableDictionary *deviceState =
//        [[report valueForKeyPath:@"user.state.deviceState"] mutableCopy];
//        BSGDictSetSafeObject(deviceState,
//                             [report valueForKeyPath:@"system.memory.free"],
//                             @"freeMemory");
//        BSGDictSetSafeObject(deviceState,
//                             [report valueForKeyPath:@"report.timestamp"], @"time");
//
//        BSGDictSetSafeObject(deviceState,
//                             [report valueForKeyPath:@"system.jailbroken"], @"jailbroken");
//
//        NSFileManager *fileManager = [NSFileManager defaultManager];
//        NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(
//                                                                   NSDocumentDirectory, NSUserDomainMask, true);
//        NSString *path = [searchPaths lastObject];
//
//        NSError *error;
//        NSDictionary *fileSystemAttrs =
//        [fileManager attributesOfFileSystemForPath:path error:&error];
//
//        if (error) {
//            bsg_log_warn(@"Failed to read free disk space: %@", error);
//        }
//
//        NSNumber *freeBytes = [fileSystemAttrs objectForKey:NSFileSystemFreeSize];
//        BSGDictSetSafeObject(deviceState, freeBytes, @"freeDisk");
//        return deviceState;
//    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    // TODO serialise below!
    
//    // Top level info that is unlikely change between sessions on one device (in the notifier batch period)
//    "device": {
//        "hostname": "Mikes-Ipad",
//        "jailbroken": false,
//        "manufacturer": "Apple",
//        "model": "iPad3,2",
//        "modelNumber": "123",
//        "osName": "iOS",
//        "osVersion": "7.0.4",
//        "userAgent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/54.0.2840.98 Safari/537.36"
//    },
//    "app": {
//        "type": "sidekiq",
//        "releaseStage": "production",
//        "version": "1.1",
//        "versionCode": 123,
//        "bundleVersion": "123",
//        "codeBundleId": "1111"
//    },
    
    
    return [NSDictionary dictionaryWithDictionary:dict];
}

@end
