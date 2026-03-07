//
//  BugsnagInstrumentedHTTPResponse.m
//  BugsnagNetworkRequestPlugin
//
//  Created by Daria Bialobrzeska on 27/02/2026.
//
#import "BugsnagInstrumentedHTTPResponse.h"
#import <Bugsnag/BugsnagResponse.h>

@interface BugsnagInstrumentedHTTPResponse ()
@property (nonatomic, strong) NSURLResponse *originalResponse;
@property (nonatomic, strong) BugsnagResponse *response;
@property (nonatomic) BOOL isBreadcrumbReported;
@property (nonatomic) BugsnagOnErrorBlock onErrorBlock;
@end

@implementation BugsnagInstrumentedHTTPResponse

+ (instancetype)initWithTransactionMetrics:(NSURLSessionTaskMetrics *)metrics config:(BugsnagNetworkRequestFailuresConfiguration *)config API_AVAILABLE(macos(10.12)){
    BOOL responseFound = NO;
    NSURLResponse *response = nil;

    NSUInteger idx = metrics.transactionMetrics.count - 1;
    while (responseFound != YES) {
        NSURLSessionTaskTransactionMetrics* transaction = [metrics.transactionMetrics objectAtIndex:idx];
        if (transaction.response != nil) {
            responseFound = YES;
            response = transaction.response;
            break;
        }
        if (idx == 0) {
            break;
        }
        idx = idx - 1;
    }

    return [[BugsnagInstrumentedHTTPResponse alloc] init:response config:config];
}

- (instancetype)init:(NSURLResponse *)response config:(BugsnagNetworkRequestFailuresConfiguration *)config {
    if ((self = [super init])) {
        _originalResponse = response;
        _response = [BugsnagResponse initFromHttpResponse:response maxBodyCapture:config.maxResponseBodyCapture];
        _isBreadcrumbReported = config.enableNetworkBreadcrumbs;
    }
    return self;
}

- (NSURLResponse * _Nullable)getResponse {
    return self.originalResponse;
}

- (NSInteger) getStatusCode {
    return self.response.statusCode;
}

- (void) setInstrumentedRequest:(BugsnagInstrumentedHTTPRequest * _Nonnull)request {
    self.relatedRequest = request;
}

- (NSString * _Nullable) getReportedResponseBody {
    return self.response.body;
}

- (void) setReportedResponseBody:(NSString * _Nullable)responseBody {
    if (responseBody == nil) {
        self.response.bodyLength = 0;
        self.response.body = nil;
    } else {
        self.response.bodyLength = responseBody.length;
        self.response.body = responseBody;
    }
}

- (void) setBreadcrumbReported:(BOOL)isBreadcrumbReported {
    self.isBreadcrumbReported = isBreadcrumbReported;
}

- (BOOL) isBreadcrumbReported {
    return self.isBreadcrumbReported;
}

- (void) setErrorCallback:(BugsnagOnErrorBlock _Nullable)onErrorCallback {
    self.onErrorBlock = onErrorCallback;
}

- (BugsnagOnErrorBlock _Nullable) getErrorCallback {
    return self.onErrorBlock;
}

- (BugsnagResponse * _Nonnull) getBugsnagResponse {
    return self.response;
}

@end
