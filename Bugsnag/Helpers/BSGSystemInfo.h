//
//  BSGSystemInfo.h
//  Bugsnag
//
//  Created by Karl Stenerud on 2012-02-05.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import <Bugsnag/BugsnagDefines.h>
#import <Foundation/Foundation.h>

#import "BSGDefines.h"

#define BSG_KSSystemField_AppUUID "app_uuid"
#define BSG_KSSystemField_BinaryArch "binary_arch"
#define BSG_KSSystemField_BundleID "CFBundleIdentifier"
#define BSG_KSSystemField_BundleName "CFBundleName"
#define BSG_KSSystemField_BundleExecutable "CFBundleExecutable"
#define BSG_KSSystemField_BundleShortVersion "CFBundleShortVersionString"
#define BSG_KSSystemField_BundleVersion "CFBundleVersion"
#define BSG_KSSystemField_CPUArch "cpu_arch"
#define BSG_KSSystemField_DeviceAppHash "device_app_hash"
#define BSG_KSSystemField_Disk "disk"
#define BSG_KSSystemField_Jailbroken "jailbroken"
#define BSG_KSSystemField_Machine "machine"
#define BSG_KSSystemField_Memory "memory"
#define BSG_KSSystemField_Model "model"
#define BSG_KSSystemField_OSVersion "os_version"
#define BSG_KSSystemField_Size "size"
#define BSG_KSSystemField_SystemName "system_name"
#define BSG_KSSystemField_SystemVersion "system_version"
#define BSG_KSSystemField_ClangVersion "clang_version"
#define BSG_KSSystemField_TimeZone "time_zone"
#define BSG_KSSystemField_Translated "proc_translated"
#define BSG_KSSystemField_iOSSupportVersion "iOSSupportVersion"
#define BSG_KSSystemField_ActiveTimeSinceLaunch "active_time_since_launch"
#define BSG_KSSystemField_AppInFG "application_in_foreground"
#define BSG_KSSystemField_BGTimeSinceLaunch "background_time_since_launch"
#define BSG_KSSystemField_AppStats "application_stats"
#define BSG_KSSystemField_Free "free"

/**
 * Provides system information useful for a crash report.
 */
@interface BSGSystemInfo : NSObject

/** Get the system info.
 *
 * @return The system info.
 */
+ (NSDictionary *)systemInfo;

/**
 * Whether the current main bundle is an iOS app extension
 */
+ (BOOL)isRunningInAppExtension;

/** Generate a 20 byte SHA1 hash that remains unique across a single device and
 * application. This is slightly different from the Apple crash report key,
 * which is unique to the device, regardless of the application.
 *
 * @return The stringified hex representation of the hash for this device + app.
 */
// Disabled so that it never gets used unintentionally.
//+ (NSString *)deviceAndAppHash;

@end
