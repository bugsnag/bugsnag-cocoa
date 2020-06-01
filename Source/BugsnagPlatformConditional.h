//
//  BugsnagPlatformConditional.h
//  Bugsnag
//
//  Created by Jamie Lynch on 01/06/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

// ***IMPORTANT NOTE***: this should always be imported as the first header in a file,
// because it relies on preprocessor macros. If this is not done the targets will
// not be defined appropriately and the functions/defines will behave unexpectedly.

#ifndef BugsnagPlatformConditional_h
#define BugsnagPlatformConditional_h

#import <Foundation/Foundation.h>

/**
 * Defined as true if this is the iOS platform.
 */
#define BSG_PLATFORM_IOS TARGET_OS_IOS

/**
* Defined as true if this is the OSX platform.
*/
#define BSG_PLATFORM_OSX TARGET_OS_OSX

/**
* Defined as true if this is the tvOS platform.
*/
#define BSG_PLATFORM_TVOS TARGET_OS_TV

#endif /* BugsnagPlatformConditional_h */
