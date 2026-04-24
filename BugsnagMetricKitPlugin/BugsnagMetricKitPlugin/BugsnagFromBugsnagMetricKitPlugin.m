//
//  BugsnagFromBugsnagMetricKitPlugin.m
//  BugsnagMetricKitPlugin
//
//  Created by Robert Bartoszewski on 27/03/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import "BugsnagFromBugsnagMetricKitPlugin.h"

// Bridged API methods won't have implementations until we connect them at runtime.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation BugsnagFromBugsnagMetricKitPlugin

static NSString *BSGUserInfoKeyIsSafeToCall = @"isSafeToCall";
static NSString *BSGUserInfoKeyWillNOOP = @"willNOOP";

static id bugsnagCrossTalkAPI = nil;

+ (void)initialize {
    // Look for a cross-talk API
    Class cls = NSClassFromString(@"BugsnagCrossTalkAPI");
    if (cls != nil) {
        NSError *err = nil;
        
        // Map the methods we want to use, with the API versions we expect
        if ((err = [cls mapAPINamed:@"symbolicateStackframesV1:"
                         toSelector:@selector(symbolicateStackframes:)]) != nil) {
            NSLog(@"Failed to map Bugsnag API symbolicateStackframesV1:: %@", err);
            NSNumber *isSafeToCall = err.userInfo[BSGUserInfoKeyIsSafeToCall];
            if (![isSafeToCall boolValue]) {
                // Must abort because this method is not mapped, so we'd crash if we tried to call it.
                return;
            }
        }
        
        if ((err = [cls mapAPINamed:@"notifyPlainEventV1:errorMessage:stacktrace:timestamp:block:"
                         toSelector:@selector(notifyPlainEvent:errorMessage:stacktrace:timestamp:block:)]) != nil) {
            NSLog(@"Failed to map Bugsnag API notifyPlainEventV1:errorMessage:stacktrace:timestamp:block:: %@", err);
            NSNumber *isSafeToCall = err.userInfo[BSGUserInfoKeyIsSafeToCall];
            if (![isSafeToCall boolValue]) {
                // Must abort because this method is not mapped, so we'd crash if we tried to call it.
                return;
            }
        }

        // Our "sharedInstance" will actually be the cross-talk API whose class we loaded.
        bugsnagCrossTalkAPI = [cls sharedInstance];
    }
}

+ (instancetype _Nullable)sharedInstance {
    // We're either going to return the API object we found in +initialize, or nil.
    return bugsnagCrossTalkAPI;
}

/**
 * Map a named API to a method with the specified selector.
 * If an error occurs, the user info dictionary of the error will contain a field "isSafeToCall".
 * If "isSafeToCall" is "YES", then the selector has been mapped to a null implementation (does nothing, returns nil).
 * If "isSafeToCall" is "NO", then no mapping has occurred, and the method doesn't exist (calling it will result in no such selector).
 */
+ (NSError *)mapAPINamed:(NSString * _Nonnull __unused)apiName toSelector:(SEL __unused)toSelector {
    // This exists only to make the mapAPINamed selector available on our side
    // so that we can call it on the API class we found (see +initialize).
    // This implementation is never actually called.
    return nil;
}

@end
#pragma clang diagnostic pop
