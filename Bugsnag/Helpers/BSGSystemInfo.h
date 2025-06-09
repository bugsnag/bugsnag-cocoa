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

#define BSG_SystemField_Translated "proc_translated"
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

@end

#if TARGET_OS_OSX
bool bsg_statfs(const char *path, uint64_t *free, uint64_t *total);
#endif
