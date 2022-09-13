//
//  KSSystemInfo.m
//
//  Created by Karl Stenerud on 2012-02-05.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "BSG_KSSystemInfo.h"

#import "BSGDefines.h"
#import "BSGJSONSerialization.h"
#import "BSGKeys.h"
#import "BSGRunContext.h"
#import "BSGUIKit.h"
#import "BSGUtils.h"
#import "BSG_Jailbreak.h"
#import "BSG_KSCrashC.h"
#import "BSG_KSCrashReportFields.h"
#import "BSG_KSFileUtils.h"
#import "BSG_KSMach.h"
#import "BSG_KSMach.h"
#import "BSG_KSMachHeaders.h"
#import "BSG_KSSysCtl.h"
#import "BSG_KSSystemInfoC.h"
#import "BugsnagCollections.h"
#import "BugsnagInternals.h"
#import "BugsnagLogger.h"

#import <CommonCrypto/CommonDigest.h>
#import <mach-o/dyld.h>

static inline bool is_jailbroken() {
    static bool initialized_jb;
    static bool is_jb;
    if(!initialized_jb) {
        get_jailbreak_status(&is_jb);

        // Also keep using the old detection method.
        if(bsg_mach_headers_image_named("MobileSubstrate", false) != NULL) {
            is_jb = true;
        }
        initialized_jb = true;
    }

    return is_jb;
}

/**
 * Returns the content of /System/Library/CoreServices/SystemVersion.plist
 * bypassing the open syscall shim that would normally redirect access to this
 * file for iOS apps running on macOS.
 *
 * https://opensource.apple.com/source/xnu/xnu-7195.81.3/libsyscall/wrappers/system-version-compat.c.auto.html
 */
