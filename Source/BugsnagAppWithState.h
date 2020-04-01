//
//  BugsnagAppWithState.h
//  Bugsnag
//
//  Created by Jamie Lynch on 01/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "BugsnagApp.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Stateful information set by the notifier about your app can be found on this class. These values
 * can be accessed and amended if necessary.
 */
@interface BugsnagAppWithState : BugsnagApp

@end

NS_ASSUME_NONNULL_END
