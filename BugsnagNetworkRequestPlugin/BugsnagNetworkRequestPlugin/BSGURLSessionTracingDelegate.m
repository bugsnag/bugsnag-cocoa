//
//  BSGURLSessionTracingDelegate.m
//  
//
//  Created by Karl Stenerud on 07.09.21.
//

#import "BSGURLSessionTracingDelegate.h"
#import <Bugsnag/Bugsnag.h>


@implementation BSGURLSessionTracingDelegate

// All proxies should be talking to the same sink.
static id<BSGBreadcrumbSink> g_sink;

+ (BSGURLSessionTracingDelegate *_Nonnull)sharedDelegate {
    static dispatch_once_t onceToken;
    static BSGURLSessionTracingDelegate *delegate;
    dispatch_once(&onceToken, ^{
        delegate = [BSGURLSessionTracingDelegate new];
    });

    return delegate;
}

+ (void)setSink:(nullable id<BSGBreadcrumbSink>) sink {
    g_sink = sink;
}

- (BOOL)canTrace {
    return g_sink != nil;
}

static NSString *responseConclusions[10] = {
    @"NSURLSession error",
    @"NSURLSession succeeded",
    @"NSURLSession succeeded",
    @"NSURLSession succeeded",
    @"NSURLSession failed",
    @"NSURLSession error",
    @"NSURLSession error",
    @"NSURLSession error",
    @"NSURLSession error",
    @"NSURLSession error",
};

- (NSString *)conclusionForResponseCode:(NSInteger)responseCode {
    return responseConclusions[(responseCode / 100) % 10];
}

static NSDictionary *_Nonnull queryItemsAsDict(NSArray<NSURLQueryItem *> *_Nullable queryItems) {
    NSMutableDictionary *result = [NSMutableDictionary new];
    for(NSURLQueryItem *item in queryItems)
    {
        result[item.name] = item.value;
    }
    return result;
}

static NSString * stringOrEmpty(NSString *str) {
    return str ? str : @"";
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics
API_AVAILABLE(macosx(10.12), ios(10.0), watchos(3.0), tvos(10.0)) {
    if (g_sink != nil) {
        // Note: Cannot use metrics transaction request because it might have a 0 length HTTP body.
        NSURLRequest *req = task.originalRequest;
        NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:req.URL resolvingAgainstBaseURL:YES];
        // Note: Cannot use metrics transaction response because it will be nil if a custom NSURLProtocol is present.
        // Note: If there was an error, task.response will be nil, and the following values will be set accordingly.
        NSURLResponse *resp = task.response;
        NSHTTPURLResponse *httpResp = [resp isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)resp : nil;
        NSString *message = [self conclusionForResponseCode:httpResp.statusCode];
        int64_t requestContentLength = (int64_t)req.HTTPBody.length;
        int64_t responseContentLength = resp.expectedContentLength;

        if (@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)) {
            NSURLSessionTaskTransactionMetrics *transaction = [metrics.transactionMetrics lastObject];
            // Note: Must check for zero because these somtimes lie.
            if (transaction.countOfRequestBodyBytesSent != 0) {
                requestContentLength= transaction.countOfRequestBodyBytesSent;
            }
            if (transaction.countOfResponseBodyBytesReceived != 0) {
                responseContentLength = transaction.countOfResponseBodyBytesReceived;
            }
        }

        [g_sink leaveBreadcrumbWithMessage:message metadata:@{
            @"status": @(httpResp.statusCode),
            @"method": stringOrEmpty(req.HTTPMethod),
            @"url": stringOrEmpty(urlComponents.string),
            @"urlParams": queryItemsAsDict(urlComponents.queryItems),
            @"duration": @((unsigned)(metrics.taskInterval.duration * 1000)),
            @"requestContentLength": @(requestContentLength),
            @"responseContentLength": @(responseContentLength)
        } andType:BSGBreadcrumbTypeRequest];
    }
}

@end
