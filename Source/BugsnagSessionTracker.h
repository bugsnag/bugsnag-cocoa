//
//  BugsnagSessionTracker.h
//  Bugsnag
//
//  Created by Jamie Lynch on 24/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BugsnagSessionTracker : NSObject

- (void)startNewSession;
- (void)suspendCurrentSession;

@end
