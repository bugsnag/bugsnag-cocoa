//
//  BugsnagSessionTracker.m
//  Bugsnag
//
//  Created by Jamie Lynch on 24/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import "BugsnagSessionTracker.h"
#import "BugsnagSessionFileStore.h"
#import "BSG_KSLogger.h"

@interface BugsnagSessionTracker ()
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

    @synchronized (self) {
        _currentSession = [[BugsnagSession alloc] initWithId:[[NSUUID UUID] UUIDString]
                                                   startDate:date
                                                        user:user
                                                autoCaptured:autoCaptured];

        if (self.config.shouldAutoCaptureSessions || !autoCaptured) {
            [self.sessionQueue addObject:self.currentSession];
        }
        _isInForeground = YES;
    }


    // TODO file store testing!


    NSString *bundleName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    NSString *storePath = [BugsnagFileStore findReportStorePath:@"Sessions"
                                                     bundleName:bundleName];

    if (!storePath) {
        BSG_KSLOG_ERROR(
                @"Failed to initialize session store.");
    } else {
        BugsnagSessionFileStore *sessionStore = [BugsnagSessionFileStore storeWithPath:storePath];
        
        
        // serialise session
        NSString *filepath = [sessionStore pathToFileWithId:self.currentSession.sessionId];
        NSDictionary *dict = [self.currentSession toJson];

        NSError *error;
        NSData *json = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];

        if (error != nil || ![json writeToFile:filepath atomically:YES]) {
            BSG_KSLOG_ERROR(@"Failed to write session %@", error);
            return;
        }
        
        
        // deserialise session

        NSArray *storedSessions = [sessionStore allFiles];
        storedSessions.count;

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
