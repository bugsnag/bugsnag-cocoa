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

#import "BugsnagPlatformConditional.h"

#import "BSG_KSSystemInfo.h"
#import "BSG_KSSystemInfoC.h"
#import "BSG_KSDynamicLinker.h"
#import "BSG_KSMachHeaders.h"
#import "BSG_KSJSONCodecObjC.h"
#import "BSG_KSMach.h"
#import "BSG_KSSysCtl.h"
#import "BugsnagKeys.h"
#import "BugsnagCollections.h"
#import "BSG_KSLogger.h"
#import "BSG_KSCrashReportFields.h"
#import "BSG_KSMach.h"
#import "BSG_KSCrash.h"

#import <CommonCrypto/CommonDigest.h>
#if BSG_PLATFORM_IOS || BSG_PLATFORM_TVOS
#import "BSGUIKit.h"
#endif
#import "BSG_Jailbreak.h"


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

@implementation BSG_KSSystemInfo

// ============================================================================
#pragma mark - Utility -
// ============================================================================

/** Get a sysctl value as an NSNumber.
 *
 * @param name The sysctl name.
 *
 * @return The result of the sysctl call.
 */
+ (NSNumber *)int32Sysctl:(NSString *)name {
    return @(bsg_kssysctl_int32ForName(
            [name cStringUsingEncoding:NSUTF8StringEncoding]));
}

/** Get a sysctl value as an NSNumber.
 *
 * @param name The sysctl name.
 *
 * @return The result of the sysctl call.
 */
+ (NSNumber *)int64Sysctl:(NSString *)name {
    return @(bsg_kssysctl_int64ForName([name
            cStringUsingEncoding:NSUTF8StringEncoding]));
}

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

/** Get a sysctl value as an NSDate.
 *
 * @param name The sysctl name.
 *
 * @return The result of the sysctl call.
 */
+ (NSDate *)dateSysctl:(NSString *)name {
    NSDate *result = nil;

    struct timeval value = bsg_kssysctl_timevalForName(
        [name cStringUsingEncoding:NSUTF8StringEncoding]);
    if (!(value.tv_sec == 0 && value.tv_usec == 0)) {
        result =
            [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)value.tv_sec];
    }

    return result;
}

/** Convert raw UUID bytes to a human-readable string.
 *
 * @param uuidBytes The UUID bytes (must be 16 bytes long).
 *
 * @return The human readable form of the UUID.
 */
+ (NSString *)uuidBytesToString:(const uint8_t *)uuidBytes {
    CFUUIDRef uuidRef =
        CFUUIDCreateFromUUIDBytes(NULL, *((CFUUIDBytes *)uuidBytes));
    NSString *str =
        (__bridge_transfer NSString *)CFUUIDCreateString(NULL, uuidRef);
    CFRelease(uuidRef);

    return str;
}

/** Get this application's executable path.
 *
 * @return Executable path.
 */
+ (NSString *)executablePath {
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSDictionary *infoDict = [mainBundle infoDictionary];
    NSString *bundlePath = [mainBundle bundlePath];
    NSString *executableName = infoDict[BSGKeyExecutableName];
    return [bundlePath stringByAppendingPathComponent:executableName];
}

/** Get this application's UUID.
 *
 * @return The UUID.
 */
+ (NSString *)appUUID {
    NSString *result = nil;

    NSString *exePath = [self executablePath];

    if (exePath != nil) {
        const uint8_t *uuidBytes =
            bsg_ksdlimageUUID([exePath UTF8String], true);
        if (uuidBytes == NULL) {
            // OSX app image path is a lie.
            uuidBytes = bsg_ksdlimageUUID(
                [exePath.lastPathComponent UTF8String], false);
        }
        if (uuidBytes != NULL) {
            result = [self uuidBytesToString:uuidBytes];
        }
    }

    return result;
}

