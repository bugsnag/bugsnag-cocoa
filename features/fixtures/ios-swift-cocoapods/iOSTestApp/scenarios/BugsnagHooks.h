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
+ (void)internalClientNotify:(NSException *_Nonnull)exception
                    withData:(NSDictionary *_Nullable)metadata
                       block:(BugsnagOnErrorBlock _Nullable)block;
@end
