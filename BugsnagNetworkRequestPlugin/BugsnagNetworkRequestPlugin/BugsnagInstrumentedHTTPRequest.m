//
//  BugsnagInstrumentedHTTPRequest.m
//  BugsnagNetworkRequestPlugin
//
//  Created by Daria Bialobrzeska on 24/02/2026.
//
#import <BugsnagNetworkRequestPlugin/BugsnagInstrumentedHTTPRequest.h>
#import <BugsnagNetworkRequestPlugin/BugsnagNetworkRequestFailuresConfiguration.h>

@interface BugsnagInstrumentedHTTPRequest ()
@property (nonatomic, strong) NSURLRequest *originalRequest;
@property (nonatomic, strong) BugsnagHttpRequest *request;
@end

@implementation BugsnagInstrumentedHTTPRequest

+ (instancetype)init:(NSURLRequest * _Nullable)request
         httpVersion:(NSString * _Nullable)httpVersion
              config:(BugsnagNetworkRequestFailuresConfiguration *)config
API_AVAILABLE(macos(10.12)){
    BugsnagInstrumentedHTTPRequest *instrumentedRequest = [BugsnagInstrumentedHTTPRequest new];
    instrumentedRequest.originalRequest = request;
    instrumentedRequest.request = [BugsnagHttpRequest initWithHttpRequest:request httpVersion:httpVersion maxBodyCapture:config.maxRequestBodyCapture];
    return instrumentedRequest;
}

- (NSURLRequest * _Nullable)getRequest {
    return _originalRequest;
}

- (NSString * _Nullable)getReportedUrl {
    return _request.url;
}

- (void)setReportedUrl:(NSString * _Nullable )reportedUrl {
    if (reportedUrl == nil) {
        [self.request setNewUrl:nil];
    } else {
        [self.request setNewUrl:reportedUrl];
    }
}

- (NSString * _Nullable)getReportedRequestBody {
    return _request.body;
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

- (BugsnagHttpRequest *) getBugsnagRequest {
    return _request;
}

@end
