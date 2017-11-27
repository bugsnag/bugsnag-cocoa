//
//  BugsnagSessionTracker.m
//  Bugsnag
//
//  Created by Jamie Lynch on 24/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import "BugsnagSessionTracker.h"

@interface BugsnagSessionTracker()
@property BugsnagConfiguration *config;
@end

@implementation BugsnagSessionTracker

- (instancetype)initWithConfig:(BugsnagConfiguration *)config {
    if (self = [super init]) {
        self.config = config;
    }
    return self;
}


- (void)startNewSession:(NSDate *)date
               withUser:(BugsnagUser *)user
           autoCaptured:(BOOL)autoCaptured {
    NSLog(@"");
    // TODO implement
}

- (void)suspendCurrentSession:(NSDate *)date {
    NSLog(@"");
    // TODO implement
}

- (void)incrementHandledError {
    // TODO implement
}

- (void)incrementUnhandledError {
    // TODO implement
}

@end
