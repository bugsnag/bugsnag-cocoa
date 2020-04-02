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
#import "Private.h"

NSDictionary *BSGParseDeviceMetadata(NSDictionary *event) {
    NSMutableDictionary *device = [NSMutableDictionary new];
    NSDictionary *state = [event valueForKeyPath:@"user.state.deviceState"];
    [device addEntriesFromDictionary:state];
    BSGDictSetSafeObject(device, [event valueForKeyPath:@"system.time_zone"], @"timezone");

#if TARGET_OS_SIMULATOR
    BSGDictSetSafeObject(device, @YES, @"simulator");
#elif TARGET_OS_IPHONE || TARGET_OS_TV
    BSGDictSetSafeObject(device, @NO, @"simulator");
#endif

    BSGDictSetSafeObject(device, @(PLATFORM_WORD_SIZE), @"wordSize");
    return device;
}
