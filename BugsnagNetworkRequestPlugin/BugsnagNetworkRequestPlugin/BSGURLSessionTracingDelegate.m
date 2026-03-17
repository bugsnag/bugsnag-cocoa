//
//  BSGURLSessionTracingDelegate.m
//  
//
//  Created by Karl Stenerud on 07.09.21.
//

#import <Bugsnag/BugsnagError.h>
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
    g_breadcrumbsEnabled = YES;
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
        if (g_breadcrumbsEnabled == YES) {
            [g_client leaveNetworkRequestBreadcrumbForTask:task metrics:metrics];
        }
        return;
    }

    BugsnagErrorOptions *options = [[BugsnagErrorOptions alloc] init];
    options.capture.threads = NO;
    options.capture.stacktrace = NO;

    NSString *httpVersion = nil;
    for (NSURLSessionTaskTransactionMetrics* transaction in metrics.transactionMetrics) {
        if (transaction.networkProtocolName == nil) {
            continue;
        }
        httpVersion = transaction.networkProtocolName;
        break;
    }

    BugsnagInstrumentedHTTPRequest *instrumentedRequest = [BugsnagInstrumentedHTTPRequest init:task.originalRequest
                                                                                   httpVersion:httpVersion
                                                                                        config:g_config];
    BugsnagInstrumentedHTTPResponse *instrumentedResponse = [BugsnagInstrumentedHTTPResponse init:task.response
                                                                         enableNetworkBreadcrumbs:g_breadcrumbsEnabled];
    [instrumentedResponse setInstrumentedRequest:instrumentedRequest];

    // CALL ONRESPONSE CALLBACK
    NSArray<BugsnagHttpResponseCallback> *responseCallbacks = [g_config getResponseCallbacks];
    for (BugsnagHttpResponseCallback callback in responseCallbacks) {
        callback(instrumentedResponse);
    }

    if (g_breadcrumbsEnabled == YES && [instrumentedResponse isBreadcrumbReported] == YES) {
        [g_client leaveNetworkRequestBreadcrumbForTask:task metrics:metrics];
    }

    NSUInteger uStatusCode = (NSUInteger) [instrumentedResponse getStatusCode];
    if ([g_config shouldCaptureHttpErrorCode:uStatusCode] == YES) {
        NSError *error = [NSError errorWithDomain:@"NetworkFailureError" code:1 userInfo:@{}];
        [g_client notifyError:error options:options block:^BOOL(BugsnagEvent * _Nonnull event) {
            event.request = [instrumentedRequest getBugsnagRequest];
            event.response = [instrumentedResponse getBugsnagResponse];

            // clear all other errors
            BugsnagError *networkError = [BugsnagError new];
            networkError.errorClass = @"HTTPError";
            networkError.errorMessage = [NSString stringWithFormat:@"%ld: %@", (long)event.response.statusCode, event.request.url];
            networkError.type = BSGErrorTypeCocoa;
            networkError.stacktrace = @[];
            event.errors = @[networkError];

            // CALL ONERROR CALLBACK
            BugsnagOnErrorBlock onErrorBlock = [instrumentedResponse getErrorCallback];
            if (onErrorBlock != nil) {
                return onErrorBlock(event);
            }
            return YES;
        }];
    }
}

@end
