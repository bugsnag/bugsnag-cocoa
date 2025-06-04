//
//  BSGSystemInfo.m
//  Bugsnag
//
//  Created by Karl Stenerud on 2012-02-05.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "BSGSystemInfo.h"

#import "BSGJSONSerialization.h"
#import "BSGRunContext.h"
#import "BSGUIKit.h"
#import "BSGUtils.h"
#import "BugsnagLogger.h"
#import "KSCrashReportFields.h"
#import "KSCrashMonitorContext.h"
#import "KSCrashMonitor_System.h"
#import "KSCrashMonitor_AppState.h"
#import "KSCrashMonitor_DiscSpace.h"
#import "KSJailbreak.h"
#import "KSSystemCapabilities.h"

// TODO: Check if KSCrash reported version is correct after CI tests run
// I think they have it covered (check after tests)
/**
 * Returns the content of /System/Library/CoreServices/SystemVersion.plist
 * bypassing the open syscall shim that would normally redirect access to this
 * file for iOS apps running on macOS.
 *
 * https://opensource.apple.com/source/xnu/xnu-7195.81.3/libsyscall/wrappers/system-version-compat.c.auto.html
 */
#if !TARGET_OS_SIMULATOR
static NSDictionary * bsg_systemversion(void) {
    int fd = -1;
    char buffer[1024] = {0};
    const char *file = "/System/Library/CoreServices/SystemVersion.plist";
#if KSCRASH_HAS_SYSCALL
    ksj_syscall_open(file, O_RDONLY, 0, &fd);
#else
    fd = open(file, O_RDONLY);
#endif
    if (fd < 0) {
        bsg_log_err(@"Could not open SystemVersion.plist");
        return nil;
    }
    ssize_t length = read(fd, buffer, sizeof(buffer));
    close(fd);
    if (length < 0 || length == sizeof(buffer)) {
        bsg_log_err(@"Could not read SystemVersion.plist");
        return nil;
    }
    NSData *data = [NSData
                    dataWithBytesNoCopy:buffer
                    length:(NSUInteger)length freeWhenDone:NO];
    if (!data) {
        bsg_log_err(@"Could not read SystemVersion.plist");
        return nil;
    }
    NSError *error = nil;
    NSDictionary *systemVersion = [NSPropertyListSerialization
                                   propertyListWithData:data
                                   options:0 format:NULL error:&error];
    if (!systemVersion) {
        bsg_log_err(@"Could not read SystemVersion.plist: %@", error);
    }
    return systemVersion;
}
#endif

@implementation BSGSystemInfo

#pragma mark - API -

/**
 * Returns a systemInfo dictionary containing all the nonvolatile unchanging values.
 */
+ (NSDictionary *)systemInfoStatic {
    static NSDictionary *sysInfo;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sysInfo = [self buildSystemInfoStatic];
    });
    return sysInfo;
}

#define COPY_STRING(A) \
fakeEvent.System.A ? [NSString stringWithUTF8String:fakeEvent.System.A] : nil

+ (NSDictionary *)buildSystemInfoStatic {
    NSMutableDictionary *sysInfo = [NSMutableDictionary dictionary];
    
    KSCrash_MonitorContext fakeEvent = { 0 };
    kscm_system_getAPI()->addContextualInfoToEvent(&fakeEvent);

    sysInfo[KSCrashField_SystemName] = COPY_STRING(systemName);
    sysInfo[KSCrashField_SystemVersion] = COPY_STRING(systemVersion);
    sysInfo[KSCrashField_Machine] = COPY_STRING(machine);
    sysInfo[KSCrashField_Model] = COPY_STRING(model);
    sysInfo[KSCrashField_OSVersion] = COPY_STRING(osVersion);
    sysInfo[KSCrashField_BundleID] = COPY_STRING(bundleID);
    sysInfo[KSCrashField_BundleName] = COPY_STRING(bundleName);
    sysInfo[KSCrashField_Executable] = COPY_STRING(executableName);
    sysInfo[KSCrashField_BundleVersion] = COPY_STRING(bundleVersion);
    sysInfo[KSCrashField_BundleShortVersion] = COPY_STRING(bundleShortVersion);
    sysInfo[KSCrashField_AppUUID] = COPY_STRING(appID);
    sysInfo[KSCrashField_CPUArch] = COPY_STRING(cpuArchitecture);
    sysInfo[@BSG_SystemField_BinaryArch] = COPY_STRING(binaryArchitecture);
    sysInfo[KSCrashField_DeviceAppHash] = COPY_STRING(deviceAppHash);
    sysInfo[@BSG_SystemField_Translated] = @(fakeEvent.System.procTranslated);
    
#if !TARGET_OS_SIMULATOR
    //
    // Report the name and version of the underlying OS the app is running on.
    // For Mac Catalyst and iOS apps running on macOS, this means macOS rather
    // than the version of iOS it emulates ("iOSSupportVersion")
    //
    NSDictionary *sysVersion = bsg_systemversion();
#if TARGET_OS_IOS
    sysInfo[@BSG_SystemField_iOSSupportVersion] = sysVersion[@"iOSSupportVersion"];
#endif
#endif

#ifdef __clang_version__
    sysInfo[@BSG_SystemField_ClangVersion] = @__clang_version__;
#endif

    return sysInfo;
}

