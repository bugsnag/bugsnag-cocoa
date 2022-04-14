//
//  BugsnagSystemState.m
//  Bugsnag
//
//  Created by Karl Stenerud on 21.09.20.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import "BugsnagSystemState.h"

#if TARGET_OS_OSX
#import "BSGAppKit.h"
#else
#import "BSGUIKit.h"
#endif

#import <Bugsnag/Bugsnag.h>

#import "BSGFileLocations.h"
#import "BSGJSONSerialization.h"
#import "BSGRunContext.h"
#import "BSGUtils.h"
#import "BSG_KSCrashState.h"
#import "BSG_KSSystemInfo.h"
#import "BSG_RFC3339DateTool.h"
#import "BugsnagLogger.h"
#import "BugsnagSession+Private.h"

#import <stdatomic.h>

#define SYSTEMSTATE_APP_VERSION @"version"
#define SYSTEMSTATE_APP_BUNDLE_VERSION @"bundleVersion"

#define SYSTEMSTATE_DEVICE_BOOT_TIME @"bootTime"

static NSString * const ConsecutiveLaunchCrashesKey = @"consecutiveLaunchCrashes";
static NSString * const InternalKey = @"internal";

static NSDictionary * loadPreviousState(NSString *jsonPath) {
    if (!bsg_lastRunContext) {
        return @{};
    }

    NSError *error = nil;
    NSMutableDictionary *state = [BSGJSONSerialization JSONObjectWithContentsOfFile:jsonPath options:NSJSONReadingMutableContainers error:&error];
    if(![state isKindOfClass:[NSMutableDictionary class]]) {
        bsg_log_err(@"Could not load system_state.json: %@", error);
        return @{};
    }

    NSMutableDictionary *app = state[SYSTEMSTATE_KEY_APP];
    app[@"inForeground"]    = @(bsg_lastRunContext->isForeground);
    app[BSGKeyIsLaunching]  = @(bsg_lastRunContext->isLaunching);

    return state;
}

id blankIfNil(id value) {
    if(value == nil || [value isKindOfClass:[NSNull class]]) {
        return @"";
    }
    return value;
}

static NSMutableDictionary * initCurrentState(BugsnagConfiguration *config) {
    NSDictionary *systemInfo = [BSG_KSSystemInfo systemInfo];

    NSMutableDictionary *app = [NSMutableDictionary new];
    app[BSGKeyId] = blankIfNil(systemInfo[@BSG_KSSystemField_BundleID]);
    app[BSGKeyName] = blankIfNil(systemInfo[@BSG_KSSystemField_BundleName]);
    app[BSGKeyReleaseStage] = config.releaseStage;
    app[BSGKeyVersion] = blankIfNil(systemInfo[@BSG_KSSystemField_BundleShortVersion]);
    app[BSGKeyBundleVersion] = blankIfNil(systemInfo[@BSG_KSSystemField_BundleVersion]);
    app[BSGKeyMachoUUID] = systemInfo[@BSG_KSSystemField_AppUUID];
    app[@"binaryArch"] = systemInfo[@BSG_KSSystemField_BinaryArch];
#if TARGET_OS_TV
    app[BSGKeyType] = @"tvOS";
#elif TARGET_OS_IOS
    app[BSGKeyType] = @"iOS";
#elif TARGET_OS_OSX
    app[BSGKeyType] = @"macOS";
#endif

    NSMutableDictionary *device = [NSMutableDictionary new];
    device[SYSTEMSTATE_DEVICE_BOOT_TIME] = [BSG_RFC3339DateTool stringFromDate:systemInfo[@BSG_KSSystemField_BootTime]];
    device[@"id"] = systemInfo[@BSG_KSSystemField_DeviceAppHash];
    device[@"jailbroken"] = systemInfo[@BSG_KSSystemField_Jailbroken];
    device[@"osBuild"] = systemInfo[@BSG_KSSystemField_OSVersion];
    device[@"osVersion"] = systemInfo[@BSG_KSSystemField_SystemVersion];
    device[@"osName"] = systemInfo[@BSG_KSSystemField_SystemName];
    // Translated from 'iDeviceMaj,Min' into human-readable "iPhone X" description on the server
    device[@"model"] = systemInfo[@BSG_KSSystemField_Machine];
    device[@"modelNumber"] = systemInfo[@ BSG_KSSystemField_Model];
    device[@"wordSize"] = @(PLATFORM_WORD_SIZE);
    device[@"locale"] = [[NSLocale currentLocale] localeIdentifier];
    device[@"runtimeVersions"] = @{
        @"clangVersion": systemInfo[@BSG_KSSystemField_ClangVersion] ?: @"",
        @"osBuild": systemInfo[@BSG_KSSystemField_OSVersion] ?: @""
    };
#if TARGET_OS_SIMULATOR
    device[@"simulator"] = @YES;
#else
    device[@"simulator"] = @NO;
#endif
    device[@"totalMemory"] = systemInfo[@ BSG_KSSystemField_Memory][@ BSG_KSSystemField_Size];

    NSMutableDictionary *state = [NSMutableDictionary new];
    state[BSGKeyApp] = app;
    state[BSGKeyDevice] = device;

    return state;
}

static NSDictionary *copyDictionary(NSDictionary *launchState) {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    for (id key in launchState) {
        dictionary[key] = [launchState[key] copy];
    }
    return dictionary;
}

@interface BugsnagSystemState ()

@property(readwrite,atomic) NSDictionary *currentLaunchState;
@property(readwrite,nonatomic) NSDictionary *lastLaunchState;
@property(readonly,nonatomic) NSString *persistenceFilePath;

@end

@implementation BugsnagSystemState

