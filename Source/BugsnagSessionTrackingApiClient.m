//
// Created by Jamie Lynch on 30/11/2017.
// Copyright (c) 2017 Bugsnag. All rights reserved.
//

#import "BugsnagSessionTrackingApiClient.h"
#import "BugsnagConfiguration.h"
#import "BugsnagSessionTrackingPayload.h"
#import "BugsnagLogger.h"
#import "Bugsnag.h"
#import "BugsnagKeys.h"
#import "BugsnagSession.h"

@interface SessionDeliveryOperation : NSOperation
@end

@implementation BugsnagSessionTrackingApiClient

- (NSOperation *)deliveryOperation {
    return [SessionDeliveryOperation new];
}

@end

@implementation SessionDeliveryOperation

- (void)main {
    @autoreleasepool {
        @try {
            // TODO deliver sessions!
        } @catch (NSException *e) {
            bsg_log_err(@"Could not send sessions: %@", e);
        }
    }
}

@end