+ (NSDictionary *)systemInfo {
    NSMutableDictionary *sysInfo = [[self systemInfoStatic] mutableCopy];

    KSCrash_MonitorContext fakeEvent = { 0 };
    kscm_system_getAPI()->addContextualInfoToEvent(&fakeEvent);
    sysInfo[KSCrashField_Jailbroken] = @(fakeEvent.System.isJailbroken);

    sysInfo[KSCrashField_TimeZone] = [[NSTimeZone localTimeZone] abbreviation];
    sysInfo[KSCrashField_Memory] = @{
        KSCrashField_Free: @(bsg_getHostMemory()),
        KSCrashField_Size: @(NSProcessInfo.processInfo.physicalMemory)
    };
    
    // Grey area APIs, may not be filled on KSCrash side
    kscm_discspace_getAPI()->addContextualInfoToEvent(&fakeEvent);
    sysInfo[@BSG_SystemField_Disk] = @{
        KSCrashField_Free: @(fakeEvent.System.freeStorageSize),
        KSCrashField_Size: @(fakeEvent.System.storageSize)
    };
    
    kscm_appstate_getAPI()->addContextualInfoToEvent(&fakeEvent);
    NSMutableDictionary *statsInfo = [NSMutableDictionary dictionary];
    statsInfo[KSCrashField_ActiveTimeSinceLaunch] = @(fakeEvent.AppState.activeDurationSinceLaunch);
    statsInfo[KSCrashField_BGTimeSinceLaunch] = @(fakeEvent.AppState.backgroundDurationSinceLaunch);
    statsInfo[KSCrashField_AppInFG] = @(fakeEvent.AppState.applicationIsInForeground);
    sysInfo[KSCrashField_AppStats] = statsInfo;

    return sysInfo;
}

+ (BOOL)isRunningInAppExtension {
    // From "Information Property List Key Reference" > "App Extension Keys"
    // https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/AppExtensionKeys.html
    //
    // NSExtensionPointIdentifier
    // String - iOS, macOS. Specifies the extension point that supports an app extension, in reverse-DNS notation.
    // This key is required for every app extension, and must be placed as an immediate child of the NSExtension key.
    // Each Xcode app extension template is preconfigured with the appropriate extension point identifier key.
    return NSBundle.mainBundle.infoDictionary[@"NSExtension"][@"NSExtensionPointIdentifier"] != nil;
}

@end

char *bsg_systeminfo_toJSON(void) {
    NSMutableDictionary *systemInfo = [[BSGSystemInfo systemInfo] mutableCopy];

    // Make sure the jailbroken status didn't get patched out.
    KSCrash_MonitorContext fakeEvent = { 0 };
    kscm_system_getAPI()->addContextualInfoToEvent(&fakeEvent);
    systemInfo[KSCrashField_Jailbroken] = @(fakeEvent.System.isJailbroken);

    NSData *data = BSGJSONDataFromDictionary(systemInfo, NULL);
    if (!data) {
        bsg_log_err(@"Could not serialize system info. "
                    "Crash reports will be missing vital data.");
    }
    return BSGCStringWithData(data);
}

char *bsg_systeminfo_copyProcessName(void) {
    return strdup([[NSProcessInfo processInfo].processName UTF8String]);
}

NSString * BSGGetDefaultDeviceId(void) {
    NSDictionary *sysInfo = [BSGSystemInfo systemInfo];
    NSString *appHash = sysInfo[KSCrashField_DeviceAppHash];
    return appHash;
}

NSDictionary * BSGGetSystemInfo(void) {
    return [BSGSystemInfo systemInfo];
}