- (instancetype)initWithConfiguration:(BugsnagConfiguration *)config {
    if ((self = [super init])) {
        _persistenceFilePath = [BSGFileLocations current].systemState;
        _lastLaunchState = loadPreviousState(_persistenceFilePath);
        _currentLaunchState = initCurrentState(config);
        _consecutiveLaunchCrashes = [_lastLaunchState[InternalKey][ConsecutiveLaunchCrashesKey] unsignedIntegerValue];
        [self sync];
    }
    return self;
}

- (void)setSession:(nullable BugsnagSession *)session {
    [self mutateLaunchState:^(NSMutableDictionary *state) {
        state[BSGKeySession] = session ? BSGSessionToEventJson((BugsnagSession *_Nonnull)session) : nil;
    }];
}

- (void)setCodeBundleID:(NSString*)codeBundleID {
    [self setValue:codeBundleID forAppKey:BSGKeyCodeBundleId];
}

- (void)setConsecutiveLaunchCrashes:(NSUInteger)consecutiveLaunchCrashes {
    [self setValue:@(_consecutiveLaunchCrashes = consecutiveLaunchCrashes) forKey:ConsecutiveLaunchCrashesKey inSection:InternalKey];
}

- (void)setValue:(id)value forAppKey:(NSString *)key {
    [self setValue:value forKey:key inSection:SYSTEMSTATE_KEY_APP];
}

- (void)setValue:(id)value forKey:(NSString *)key inSection:(NSString *)section {
    [self mutateLaunchState:^(NSMutableDictionary *state) {
        if (state[section]) {
            state[section][key] = value;
        } else {
            state[section] = [NSMutableDictionary dictionaryWithObjectsAndKeys:value, key, nil];
        }
    }];
}

- (void)mutateLaunchState:(nonnull void (^)(NSMutableDictionary *state))block {
    static _Atomic(BOOL) writePending;
    @synchronized (self) {
        NSMutableDictionary *mutableState = [NSMutableDictionary dictionary];
        for (NSString *section in self.currentLaunchState) {
            mutableState[section] = [self.currentLaunchState[section] mutableCopy];
        }
        block(mutableState);
        // User-facing state should never mutate from under them.
        self.currentLaunchState = copyDictionary(mutableState);
        
        BOOL expected = NO;
        if (!atomic_compare_exchange_strong(&writePending, &expected, YES)) {
            // _writePending was YES -- avoid an unnecesary dispatch_async()
            return;
        }
    }
    // Run on a BG thread so we don't monopolize the notification queue.
    dispatch_async(BSGGetFileSystemQueue(), ^(void){
        atomic_store(&writePending, NO);
        [self sync];
    });
}

- (void)sync {
    NSDictionary *state = self.currentLaunchState;
    NSAssert([BSGJSONSerialization isValidJSONObject:state], @"BugsnagSystemState cannot be converted to JSON data");
    NSError *error = nil;
    if (![BSGJSONSerialization writeJSONObject:state toFile:self.persistenceFilePath options:0 error:&error]) {
        bsg_log_err(@"System state cannot be written as JSON: %@", error);
    }
}

- (void)purge {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    if(![fm removeItemAtPath:self.persistenceFilePath error:&error]) {
        bsg_log_err(@"Could not remove persistence file: %@", error);
    }
    self.lastLaunchState = loadPreviousState(self.persistenceFilePath);
}

// MARK: -

- (BOOL)lastLaunchTerminatedUnexpectedly {
    // App extensions have a different lifecycle and the heuristic used for finding app terminations rooted in fixable code does not apply
    if ([BSG_KSSystemInfo isRunningInAppExtension]) {
        return NO;
    }
    
    if (!bsg_lastRunContext) {
        return NO;
    }
    
    NSDictionary *currentAppState = self.currentLaunchState[SYSTEMSTATE_KEY_APP];
    NSDictionary *previousAppState = self.lastLaunchState[SYSTEMSTATE_KEY_APP];
    NSDictionary *currentDeviceState = self.currentLaunchState[SYSTEMSTATE_KEY_DEVICE];
    NSDictionary *previousDeviceState = self.lastLaunchState[SYSTEMSTATE_KEY_DEVICE];
    
    if (bsg_lastRunContext->isTerminating) {
        return NO; // The app terminated normally
    }
    
    if (bsg_lastRunContext->isDebuggerAttached) {
        return NO; // The debugger may have killed the app
    }
    
    // If the app was in the background, we cannot determine whether the termination was unexpected
    if (!bsg_lastRunContext->isForeground) {
        return NO;
    }
    
    // Ignore unexpected terminations that may have been due to the app being upgraded
    NSString *currentAppVersion = currentAppState[SYSTEMSTATE_APP_VERSION];
    NSString *currentAppBundleVersion = currentAppState[SYSTEMSTATE_APP_BUNDLE_VERSION];
    if (!currentAppVersion || ![previousAppState[SYSTEMSTATE_APP_VERSION] isEqualToString:currentAppVersion] ||
        !currentAppBundleVersion || ![previousAppState[SYSTEMSTATE_APP_BUNDLE_VERSION] isEqualToString:currentAppBundleVersion]) {
        return NO;
    }
    
    id currentBootTime = currentDeviceState[SYSTEMSTATE_DEVICE_BOOT_TIME];
    id previousBootTime = previousDeviceState[SYSTEMSTATE_DEVICE_BOOT_TIME];
    BOOL didReboot = currentBootTime && previousBootTime && ![currentBootTime isEqual:previousBootTime];
    if (didReboot) {
        return NO; // The app may have been terminated due to the reboot
    }
    
    return YES;
}

@end
