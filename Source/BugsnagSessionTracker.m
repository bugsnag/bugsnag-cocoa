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
        _sessionQueue = [NSMutableArray new];
    }
    return self;
}

- (void)startNewSession:(NSDate *)date
               withUser:(BugsnagUser *)user
           autoCaptured:(BOOL)autoCaptured {
    @synchronized(self) {
        _currentSession = [[BugsnagSession alloc] initWithId:[[NSUUID UUID] UUIDString]
                                                   startDate:date
                                                        user:user
                                                autoCaptured:autoCaptured];
        
        if (self.config.shouldAutoCaptureSessions || ! autoCaptured) {
            [self.sessionQueue addObject:self.currentSession];
        }
        _isInForeground = YES;
    }
}

- (void)suspendCurrentSession:(NSDate *)date {
    _isInForeground = NO;
}

- (void)incrementHandledError {
    @synchronized (self.currentSession) {
        self.currentSession.handledCount++;
    }
}

- (void)incrementUnhandledError {
    @synchronized (self.currentSession) {
        self.currentSession.unhandledCount++;
    }
}

@end
