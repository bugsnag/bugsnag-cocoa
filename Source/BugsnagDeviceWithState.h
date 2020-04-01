//
//  BugsnagDeviceWithState.h
//  Bugsnag
//
//  Created by Jamie Lynch on 01/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "BugsnagDevice.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Stateful information set by the notifier about the device on which the event occurred can be
 * found on this class. These values can be accessed and amended if necessary.
 */
@interface BugsnagDeviceWithState : BugsnagDevice

@end

NS_ASSUME_NONNULL_END
