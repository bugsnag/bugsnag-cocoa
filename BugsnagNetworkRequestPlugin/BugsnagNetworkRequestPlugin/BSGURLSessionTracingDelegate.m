//
//  BSGURLSessionTracingDelegate.m
//  
//
//  Created by Karl Stenerud on 07.09.21.
//

#import "BSGURLSessionTracingDelegate.h"

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
    if (g_breadcrumbsEnabled == YES) {
        [g_client leaveNetworkRequestBreadcrumbForTask:task metrics:metrics];
    }

    if (g_config == nil || metrics == nil) {
        return;
    }

    BugsnagErrorOptions *options = [[BugsnagErrorOptions alloc] init];
    options.capture.threads = NO;
    options.capture.stacktrace = NO;

    for (NSURLSessionTaskTransactionMetrics* transaction in metrics.transactionMetrics) {
        if (transaction.response != nil) {
            NSHTTPURLResponse *response = (NSHTTPURLResponse *)transaction.response;
            if ([g_config shouldCaptureHttpErrorCode:@(response.statusCode)]) {
                NSError *error = [NSError errorWithDomain:@"NetworkFailureError" code:1 userInfo:@{}];
                [g_client notifyError:error options:options block:^BOOL(BugsnagEvent * _Nonnull _) {
                    //event.request = processRequest(transaction.request);
                    //event.response = processResponse(transaction.response);
                    return NO;
                }];
            }
        }
    }

}

@end
