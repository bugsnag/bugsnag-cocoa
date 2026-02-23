//
//  BugsnagNetworkRequestPlugin.m
//  BugsnagNetworkRequestPlugin
//
//  Created by Karl Stenerud on 26.08.21.
//

// Replaces `NSURLSession.sessionWithConfiguration:delegate:delegateQueue:` and
// `NSURLSession.sharedSession` to inject a proxy delegate that responds to
// `URLSession:task:didFinishCollectingMetrics:` so that we can generate network
// breadcrumbs from all requests.

#import "BugsnagNetworkRequestPlugin.h"

#import "BSGURLSessionTracingDelegate.h"
#import "NSURLSession+Tracing.h"

#import <Bugsnag/BugsnagClient.h>

@interface BugsnagNetworkRequestPlugin ()

@property (nonatomic) BOOL enableNetworkBreadcrumbs;
@property (nonatomic, nullable) BugsnagNetworkRequestFailuresConfiguration* configuration;

@end

@implementation BugsnagNetworkRequestPlugin

- (instancetype)init {
    if (!(self = [super init])) {
        return nil;
    }
    _enableNetworkBreadcrumbs = YES;
    _configuration = nil;

    return self;
}

- (instancetype)initWithConfiguration:(BugsnagNetworkRequestFailuresConfiguration *)configuration enableNetworkBreadcrumbs:(BOOL)enableNetworkBreadcrumbs {
    if (!(self = [super init])) {
        return nil;
    }
    _enableNetworkBreadcrumbs = enableNetworkBreadcrumbs;
    _configuration = configuration;

    return self;
}



+ (void)load {
    if (@available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)) {
        bsg_installNSURLSessionTracing();
    }
}

- (void)load:(BugsnagClient *)client {
    [BSGURLSessionTracingDelegate setClient:client];
    [BSGURLSessionTracingDelegate setConfiguration:self.configuration breadcrumbsEnabled:self.enableNetworkBreadcrumbs];
}

- (void)unload {
    [BSGURLSessionTracingDelegate setClient:nil];
    [BSGURLSessionTracingDelegate setConfiguration:nil breadcrumbsEnabled:NO];
}

@end