+ (NSString *)deviceAndAppHash {
    NSMutableData *data = nil;

#if BSG_HAS_UIDEVICE
    if ([[UIDEVICE currentDevice]
            respondsToSelector:@selector(identifierForVendor)]) {
        data = [NSMutableData dataWithLength:16];
        [[UIDEVICE currentDevice].identifierForVendor
            getUUIDBytes:data.mutableBytes];
    } else
#endif
    {
        data = [NSMutableData dataWithLength:6];
        bsg_kssysctl_getMacAddress(BSGKeyDefaultMacName, [data mutableBytes]);
    }

    // Append some device-specific data.
    [data appendData:(NSData * _Nonnull)[[self stringSysctl:BSGKeyHwMachine]
                         dataUsingEncoding:NSUTF8StringEncoding]];
    [data appendData:(NSData * _Nonnull)[[self stringSysctl:BSGKeyHwModel]
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
        }
        break;
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
        [self CPUArchForCPUType:bsg_kssysctl_int32ForName(BSGKeyHwCputype)
                        subType:bsg_kssysctl_int32ForName(BSGKeyHwCpusubtype)];

    return result ?: [NSString stringWithUTF8String:bsg_ksmachcurrentCPUArch()];
}

/** Check if the current device is jailbroken.
 *
 * @return YES if the device is jailbroken.
 */
+ (BOOL)isJailbroken {
    return is_jailbroken();
}

/** Check if the current build is a debug build.
 *
 * @return YES if the app was built in debug mode.
 */
+ (BOOL)isDebugBuild {
#ifdef DEBUG
    return YES;
#else
    return NO;
#endif
}

/** Check if this code is built for the simulator.
 *
 * @return YES if this is a simulator build.
 */
+ (BOOL)isSimulatorBuild {
#if BSG_PLATFORM_SIMULATOR
    return YES;
#else
    return NO;
#endif
}

/** The file path for the bundle’s App Store receipt.
 *
 * @return App Store receipt for iOS 7+, nil otherwise.
 */
+ (NSString *)receiptUrlPath {
    return [NSBundle mainBundle].appStoreReceiptURL.path;
}

/** Check if the current build is a "testing" build.
 * This is useful for checking if the app was released through Testflight.
 *
 * @return YES if this is a testing build.
 */
+ (BOOL)isTestBuild {
    return [[self receiptUrlPath].lastPathComponent
        isEqualToString:@"sandboxReceipt"];
}

/** Check if the app has an app store receipt.
 * Only apps released through the app store will have a receipt.
 *
 * @return YES if there is an app store receipt.
 */
+ (BOOL)hasAppStoreReceipt {
    NSString *receiptPath = [self receiptUrlPath];
    if (receiptPath == nil) {
        return NO;
    }
    BOOL isAppStoreReceipt =
        [receiptPath.lastPathComponent isEqualToString:@"receipt"];
    BOOL receiptExists =
        [[NSFileManager defaultManager] fileExistsAtPath:receiptPath];

    return isAppStoreReceipt && receiptExists;
}

+ (NSString *)buildType {
    if ([BSG_KSSystemInfo isSimulatorBuild]) {
        return @"simulator";
    }
    if ([BSG_KSSystemInfo isDebugBuild]) {
        return @"debug";
    }
    if ([BSG_KSSystemInfo isTestBuild]) {
        return @"test";
    }
    if ([BSG_KSSystemInfo hasAppStoreReceipt]) {
        return @"app store";
    }
    return @"unknown";
}

// ============================================================================
#pragma mark - API -
// ============================================================================

+ (NSDictionary *)systemInfo {
    NSMutableDictionary *sysInfo = [NSMutableDictionary dictionary];

    NSBundle *mainBundle = [NSBundle mainBundle];
    NSDictionary *infoDict = [mainBundle infoDictionary];
    const struct mach_header *header = _dyld_get_image_header(0);
#ifdef __clang_version__
    sysInfo[@BSG_KSSystemField_ClangVersion] = @__clang_version__;
#endif
#if BSG_HAS_UIDEVICE
    sysInfo[@BSG_KSSystemField_SystemName] = [UIDEVICE currentDevice].systemName;
    sysInfo[@BSG_KSSystemField_SystemVersion] = [UIDEVICE currentDevice].systemVersion;
#else
    sysInfo[@BSG_KSSystemField_SystemName] = @"Mac OS";
    NSOperatingSystemVersion version =
        [NSProcessInfo processInfo].operatingSystemVersion;
    NSString *systemVersion;
    if (version.patchVersion == 0) {
        systemVersion =
            [NSString stringWithFormat:@"%ld.%ld", version.majorVersion,
                                       version.minorVersion];
    } else {
        systemVersion = [NSString
            stringWithFormat:@"%ld.%ld.%ld", version.majorVersion,
                             version.minorVersion, version.patchVersion];
    }
    sysInfo[@BSG_KSSystemField_SystemVersion] = systemVersion;
#endif
    if ([self isSimulatorBuild]) {
        NSString *model = [NSProcessInfo processInfo]
                              .environment[BSGKeySimulatorModelId];
        sysInfo[@BSG_KSSystemField_Machine] = model;
        sysInfo[@BSG_KSSystemField_Model] = @"simulator";
    } else {
#if BSG_PLATFORM_OSX
        // MacOS has the machine in the model field, and no model
        sysInfo[@BSG_KSSystemField_Machine] = [self stringSysctl:BSGKeyHwModel];
#else
        sysInfo[@BSG_KSSystemField_Machine] = [self stringSysctl:BSGKeyHwMachine];
        sysInfo[@BSG_KSSystemField_Model] = [self stringSysctl:BSGKeyHwModel];
#endif
    }
    sysInfo[@BSG_KSSystemField_KernelVersion] = [self stringSysctl:@"kern.version"];
    sysInfo[@BSG_KSSystemField_OSVersion] = [self osBuildVersion];
    sysInfo[@BSG_KSSystemField_Jailbroken] = @([self isJailbroken]);
    sysInfo[@BSG_KSSystemField_BootTime] = [self dateSysctl:@"kern.boottime"];
    sysInfo[@BSG_KSSystemField_AppStartTime] = [NSDate date];
    sysInfo[@BSG_KSSystemField_ExecutablePath] = [self executablePath];
    sysInfo[@BSG_KSSystemField_Executable] = infoDict[BSGKeyExecutableName];
    sysInfo[@BSG_KSSystemField_BundleID] = infoDict[@"CFBundleIdentifier"];
    sysInfo[@BSG_KSSystemField_BundleName] = infoDict[@"CFBundleName"];
    sysInfo[@BSG_KSSystemField_BundleExecutable] = infoDict[@"CFBundleExecutable"];
    sysInfo[@BSG_KSSystemField_BundleVersion] = infoDict[@"CFBundleVersion"];
    sysInfo[@BSG_KSSystemField_BundleShortVersion] = infoDict[@"CFBundleShortVersionString"];
    sysInfo[@BSG_KSSystemField_AppUUID] = [self appUUID];
    sysInfo[@BSG_KSSystemField_CPUArch] = [self currentCPUArch];
    sysInfo[@BSG_KSSystemField_CPUType] = [self int32Sysctl:@BSGKeyHwCputype];
    sysInfo[@BSG_KSSystemField_CPUSubType] = [self int32Sysctl:@BSGKeyHwCpusubtype];
    sysInfo[@BSG_KSSystemField_BinaryCPUType] = @(header->cputype);
    sysInfo[@BSG_KSSystemField_BinaryCPUSubType] = @(header->cpusubtype);
    sysInfo[@BSG_KSSystemField_TimeZone] = [[NSTimeZone localTimeZone] abbreviation];
    sysInfo[@BSG_KSSystemField_ProcessName] = [NSProcessInfo processInfo].processName;
    sysInfo[@BSG_KSSystemField_ProcessID] = @([NSProcessInfo processInfo].processIdentifier);
    sysInfo[@BSG_KSSystemField_ParentProcessID] = @(getppid());
    sysInfo[@BSG_KSSystemField_DeviceAppHash] = [self deviceAndAppHash];
    sysInfo[@BSG_KSSystemField_BuildType] = [BSG_KSSystemInfo buildType];

    NSDictionary *memory = @{
            @BSG_KSSystemField_Size: [self int64Sysctl:@"hw.memsize"],
            @BSG_KSCrashField_Usable: @(bsg_ksmachusableMemory())
    };
    sysInfo[@BSG_KSSystemField_Memory] = memory;

    NSDictionary *statsInfo = [[BSG_KSCrash sharedInstance] captureAppStats];
    sysInfo[@BSG_KSCrashField_AppStats] = statsInfo;
    return sysInfo;
}

+ (NSString *)osBuildVersion {
    return [self stringSysctl:@"kern.osversion"];
}

+ (BOOL)isRunningInAppExtension {
#if BSG_PLATFORM_IOS
    NSBundle *mainBundle = [NSBundle mainBundle];
    // From the App Extension Programming Guide:
    // > When you build an extension based on an Xcode template, you get an
    // > extension bundle that ends in .appex.
    return [[mainBundle executablePath] containsString:@".appex"]
        // In the case that the extension bundle was renamed or generated
        // outside of the Xcode template, check the Bundle OS Type Code:
        // > This key consists of a four-letter code for the bundle type. For
        // > apps, the code is APPL, for frameworks, it's FMWK, and for bundles,
        // > it's BNDL.
        // If the main bundle type is not "APPL", assume this is an extension
        // context.
        || ![[mainBundle infoDictionary][@"CFBundlePackageType"] isEqualToString:@"APPL"];
#else
    return NO;
#endif
}

#if BSG_PLATFORM_IOS || BSG_PLATFORM_TVOS
+ (UIApplicationState)currentAppState {
    // Only checked outside of app extensions since sharedApplication is
    // unavailable to extension UIKit APIs
    if ([self isRunningInAppExtension]) {
        return UIApplicationStateActive;
    }

    UIApplicationState(^getState)(void) = ^() {
        // Calling this API indirectly to avoid a compile-time check that
        // [UIApplication sharedApplication] is not called from app extensions
        // (which is handled above)
        UIApplication *app = [UIAPPLICATION performSelector:@selector(sharedApplication)];
        return [app applicationState];
    };

    if ([[NSThread currentThread] isMainThread]) {
        return getState();
    } else {
        // [UIApplication sharedApplication] is a main thread-only API
        __block UIApplicationState state;
        dispatch_sync(dispatch_get_main_queue(), ^{
            state = getState();
        });
        return state;
    }
}

+ (BOOL)isInForeground:(UIApplicationState)state {
    // The app is in the foreground if the current state is "active" or
    // "inactive". From the UIApplicationState docs:
    // > UIApplicationStateActive
    // >   The app is running in the foreground and currently receiving events.
    // > UIApplicationStateInactive
    // >   The app is running in the foreground but is not receiving events.
    // >   This might happen as a result of an interruption or because the app
    // >   is transitioning to or from the background.
    // > UIApplicationStateBackground
    // >   The app is running in the background.
    return state == UIApplicationStateInactive
        || state == UIApplicationStateActive;
}
#endif

@end

const char *bsg_kssysteminfo_toJSON(void) {
    NSError *error;
    NSMutableDictionary *systemInfo = [[BSG_KSSystemInfo systemInfo] mutableCopy];

    // Make sure the jailbroken status didn't get patched out.
    systemInfo[@BSG_KSSystemField_Jailbroken] = @(is_jailbroken());

    NSMutableData *jsonData =
        (NSMutableData *)[BSG_KSJSONCodec encode:systemInfo
                                         options:BSG_KSJSONEncodeOptionSorted
                                           error:&error];
    if (error != nil) {
        BSG_KSLOG_ERROR(@"Could not serialize system info: %@", error);
        return NULL;
    }
    if (![jsonData isKindOfClass:[NSMutableData class]]) {
        jsonData = [NSMutableData dataWithData:jsonData];
    }

    [jsonData appendBytes:"\0" length:1];
    return strdup([jsonData bytes]);
}

char *bsg_kssysteminfo_copyProcessName(void) {
    return strdup([[NSProcessInfo processInfo].processName UTF8String]);
}
