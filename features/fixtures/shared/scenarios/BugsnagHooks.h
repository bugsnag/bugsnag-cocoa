//
//  BugsnagHooks.h
//  iOSTestApp
//
//  Created by Jamie Lynch on 21/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <Bugsnag/Bugsnag.h>

NS_ASSUME_NONNULL_BEGIN

@interface Bugsnag ()

+ (void)notifyInternal:(BugsnagEvent *)event block:(BOOL (^)(BugsnagEvent *))block;

@property (class, readonly, nonatomic) BugsnagClient *client;

@end

@interface BugsnagClient()

@property (nonatomic) BOOL autoNotify;

@end

NS_ASSUME_NONNULL_END
