//
//  BugsnagSessionTracker.h
//  Bugsnag
//
//  Created by Jamie Lynch on 24/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "BugsnagSession.h"
#import "BugsnagConfiguration.h"

@interface BugsnagSessionTracker : NSObject

- (instancetype)initWithConfig:(BugsnagConfiguration *)config;

- (void)startNewSession:(NSDate *)date
               withUser:(BugsnagUser *)user
           autoCaptured:(BOOL)autoCaptured;

- (void)suspendCurrentSession:(NSDate *)date;
- (void)incrementHandledError;
- (void)incrementUnhandledError;

@property (readonly) BugsnagSession *currentSession;
@property (readonly) BOOL isInForeground;
@property (readonly) NSMutableArray *sessionQueue;

@end
