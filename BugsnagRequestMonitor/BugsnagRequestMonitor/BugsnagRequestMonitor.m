//
//  BugsnagRequestMonitor.m
//  BugsnagRequestMonitor
//
//  Created by Karl Stenerud on 26.08.21.
//

// Replaces `NSURLSession.sessionWithConfiguration:delegate:delegateQueue:` and
// `NSURLSession.sharedSession` to inject a proxy delegate that responds to
// `URLSession:task:didFinishCollectingMetrics:` so that we can generate network
// breadcrumbs from all requests.

#import <Bugsnag/BugsnagPlugin.h>
#import "BugsnagRequestMonitor.h"
#import "BSGURLSessionTracingDelegate.h"
#import "NSURLSession+Tracing.h"

@implementation BugsnagRequestMonitor

+ (void)load {
    if (@available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)) {
        bsg_installNSURLSessionTracing();
    }
}

- (void)load:(BugsnagClient * _Nonnull)client {
    [BSGURLSessionTracingDelegate setSink:client];
}

- (void)unload {
    [BSGURLSessionTracingDelegate setSink:nil];
}

@end