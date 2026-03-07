//
//  BSGURLSessionTracingDelegate.m
//  
//
//  Created by Karl Stenerud on 07.09.21.
//

#import "BSGURLSessionTracingDelegate.h"
#import "BugsnagInstrumentedHTTPRequest.h"
#import "BugsnagInstrumentedHTTPResponse.h"

@implementation BSGURLSessionTracingDelegate

static BugsnagClient *g_client;
static BugsnagNetworkRequestFailuresConfiguration *g_config;
static BOOL g_breadcrumbsEnabled;

+ (BSGURLSessionTracingDelegate *_Nonnull)sharedDelegate {
    static dispatch_once_t onceToken;
    static BSGURLSessionTracingDelegate *delegate;
    dispatch_once(&onceToken, ^{
        delegate = [BSGURLSessionTracingDelegate new];
    });

    return delegate;
}

+ (void)setClient:(BugsnagClient *)client {
    g_client = client;
}

+ (void)setConfiguration:(nullable BugsnagNetworkRequestFailuresConfiguration *)config breadcrumbsEnabled:(BOOL)breadcrumbsEnabled {
    g_config = config;
    g_breadcrumbsEnabled = breadcrumbsEnabled;
}

- (BOOL)canTrace {
    return g_client != nil;
}

- (void)URLSession:(__unused NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics
API_AVAILABLE(macosx(10.12), ios(10.0), watchos(3.0), tvos(10.0)) {
    if (g_config == nil || metrics == nil) {
        return;
    }

    BugsnagErrorOptions *options = [[BugsnagErrorOptions alloc] init];
    options.capture.threads = NO;
    options.capture.stacktrace = NO;

    BugsnagInstrumentedHTTPRequest *instrumentedRequest = [BugsnagInstrumentedHTTPRequest initWithTransactionMetrics:metrics config:g_config];
    BugsnagInstrumentedHTTPResponse *instrumentedResponse = [BugsnagInstrumentedHTTPResponse initWithTransactionMetrics:metrics config:g_config];
    [instrumentedResponse setInstrumentedRequest:instrumentedRequest];

    // CALL ONRESPONSE CALLBACK
    NSArray<BugsnagHttpResponseCallback> *responseCallbacks = [g_config getResponseCallbacks];
    for (BugsnagHttpResponseCallback callback in responseCallbacks) {
        callback(instrumentedResponse);
    }

    NSUInteger uStatusCode = (NSUInteger) [instrumentedResponse getStatusCode];
    if ([g_config shouldCaptureHttpErrorCode:uStatusCode] == YES) {
        NSError *error = [NSError errorWithDomain:@"NetworkFailureError" code:1 userInfo:@{}];
        [g_client notifyError:error options:options block:^BOOL(BugsnagEvent * _Nonnull event) {
            event.request = [instrumentedRequest getBugsnagRequest];
            event.response = [instrumentedResponse getBugsnagResponse];
            // CALL OnERROR CALLBACK
            BugsnagOnErrorBlock onErrorBlock = [instrumentedResponse getErrorCallback];
            onErrorBlock(event);
            return NO;
        }];
    }

    if (g_breadcrumbsEnabled == YES && [instrumentedResponse isBreadcrumbReported] == YES) {
        [g_client leaveNetworkRequestBreadcrumbForTask:task metrics:metrics];
    }
}

@end
