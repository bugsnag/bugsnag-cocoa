//
//  BugsnagClient+AppHangs.m
//  Bugsnag
//
//  Created by Nick Dowell on 08/03/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "BugsnagClient+AppHangs.h"

#import "BSG_KSSystemInfo.h"
#import "BugsnagBreadcrumbs.h"
#import "BugsnagError+Private.h"
#import "BugsnagEvent+Private.h"
#import "BugsnagHandledState.h"
#import "BugsnagLogger.h"
#import "BugsnagSessionTracker.h"
#import "BugsnagThread+Private.h"

@implementation BugsnagClient (AppHangs)

- (void)appHangDetectedWithThreads:(nonnull NSArray<BugsnagThread *> *)threads {
    NSDictionary *systemInfo = [BSG_KSSystemInfo systemInfo];
    
    NSString *message = [NSString stringWithFormat:@"The app's main thread failed to respond to an event within %d milliseconds",
                         (int)self.configuration.appHangThresholdMillis];
    
    BugsnagError *error =
    [[BugsnagError alloc] initWithErrorClass:@"App Hang"
                                errorMessage:message
                                   errorType:BSGErrorTypeCocoa
                                  stacktrace:threads.firstObject.stacktrace];
    
    BugsnagHandledState *handledState =
    [[BugsnagHandledState alloc] initWithSeverityReason:AppHang
                                               severity:BSGSeverityError
                                              unhandled:NO
                                    unhandledOverridden:NO
                                              attrValue:nil];
    
    self.appHangEvent =
    [[BugsnagEvent alloc] initWithApp:[self generateAppWithState:systemInfo]
                               device:[self generateDeviceWithState:systemInfo]
                         handledState:handledState
                                 user:self.configuration.user
                             metadata:[self.metadata deepCopy]
                          breadcrumbs:self.breadcrumbs.breadcrumbs
                               errors:@[error]
                              threads:threads
                              session:self.sessionTracker.runningSession];
    
    // TODO: Persist BugsnagEvent to app_hang.json
}

- (void)appHangEnded {
    // TODO: Delete app_hang.json
    
    const BOOL fatalOnly = self.configuration.appHangThresholdMillis == BugsnagAppHangThresholdFatalOnly;
    if (!fatalOnly && self.appHangEvent) {
        [self notifyInternal:self.appHangEvent block:nil];
    }
    self.appHangEvent = nil;
}

@end
