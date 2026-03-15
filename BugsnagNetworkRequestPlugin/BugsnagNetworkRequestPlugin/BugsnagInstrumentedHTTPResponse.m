//
//  BugsnagInstrumentedHTTPResponse.m
//  BugsnagNetworkRequestPlugin
//
//  Created by Daria Bialobrzeska on 27/02/2026.
//
#import <Bugsnag/BugsnagConfiguration.h>
#import <BugsnagNetworkRequestPlugin/BugsnagInstrumentedHTTPResponse.h>
#import <BugsnagNetworkRequestPlugin/BugsnagNetworkRequestFailuresConfiguration.h>
#import <BugsnagNetworkRequestPlugin/BugsnagInstrumentedHTTPRequest.h>

@interface BugsnagInstrumentedHTTPResponse ()
@property (nonatomic, nullable, strong) NSURLResponse *originalResponse;
@property (nonatomic, nonnull, strong) BugsnagResponse *response;
@property (nonatomic) BOOL isBreadcrumbReported;
@property (nonatomic) BugsnagOnErrorBlock onErrorBlock;
@end

@implementation BugsnagInstrumentedHTTPResponse

+ (instancetype)init:(NSURLResponse * _Nullable)response
              config:(BugsnagNetworkRequestFailuresConfiguration *)config
              enableNetworkBreadcrumbs:(BOOL)enableNetworkBreadcrumbs
API_AVAILABLE(macos(10.12)) {
    BugsnagInstrumentedHTTPResponse *instrumentedResp = [BugsnagInstrumentedHTTPResponse new];
    instrumentedResp.originalResponse = response;
    instrumentedResp.response = [BugsnagResponse initFromHttpResponse:response];
    instrumentedResp.isBreadcrumbReported = enableNetworkBreadcrumbs;
    instrumentedResp.onErrorBlock = nil;
    return instrumentedResp;
}

- (NSURLResponse * _Nullable)getResponse {
    return _originalResponse;
}

- (NSInteger) getStatusCode {
    return _response.statusCode;
}

- (void) setInstrumentedRequest:(BugsnagInstrumentedHTTPRequest *)request {
    self.relatedRequest = request;
}

- (NSString * _Nullable) getReportedResponseBody {
    return _response.body;
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
    _isBreadcrumbReported = isBreadcrumbReported;
}

- (BOOL) isBreadcrumbReported {
    return _isBreadcrumbReported;
}

- (void) setErrorCallback:(BugsnagOnErrorBlock _Nullable)onErrorCallback {
    _onErrorBlock = onErrorCallback;
}

- (BugsnagOnErrorBlock _Nullable) getErrorCallback {
    return _onErrorBlock;
}

- (BugsnagResponse *) getBugsnagResponse {
    return _response;
}

@end
