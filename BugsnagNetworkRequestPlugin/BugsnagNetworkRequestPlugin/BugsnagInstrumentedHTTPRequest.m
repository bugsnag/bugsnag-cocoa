//
//  BugsnagInstrumentedHTTPRequest.m
//  BugsnagNetworkRequestPlugin
//
//  Created by Daria Bialobrzeska on 24/02/2026.
//
#import "BugsnagInstrumentedHTTPRequest.h"
#import <Bugsnag/BugsnagRequest.h>

@interface BugsnagInstrumentedHTTPRequest ()
@property (nonatomic, strong) NSURLRequest *originalRequest;
@property (nonatomic, strong) BugsnagRequest *request;
@end

@implementation BugsnagInstrumentedHTTPRequest

+ (instancetype)initWithTransactionMetrics:(NSURLSessionTaskMetrics *)metrics config:(BugsnagNetworkRequestFailuresConfiguration *)config API_AVAILABLE(macos(10.12)){
    NSURLRequest *request = nil;
    BOOL requestFound = NO;
    NSString *httpVersion = nil;

    NSUInteger idx = 0;
    while (requestFound != YES) {
        NSURLSessionTaskTransactionMetrics* transaction = [metrics.transactionMetrics objectAtIndex:idx];
        if (transaction.request != nil) {
            requestFound = YES;
            request = transaction.request;
            httpVersion = transaction.networkProtocolName;
            break;
        }
        idx = idx + 1;
        if (idx >= metrics.transactionMetrics.count - 1) {
            break;
        }
    }

    return [[BugsnagInstrumentedHTTPRequest alloc] init:request httpVersion:httpVersion config:config];
}

- (instancetype)init:(NSURLRequest *)request httpVersion:(NSString * _Nullable)httpVersion config:(BugsnagNetworkRequestFailuresConfiguration *)config {
    if ((self = [super init])) {
        _originalRequest = request;
         // @TODO - where to put max body capture value?
        _request = [BugsnagRequest initFromHttpRequest:request httpVersion:httpVersion maxBodyCapture:config.maxRequestBodyCapture];
    }
    return self;
}

- (NSURLRequest *)getRequest {
    return self.originalRequest;
}

- (NSString * _Nullable)getReportedUrl {
    return self.request.url;
}

- (void)setReportedUrl:(NSString * _Nullable )reportedUrl {
    if (reportedUrl == nil) {
        [self.request setNewUrl:nil];
    } else {
        [self.request setNewUrl:reportedUrl];
    }
}

- (NSString * _Nullable)getReportedRequestBody {
    return self.request.body;
}

- (void)setReportedRequestBody:(NSString * _Nullable)requestBody {
    if (requestBody == nil) {
        self.request.bodyLength = 0;
        self.request.body = nil;
    } else {
        self.request.bodyLength = requestBody.length;
        self.request.body = requestBody;
    }
}

@end
