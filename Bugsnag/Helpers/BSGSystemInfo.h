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

#define BSG_SystemField_BinaryArch "binary_arch"
#define BSG_SystemField_Translated "proc_translated"
#define BSG_SystemField_ClangVersion "clang_version"
#define BSG_SystemField_iOSSupportVersion "iOSSupportVersion"
#define BSG_SystemField_Disk "disk"

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
