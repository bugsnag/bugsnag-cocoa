//
//  BugsnagDevice.h
//  Bugsnag
//
//  Created by Jamie Lynch on 01/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Bugsnag/BugsnagDefines.h>

/**
 * Stateless information set by the notifier about the device on which the event occurred can be
 * found on this class. These values can be accessed and amended if necessary.
 */
BUGSNAG_EXTERN
@interface BugsnagDevice : NSObject

/**
 * Whether the device has been jailbroken
 */
@property (nonatomic) BOOL jailbroken;

/**
 * A unique ID generated by Bugsnag which identifies the device
 */
@property (copy, nullable, nonatomic) NSString *id;

/**
 * The IETF language tag of the locale used
 */
@property (copy, nullable, nonatomic) NSString *locale;

/**
 * The manufacturer of the device used
 */
@property (copy, nullable, nonatomic) NSString *manufacturer;

/**
 * The model ID of the device used, e.g. "iPhone14,1" or "MacBookPro17,1"
 */
@property (copy, nullable, nonatomic) NSString *model;

/**
 * The model number of the device used, e.g. "N841AP"
 */
@property (copy, nullable, nonatomic) NSString *modelNumber;

/**
 * The name of the operating system running on the device used
 */
@property (copy, nullable, nonatomic) NSString *osName;

/**
 * The version of the operating system running on the device used
 */
@property (copy, nullable, nonatomic) NSString *osVersion;

/**
 * A collection of names and their versions of the primary languages, frameworks or
 * runtimes that the application is running on
 */
@property (copy, nullable, nonatomic) NSDictionary<NSString *, NSString *> *runtimeVersions;

/**
 * The total number of bytes of memory on the device
 */
@property (strong, nullable, nonatomic) NSNumber *totalMemory;

@end
