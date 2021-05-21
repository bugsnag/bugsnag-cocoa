//
//  BugsnagHooks.h
//  iOSTestApp
//
//  Created by Jamie Lynch on 21/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Bugsnag/Bugsnag.h>

@interface Bugsnag ()
+ (void)notifyInternal:(BugsnagEvent *_Nonnull)event
                 block:(BugsnagOnErrorBlock _Nonnull)block;

@property (class, readonly) BugsnagClient *client;
@end

@interface BugsnagClient()
@property (nonatomic) BOOL autoNotify;
@end
