//
//  BSGSystemInfo.m
//  Bugsnag
//
//  Created by Karl Stenerud on 2012-02-05.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "BSGSystemInfo.h"

#import "BSGDefines.h"
#import "BSGJSONSerialization.h"
#import "BSGKeys.h"
#import "BSGRunContext.h"
#import "BSGUIKit.h"
#import "BSGUtils.h"
#import "BSG_Jailbreak.h"
#import "BSG_KSMach.h"
#import "BSG_KSMach.h"
#import "BSG_KSMachHeaders.h"
#import "BugsnagCollections.h"
#import "BugsnagInternals.h"
#import "BugsnagLogger.h"
#import "KSSysCtl.h"
#import "KSCrashC.h"
#import "KSCrash.h"
#import "KSCrashReportFields.h"
#import "KSFileUtils.h"
#import "KSCrashMonitorContext.h"
#import "KSCrashMonitor_AppState.h"
#import "KSCrashMonitor_DiscSpace.h"

#import <CommonCrypto/CommonDigest.h>
#import <mach-o/dyld.h>

// TODO - OLD jailbroken definition left until Jailbroken task is done

//static inline bool is_jailbroken(void) {
//    static bool initialized_jb;
//    static bool is_jb;
//    if(!initialized_jb) {
//        get_jailbreak_status(&is_jb);
//
//        // Also keep using the old detection method.
//        if(bsg_mach_headers_image_named("MobileSubstrate", false) != NULL) {
//            is_jb = true;
//        }
//        initialized_jb = true;
//    }
//
//    return is_jb;
//}

// TODO DARIA should I move this to KSCrash?
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
#if BSG_HAVE_SYSCALL
    bsg_syscall_open(file, O_RDONLY, 0, &fd);
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

+ (NSDictionary *)buildSystemInfoStatic {
    NSMutableDictionary *sysInfo = [NSMutableDictionary dictionary];
    
    // TODO DARIA do I need to check if the result is not empty?
    // TODO DARIA replace magic strings with constants
    // Or use directly from MonitorContext struct
    NSDictionary *ksSysInfo = [[KSCrash sharedInstance] systemInfo];

    sysInfo[@BSG_KSSystemField_SystemName] = ksSysInfo[@"systemName"];
    sysInfo[@BSG_KSSystemField_SystemVersion] = ksSysInfo[@"systemVersion"];
    sysInfo[@BSG_KSSystemField_Machine] = ksSysInfo[@"machine"];
    sysInfo[@BSG_KSSystemField_Model] = ksSysInfo[@"model"];
    sysInfo[@BSG_KSSystemField_OSVersion] = ksSysInfo[@"osVersion"];
    sysInfo[@BSG_KSSystemField_BundleID] = ksSysInfo[@"bundleID"];
    sysInfo[@BSG_KSSystemField_BundleName] = ksSysInfo[@"bundleName"];
    sysInfo[@BSG_KSSystemField_BundleExecutable] = ksSysInfo[@"executableName"];
    sysInfo[@BSG_KSSystemField_BundleVersion] = ksSysInfo[@"bundleVersion"];
    sysInfo[@BSG_KSSystemField_BundleShortVersion] = ksSysInfo[@"bundleShortVersion"];
    sysInfo[@BSG_KSSystemField_AppUUID] = ksSysInfo[@"appID"];
    sysInfo[@BSG_KSSystemField_CPUArch] = ksSysInfo[@"cpuArchitecture"];
    
    // TODO DARIA what's the difference between CPUArch and BinaryArch??
    //sysInfo[@BSG_KSSystemField_BinaryArch] = [self CPUArchForCPUType:header->cputype subType:header->cpusubtype];
    
    // TODO DARIA missing field iOSSupportVersion
    
    sysInfo[@BSG_KSSystemField_DeviceAppHash] = ksSysInfo[@"deviceAppHash"];
    sysInfo[@BSG_KSSystemField_Translated] = ksSysInfo[@"procTranslated"];
    
#ifdef __clang_version__
    sysInfo[@BSG_KSSystemField_ClangVersion] = @__clang_version__;
#endif

    return sysInfo;
}

+ (NSDictionary *)systemInfo {
    NSMutableDictionary *sysInfo = [[self systemInfoStatic] mutableCopy];

    NSDictionary *ksSysInfo = [[KSCrash sharedInstance] systemInfo];
    sysInfo[@BSG_KSSystemField_Jailbroken] = ksSysInfo[@"isJailbroken"];

    sysInfo[@BSG_KSSystemField_TimeZone] = [[NSTimeZone localTimeZone] abbreviation];
    sysInfo[@BSG_KSSystemField_Memory] = @{
        @BSG_KSSystemField_Free: @(bsg_getHostMemory()),
        @BSG_KSSystemField_Size: @(NSProcessInfo.processInfo.physicalMemory)
    };
    
    // Grey area APIs, may not be filled on KSCrash side
    // TODO DARIA how to check if empty!!
    KSCrash_MonitorContext fakeEvent = { 0 };
    kscm_discspace_getAPI()->addContextualInfoToEvent(&fakeEvent);
    sysInfo[@BSG_KSSystemField_Disk] = @{
        @BSG_KSSystemField_Free: @(fakeEvent.System.freeStorageSize),
        @BSG_KSSystemField_Size: @(fakeEvent.System.storageSize)
    };
    
    // TODO DARIA is this properly copied?
    kscm_appstate_getAPI()->addContextualInfoToEvent(&fakeEvent);
    NSMutableDictionary *statsInfo = [NSMutableDictionary dictionary];
    statsInfo[@BSG_KSSystemField_ActiveTimeSinceLaunch] = @(fakeEvent.AppState.activeDurationSinceLaunch);
    statsInfo[@BSG_KSSystemField_BGTimeSinceLaunch] = @(fakeEvent.AppState.backgroundDurationSinceLaunch);
    statsInfo[@BSG_KSSystemField_AppInFG] = @(fakeEvent.AppState.applicationIsInForeground);
    
    sysInfo[@BSG_KSSystemField_AppStats] = statsInfo;
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
    // TODO DARIA maybe better to get from Monitor to get references, not copied strings
    NSDictionary *ksSysInfo = [[KSCrash sharedInstance] systemInfo];
    systemInfo[@BSG_KSSystemField_Jailbroken] = ksSysInfo[@"isJailbroken"];

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
    // TODO DARIA fix warning
    return sysInfo[@BSG_KSSystemField_DeviceAppHash];
}

NSDictionary * BSGGetSystemInfo(void) {
    return [BSGSystemInfo systemInfo];
}
