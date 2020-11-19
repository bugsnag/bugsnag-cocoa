//
// Created by Jamie Lynch on 04/12/2017.
// Copyright (c) 2017 Bugsnag. All rights reserved.
//

#import "BugsnagApiClient.h"
#import "BugsnagConfiguration.h"
#import "Bugsnag.h"
#import "BugsnagKeys.h"
#import "BugsnagLogger.h"
#import "Private.h"
#import "BSGJSONSerialization.h"

typedef NS_ENUM(NSInteger, HTTPStatusCode) {
    /// 402 Payment Required: a nonstandard client error status response code that is reserved for future use.
    ///
    /// This status code is returned by ngrok when a tunnel has expired.
    HTTPStatusCodePaymentRequired = 402,
    
    /// 407 Proxy Authentication Required: the request has not been applied because it lacks valid authentication credentials
    /// for a proxy server that is between the browser and the server that can access the requested resource.
    HTTPStatusCodeProxyAuthenticationRequired = 407,
    
    /// 408 Request Timeout: the server would like to shut down this unused connection.
    HTTPStatusCodeClientTimeout = 408,
    
    /// 429 Too Many Requests: the user has sent too many requests in a given amount of time ("rate limiting").
    HTTPStatusCodeTooManyRequests = 429,
};

@interface BugsnagApiClient()
@property (nonatomic, strong) NSURLSession *session;
@end

@implementation BugsnagApiClient

- (instancetype)initWithConfig:(BugsnagConfiguration *)configuration
                     queueName:(NSString *)queueName {
    if (self = [super init]) {
        _sendQueue = [NSOperationQueue new];
        _sendQueue.maxConcurrentOperationCount = 1;
        _config = configuration;
        _session = configuration.session ?: [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];

        if ([_sendQueue respondsToSelector:@selector(qualityOfService)]) {
            _sendQueue.qualityOfService = NSQualityOfServiceUtility;
        }
        _sendQueue.name = queueName;
    }
    return self;
}

- (void)flushPendingData {
    [self.sendQueue cancelAllOperations];
    NSOperation *delay = [NSBlockOperation blockOperationWithBlock:^{ [NSThread sleepForTimeInterval:1]; }];
    NSOperation *deliver = [self deliveryOperation];
    [deliver addDependency:delay];
    [self.sendQueue addOperations:@[delay, deliver] waitUntilFinished:NO];
}

- (NSOperation *)deliveryOperation {
    bsg_log_err(@"Should override deliveryOperation in subclass");
    return [NSOperation new];
}

#pragma mark - Delivery

- (void)sendJSONPayload:(NSDictionary *)payload
                headers:(NSDictionary<NSString *, NSString *> *)headers
                  toURL:(NSURL *)url
      completionHandler:(void (^)(BugsnagApiClientDeliveryStatus status, NSError * _Nullable error))completionHandler {
    
    if (![BSGJSONSerialization isValidJSONObject:payload]) {
        bsg_log_err(@"Error: Invalid JSON payload passed to %s", __PRETTY_FUNCTION__);
        return completionHandler(BugsnagApiClientDeliveryStatusUndeliverable, nil);
    }
    
    NSError *error = nil;
    NSData *data = [BSGJSONSerialization dataWithJSONObject:payload options:0 error:&error];
    if (!data) {
        bsg_log_err(@"Error: Could not encode JSON payload passed to %s", __PRETTY_FUNCTION__);
        return completionHandler(BugsnagApiClientDeliveryStatusUndeliverable, error);
    }
    
    NSMutableURLRequest *request = [self prepareRequest:url headers:headers];
    
    [[self.session uploadTaskWithRequest:request fromData:data completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (![response isKindOfClass:[NSHTTPURLResponse class]]) {
            return completionHandler(BugsnagApiClientDeliveryStatusFailed, error ?:
                                     [NSError errorWithDomain:@"BugsnagApiClientErrorDomain" code:0 userInfo:@{
                                         NSLocalizedDescriptionKey: @"Request failed: no response was received",
                                         NSURLErrorFailingURLErrorKey: url }]);
        }
        
        NSInteger statusCode = ((NSHTTPURLResponse *)response).statusCode;
        
        if (statusCode / 100 == 2) {
            return completionHandler(BugsnagApiClientDeliveryStatusDelivered, nil);
        }
        
        error = [NSError errorWithDomain:@"BugsnagApiClientErrorDomain" code:1 userInfo:@{
            NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Request failed: unacceptable status code %ld (%@)",
                                        (long)statusCode, [NSHTTPURLResponse localizedStringForStatusCode:statusCode]],
            NSURLErrorFailingURLErrorKey: url }];
        
        if (statusCode / 100 == 4 &&
            statusCode != HTTPStatusCodePaymentRequired &&
            statusCode != HTTPStatusCodeProxyAuthenticationRequired &&
            statusCode != HTTPStatusCodeClientTimeout &&
            statusCode != HTTPStatusCodeTooManyRequests) {
            return completionHandler(BugsnagApiClientDeliveryStatusUndeliverable, error);
        }
        
        return completionHandler(BugsnagApiClientDeliveryStatusFailed, error);
    }] resume];
}

- (NSMutableURLRequest *)prepareRequest:(NSURL *)url
                                headers:(NSDictionary *)headers {
    NSMutableURLRequest *request = [NSMutableURLRequest
            requestWithURL:url
               cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
           timeoutInterval:15];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    for (NSString *key in [headers allKeys]) {
        [request setValue:headers[key] forHTTPHeaderField:key];
    }
    return request;
}

- (void)dealloc {
    [self.sendQueue cancelAllOperations];
}

@end