#if !TARGET_OS_SIMULATOR
static NSDictionary * bsg_systemversion() {
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

BSG_OBJC_DIRECT_MEMBERS
@implementation BSG_KSSystemInfo

// ============================================================================
#pragma mark - Utility -
// ============================================================================

/** Get a sysctl value as an NSString.
 *
 * @param name The sysctl name.
 *
 * @return The result of the sysctl call.
 */
+ (NSString *)stringSysctl:(NSString *)name {
    NSString *str = nil;
    size_t size = bsg_kssysctl_stringForName(
        [name cStringUsingEncoding:NSUTF8StringEncoding], NULL, 0);

    if (size <= 0) {
        return @"";
    }

    NSMutableData *value = [NSMutableData dataWithLength:size];

    if (bsg_kssysctl_stringForName(
            [name cStringUsingEncoding:NSUTF8StringEncoding],
            value.mutableBytes, size) != 0) {
        str = [NSString stringWithCString:value.mutableBytes
                                 encoding:NSUTF8StringEncoding];
    }

    return str;
}

/** Get this application's UUID.
 *
 * @return The UUID.
 */
+ (NSString *)appUUID {
    BSG_Mach_Header_Info *image = bsg_mach_headers_get_main_image();
    if (image && image->uuid) {
        return [[[NSUUID alloc] initWithUUIDBytes:image->uuid] UUIDString];
    }
    return nil;
}

+ (NSString *)deviceAndAppHash {
#if BSG_HAVE_UIDEVICE
    NSMutableData *data = [NSMutableData dataWithLength:16];
    [[UIDEVICE currentDevice].identifierForVendor getUUIDBytes:data.mutableBytes];
#else
    NSMutableData *data = [NSMutableData dataWithLength:6];
    bsg_kssysctl_getMacAddress(BSGKeyDefaultMacName, [data mutableBytes]);
#endif

    // Append some device-specific data.
    [data appendData:(NSData * _Nonnull)[[self stringSysctl:@"hw.machine"]
                         dataUsingEncoding:NSUTF8StringEncoding]];
    [data appendData:(NSData * _Nonnull)[[self stringSysctl:@"hw.model"]
                         dataUsingEncoding:NSUTF8StringEncoding]];
    [data appendData:(NSData * _Nonnull)[[self currentCPUArch]
                         dataUsingEncoding:NSUTF8StringEncoding]];

    // Append the bundle ID.
    NSData *bundleID = [[[NSBundle mainBundle] bundleIdentifier]
        dataUsingEncoding:NSUTF8StringEncoding];
    if (bundleID != nil) {
        [data appendData:bundleID];
    }

    // SHA the whole thing.
    uint8_t sha[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1([data bytes], (CC_LONG)[data length], sha);

    NSMutableString *hash = [NSMutableString string];
    for (size_t i = 0; i < sizeof(sha); i++) {
        [hash appendFormat:@"%02x", sha[i]];
    }

    return hash;
}

/** Get the current CPU's architecture.
 *
 * @return The current CPU archutecture.
 */
+ (NSString *)CPUArchForCPUType:(cpu_type_t)cpuType
                        subType:(cpu_subtype_t)subType {
    switch (cpuType) {
    case CPU_TYPE_ARM: {
        switch (subType) {
        case CPU_SUBTYPE_ARM_V6:
            return @"armv6";
        case CPU_SUBTYPE_ARM_V7:
            return @"armv7";
        case CPU_SUBTYPE_ARM_V7F:
            return @"armv7f";
        case CPU_SUBTYPE_ARM_V7K:
            return @"armv7k";
#ifdef CPU_SUBTYPE_ARM_V7S
        case CPU_SUBTYPE_ARM_V7S:
            return @"armv7s";
#endif
        case CPU_SUBTYPE_ARM_V8:
            return @"armv8";
        }
        break;
    }
    case CPU_TYPE_ARM64: {
        switch (subType) {
        case CPU_SUBTYPE_ARM64E:
            return @"arm64e";
        default:
            return @"arm64";
        }
    }
    case CPU_TYPE_ARM64_32: {
        // Ignore arm64_32_v8 subtype
        return @"arm64_32";
    }
    case CPU_TYPE_X86:
        return @"x86";
    case CPU_TYPE_X86_64:
        return @"x86_64";
    }

    return nil;
}

+ (NSString *)currentCPUArch {
    NSString *result =
        [self CPUArchForCPUType:bsg_kssysctl_int32ForName("hw.cputype")
                        subType:bsg_kssysctl_int32ForName("hw.cpusubtype")];

    return result ?: [NSString stringWithUTF8String:bsg_ksmachcurrentCPUArch()];
}

// ============================================================================
#pragma mark - API -
// ============================================================================

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

    NSBundle *mainBundle = [NSBundle mainBundle];
    NSDictionary *infoDict = [mainBundle infoDictionary];
    const struct mach_header *header = _dyld_get_image_header(0);
#ifdef __clang_version__
    sysInfo[@BSG_KSSystemField_ClangVersion] = @__clang_version__;
#endif

#if TARGET_OS_SIMULATOR
    //
    // When running on the simulator, we want to report the name and version of
    // the simlated OS.
    //

#if TARGET_OS_IOS
    // Note: This does not match UIDevice.currentDevice.systemName for versions
    // prior to (and some versions of) iOS 9 where the systemName was reported
    // as "iPhone OS". UIDevice gets its data from MobileGestalt which is a
    // private API. /System/Library/CoreServices/SystemVersion.plist contains
    // the information we need but will contain the macOS information when
    // running on the Simulator.
    sysInfo[@BSG_KSSystemField_SystemName] = @"iOS";
#elif TARGET_OS_TV
    sysInfo[@BSG_KSSystemField_SystemName] = @"tvOS";
#elif TARGET_OS_WATCH
    sysInfo[@BSG_KSSystemField_SystemName] = @"watchOS";
#endif // TARGET_OS_IOS

    NSDictionary *env = NSProcessInfo.processInfo.environment;
    sysInfo[@BSG_KSSystemField_SystemVersion] = env[@"SIMULATOR_RUNTIME_VERSION"];
    sysInfo[@BSG_KSSystemField_Machine] = env[@"SIMULATOR_MODEL_IDENTIFIER"];
    sysInfo[@BSG_KSSystemField_Model] = @"simulator";

#else // !TARGET_OS_SIMULATOR

    //
    // Report the name and version of the underlying OS the app is running on.
    // For Mac Catalyst and iOS apps running on macOS, this means macOS rather
    // than the version of iOS it emulates ("iOSSupportVersion")
    //
    NSDictionary *sysVersion = bsg_systemversion();

#if TARGET_OS_IOS || TARGET_OS_OSX
    NSString *systemName = sysVersion[@"ProductName"];
    if ([systemName isEqual:@"iPhone OS"]) {
        systemName = @"iOS";
    } else if
        // "ProductName" changed from "Mac OS X" to "macOS" in 11.0
        ([systemName isEqual:@"macOS"] || [systemName isEqual:@"Mac OS X"]) {
        // KSCrash had the name hard-coded this way when we forked it.
        systemName = @"Mac OS";
    }
#elif TARGET_OS_TV
    NSString *systemName = @"tvOS";
#elif TARGET_OS_WATCH
    NSString *systemName = @"watchOS";
#endif

    sysInfo[@BSG_KSSystemField_SystemName] = systemName;
    sysInfo[@BSG_KSSystemField_SystemVersion] = sysVersion[@"ProductVersion"];

#if TARGET_OS_IOS
    sysInfo[@BSG_KSSystemField_iOSSupportVersion] = sysVersion[@"iOSSupportVersion"];
#endif

    // Bugsnag payload mapping:
    //
    // BSG_KSSystemField_Machine => device.model
    // BSG_KSSystemField_Model   => device.modelNumber

    if ([systemName isEqual:@"Mac OS"]) {
        // On macOS hw.model contains the "Model Identifier" e.g. MacBookPro16,1
        sysInfo[@BSG_KSSystemField_Machine] = [self stringSysctl:@"hw.model"];
        // and hw.machine contains the instruction set - e.g. "arm64" or "x86_64"
        // we omit this since it doesn't match what we're expecting or want.
    } else {
        // On iOS & tvOS hw.machine contains the "Model Identifier" or
        // "ProductType" - e.g. "iPhone6,1"
        sysInfo[@BSG_KSSystemField_Machine] = [self stringSysctl:@"hw.machine"];
        // and hw.model contains the "Internal Name" or "Board ID" - e.g. "D79AP"
        sysInfo[@BSG_KSSystemField_Model] = [self stringSysctl:@"hw.model"];
    }

#endif // TARGET_OS_SIMULATOR

    sysInfo[@BSG_KSSystemField_OSVersion] = [self osBuildVersion];
    sysInfo[@BSG_KSSystemField_BundleID] = infoDict[@"CFBundleIdentifier"];
    sysInfo[@BSG_KSSystemField_BundleName] = infoDict[@"CFBundleName"];
    sysInfo[@BSG_KSSystemField_BundleExecutable] = infoDict[@"CFBundleExecutable"];
    sysInfo[@BSG_KSSystemField_BundleVersion] = infoDict[@"CFBundleVersion"];
    sysInfo[@BSG_KSSystemField_BundleShortVersion] = infoDict[@"CFBundleShortVersionString"];
    sysInfo[@BSG_KSSystemField_AppUUID] = [self appUUID];
    sysInfo[@BSG_KSSystemField_CPUArch] = [self currentCPUArch];
    sysInfo[@BSG_KSSystemField_BinaryArch] = [self CPUArchForCPUType:header->cputype subType:header->cpusubtype];
    sysInfo[@BSG_KSSystemField_DeviceAppHash] = [self deviceAndAppHash];

#if TARGET_OS_OSX || (defined(TARGET_OS_MACCATALYST) && TARGET_OS_MACCATALYST) || TARGET_OS_SIMULATOR
    // https://developer.apple.com/documentation/apple-silicon/about-the-rosetta-translation-environment
    int proc_translated = 0;
    size_t size = sizeof(proc_translated);
    if (!sysctlbyname("sysctl.proc_translated", &proc_translated, &size, NULL, 0) && proc_translated) {
        sysInfo[@BSG_KSSystemField_Translated] = @YES;
    }
#endif

    return sysInfo;
}

+ (NSDictionary *)systemInfo {
    NSMutableDictionary *sysInfo = [[self systemInfoStatic] mutableCopy];

    sysInfo[@BSG_KSSystemField_Jailbroken] = @(is_jailbroken());
    sysInfo[@BSG_KSSystemField_TimeZone] = [[NSTimeZone localTimeZone] abbreviation];
    sysInfo[@BSG_KSSystemField_Memory] = @{
        @BSG_KSCrashField_Free: @(bsg_runContext->hostMemoryFree),
        @BSG_KSCrashField_Size: @(NSProcessInfo.processInfo.physicalMemory)
    };

    NSString *dir = NSSearchPathForDirectoriesInDomains(
        NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    const char *path = dir.fileSystemRepresentation;
    if (path) {
        uint64_t dfree, size;
        if (bsg_ksfuStatfs(path, &dfree, &size)) {
            sysInfo[@BSG_KSSystemField_Disk] = @{
                @ BSG_KSCrashField_Free: @(dfree),
                @ BSG_KSCrashField_Size: @(size)
            };
        }
    }

    bsg_kscrashstate_updateDurationStats();
    BSG_KSCrash_State state = crashContext()->state;
    NSMutableDictionary *statsInfo = [NSMutableDictionary dictionary];
    statsInfo[@ BSG_KSCrashField_ActiveTimeSinceLaunch] = @(state.foregroundDurationSinceLaunch);
    statsInfo[@ BSG_KSCrashField_BGTimeSinceLaunch] = @(state.backgroundDurationSinceLaunch);
    statsInfo[@ BSG_KSCrashField_AppInFG] = @(state.applicationIsInForeground);
    sysInfo[@BSG_KSCrashField_AppStats] = statsInfo;
    return sysInfo;
}

+ (NSString *)osBuildVersion {
    return [self stringSysctl:@"kern.osversion"];
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

char *bsg_kssysteminfo_toJSON(void) {
    NSMutableDictionary *systemInfo = [[BSG_KSSystemInfo systemInfo] mutableCopy];

    // Make sure the jailbroken status didn't get patched out.
    systemInfo[@BSG_KSSystemField_Jailbroken] = @(is_jailbroken());

    NSData *data = BSGJSONDataFromDictionary(systemInfo, NULL);
    if (!data) {
        bsg_log_err(@"Could not serialize system info. "
                    "Crash reports will be missing vital data.");
    }
    return BSGCStringWithData(data);
}

char *bsg_kssysteminfo_copyProcessName(void) {
    return strdup([[NSProcessInfo processInfo].processName UTF8String]);
}

NSString * BSGGetDefaultDeviceId(void) {
    return [BSG_KSSystemInfo deviceAndAppHash];
}

NSDictionary * BSGGetSystemInfo(void) {
    return [BSG_KSSystemInfo systemInfo];
}
