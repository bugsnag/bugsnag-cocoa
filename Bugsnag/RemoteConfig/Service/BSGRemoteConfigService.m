//
//  BSGRemoteConfigService.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 11/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import <stdlib.h>
#import "BugsnagConfiguration+Private.h"
#import "BSGRemoteConfigService.h"
#import "BugsnagApiClient.h"
#import "BSG_RFC3339DateTool.h"
#import "BSGJSONSerialization.h"

static NSString *VersionQueryParam = @"version";
static NSString *BundleVersionQueryParam = @"bundleVersion";
static NSString *OSVersionQueryParam = @"osVersion";
static NSString *ReleaseStageQueryParam = @"releaseStage";
static NSString *BinaryArchQueryParam = @"binaryArch";
static NSString *AppIdQueryParam = @"appId";
static NSString *PayloadVersionParam = @"payloadVersion";

static NSString *ContentTypeHeader = @"Content-Type";
static NSString *IfNoneMatchHeader = @"If-None-Match";
static NSString *ETagHeader = @"ETag";
static NSString *CacheControlHeader = @"Cache-Control";
static NSString *CacheControlMaxAgePrefix = @"max-age=";
static NSString *RetryAfterHeader = @"Retry-After";
// Identifies the device in the config service's logs.
static NSString *DeviceIdHeader = @"Bugsnag-Device-Id";

static const NSInteger HTTPStatusCodeNotModified = 304;
static const NSInteger HTTPStatusCodeOK = 200;

static const NSTimeInterval RequestTimeoutInterval = 30;

// Each cached config's lifetime is shortened by a random fraction up to this value, so devices that fetched
// together do not all expire, and refresh, at the same moment.
static const double ExpiryJitterFraction = 0.1;

static NSString *CurrentPayloadVersion = @"1";

static NSString *_Nullable BSGHeaderValue(NSDictionary<id, id> *headers, NSString *name) {
    for (id key in headers) {
        if ([key isKindOfClass:[NSString class]] &&
            [((NSString *)key) caseInsensitiveCompare:name] == NSOrderedSame) {
            id value = headers[key];
            return [value isKindOfClass:[NSString class]] ? value : nil;
        }
    }
    return nil;
}

// The device has no usable connection, so the request never reached the config service.
static BOOL BSGIsNetworkUnavailableError(NSError *error) {
    if (![error.domain isEqualToString:NSURLErrorDomain]) {
        return NO;
    }
    switch (error.code) {
        case NSURLErrorNotConnectedToInternet:
        case NSURLErrorInternationalRoamingOff:
        case NSURLErrorDataNotAllowed:
            return YES;
        default:
            return NO;
    }
}

@implementation BSGRemoteConfigServiceResponse

+ (instancetype)responseWithConfig:(BSGRemoteConfiguration *)config {
    return [[self alloc] initWithType:BSGRemoteConfigServiceResponseTypeSuccess
                               config:config
                                error:nil
                     configurationTag:config.configurationTag
                           expiryDate:config.expiryDate];
}

+ (instancetype)responseWithError:(NSError *)error {
    return [[self alloc] initWithType:BSGRemoteConfigServiceResponseTypeError
                               config:nil
                                error:error
                     configurationTag:nil
                           expiryDate:nil];
}

+ (instancetype)responseWithNewExpiryDate:(NSDate *)expiryDate configurationTag:(NSString *)configurationTag {
    return [[self alloc] initWithType:BSGRemoteConfigServiceResponseTypeNotModified
                               config:nil
                                error:nil
                     configurationTag:configurationTag
                           expiryDate:expiryDate];
}

- (instancetype)initWithType:(BSGRemoteConfigServiceResponseType)type
                      config:(BSGRemoteConfiguration *)config
                       error:(NSError *)error
            configurationTag:(NSString *)configurationTag
                  expiryDate:(NSDate *)expiryDate {
    self = [super init];
    if (self) {
        _type = type;
        _configuration = config;
        _error = error;
        _configurationTag = configurationTag;
        _expiryDate = expiryDate;
    }
    return self;
}

@end

@interface BSGRemoteConfigService ()

@property (nonatomic, strong) BugsnagConfiguration *configuration;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) BugsnagNotifier *notifier;
@property (nonatomic, strong) BugsnagDevice *device;
@property (nonatomic, strong) BugsnagApp *app;

@end

@implementation BSGRemoteConfigService

+ (instancetype)serviceWithSession:(NSURLSession *)session
                     configuration:(BugsnagConfiguration *)configuration
                          notifier:(BugsnagNotifier *)notifier
                            device:(BugsnagDevice *)device
                               app:(BugsnagApp *)app {
    return [[self alloc] initWithSession:session
                           configuration:configuration
                                notifier:notifier
                                  device:device
                                     app:app];
}

- (instancetype)initWithSession:(NSURLSession *)session
                  configuration:(BugsnagConfiguration *)configuration
                       notifier:(BugsnagNotifier *)notifier
                         device:(BugsnagDevice *)device
                            app:(BugsnagApp *)app {
    self = [super init];
    if (self) {
        _session = session;
        _configuration = configuration;
        _notifier = notifier;
        _device = device;
        _app = app;
    }
    return self;
}

- (void)loadRemoteConfigWithCurrentTag:(nullable NSString *)tag completion:(BSGRemoteConfigServiceCompletion)completion {
    NSURL *configUrl = self.configuration.configurationURL;
    if (!configUrl) {
        completion([BSGRemoteConfigServiceResponse responseWithError:[self noUrlError]]);
        return;
    }
    NSURLRequest *request = [self requestWithUrl:configUrl currentTag:tag];
    if (!request) {
        completion([BSGRemoteConfigServiceResponse responseWithError:[self requestBuildingError]]);
        return;
    }
    [self downloadRemoteConfigWithRequest:request
                               completion:completion];
}

#pragma mark - Helpers

- (void)downloadRemoteConfigWithRequest:(NSURLRequest *)request
                             completion:(BSGRemoteConfigServiceCompletion)completion {
    __weak typeof(self) weakSelf = self;
    [[self.session dataTaskWithRequest:request
                     completionHandler:^(NSData * _Nullable data,
                                         NSURLResponse * _Nullable response,
                                         NSError * _Nullable error) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {
            completion([BSGRemoteConfigServiceResponse responseWithError:error]);
            return;
        }
        if (error && ![response isKindOfClass:[NSHTTPURLResponse class]]) {
            BSGRemoteConfigServiceResponse *errorResponse = [BSGRemoteConfigServiceResponse responseWithError:error];
            errorResponse.networkUnavailable = BSGIsNetworkUnavailableError(error);
            completion(errorResponse);
            return;
        }

        NSString *etag = nil;
        NSDate *expiryDate = nil;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            etag = BSGHeaderValue(httpResponse.allHeaderFields, ETagHeader);
            if (!etag) {
                etag = request.allHTTPHeaderFields[IfNoneMatchHeader];
            }
            NSString *cacheControl = BSGHeaderValue(httpResponse.allHeaderFields, CacheControlHeader);
            
            expiryDate = [strongSelf expiryDateFromCacheControl:cacheControl];
            if (httpResponse.statusCode == HTTPStatusCodeNotModified) {
                completion([BSGRemoteConfigServiceResponse responseWithNewExpiryDate:expiryDate
                                                                    configurationTag:etag]);
                return;
            }
            if (httpResponse.statusCode != HTTPStatusCodeOK) {
                BSGRemoteConfigServiceResponse *errorResponse = [BSGRemoteConfigServiceResponse responseWithError:
                                                                 [strongSelf unexpectedResponseErrorWithStatusCode:httpResponse.statusCode]];
                errorResponse.retryAfter = [strongSelf parseRetryAfter:BSGHeaderValue(httpResponse.allHeaderFields, RetryAfterHeader)];
                completion(errorResponse);
                return;
            }
            if ([data length] == 0) {
                BSGRemoteConfiguration *emptyConfig = [BSGRemoteConfiguration configFromJson:@{}
                                                                                        eTag:etag
                                                                                  expiryDate:expiryDate];
                completion([BSGRemoteConfigServiceResponse responseWithConfig:emptyConfig]);
                return;
            }
        }
        
        NSData *content = data ?: [NSData data];
        NSError *jsonError = nil;
        NSDictionary *configJson = BSGJSONDictionaryFromData(content, 0, &jsonError);
        if (!configJson) {
            completion([BSGRemoteConfigServiceResponse responseWithError:jsonError]);
            return;
        }
        
        BSGRemoteConfiguration *remoteConfig;
        if (etag != nil || expiryDate != nil) {
            remoteConfig = [BSGRemoteConfiguration configFromJson:configJson
                                                             eTag:etag
                                                       expiryDate:expiryDate];
        } else {
            remoteConfig = [BSGRemoteConfiguration configFromJson:configJson];
        }
        
        if (remoteConfig) {
            completion([BSGRemoteConfigServiceResponse responseWithConfig:remoteConfig]);
        } else {
            completion([BSGRemoteConfigServiceResponse responseWithError:[strongSelf configNotValidError]]);
        }
    }] resume];
}

- (NSError *)noUrlError {
    return [NSError errorWithDomain:@"BSGRemoteConfigServiceDomain" code:0 userInfo:@{}];
}

- (NSError *)requestBuildingError {
    return [NSError errorWithDomain:@"BSGRemoteConfigServiceDomain" code:1 userInfo:@{}];
}

- (NSError *)configNotValidError {
    return [NSError errorWithDomain:@"BSGRemoteConfigServiceDomain" code:2 userInfo:@{}];
}

- (NSError *)unexpectedResponseErrorWithStatusCode:(NSInteger)statusCode {
    return [NSError errorWithDomain:@"BSGRemoteConfigServiceDomain"
                               code:statusCode
                           userInfo:@{NSLocalizedDescriptionKey: @"Unexpected Remote Config response"}];
}

+ (NSTimeInterval)jitteredLifetime:(NSTimeInterval)lifetime randomFraction:(double)randomFraction {
    double fraction = MIN(1.0, MAX(0.0, randomFraction));
    return lifetime * (1.0 - ExpiryJitterFraction * fraction);
}

- (NSDate *)expiryDateFromCacheControl:(NSString *)cacheControl {
    NSTimeInterval lifetime = [self parseMaxAgeFromCacheControl:cacheControl];
    if (lifetime <= 0) {
        lifetime = self.configuration.remoteConfigUpdateInterval +
                   self.configuration.remoteConfigUpdateTolerance;
    }
    double randomFraction = (double)arc4random() / (double)UINT32_MAX;
    return [NSDate dateWithTimeIntervalSinceNow:[[self class] jitteredLifetime:lifetime randomFraction:randomFraction]];
}

- (NSTimeInterval)parseMaxAgeFromCacheControl:(NSString *)cacheControl {
    if (!cacheControl || cacheControl.length == 0) {
        return 0;
    }
    NSArray *directives = [cacheControl componentsSeparatedByString:@","];
    
    for (NSString *directive in directives) {
        NSString *trimmedDirective = [directive stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        if ([trimmedDirective hasPrefix:CacheControlMaxAgePrefix]) {
            NSString *maxAgeValue = [trimmedDirective substringFromIndex:[CacheControlMaxAgePrefix length]];
            NSTimeInterval maxAge = [maxAgeValue doubleValue];
            return maxAge > 0 ? maxAge : 0;
        }
    }
    
    return 0;
}

// Only the delay-seconds form is supported; an HTTP-date value is ignored.
- (NSTimeInterval)parseRetryAfter:(NSString *)retryAfter {
    NSString *trimmed = [retryAfter stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (trimmed.length == 0) {
        return 0;
    }
    NSScanner *scanner = [NSScanner scannerWithString:trimmed];
    NSInteger seconds = 0;
    if (![scanner scanInteger:&seconds] || !scanner.isAtEnd || seconds <= 0) {
        return 0;
    }
    return (NSTimeInterval)seconds;
}

- (NSURLRequest *)requestWithUrl:(NSURL *)url currentTag:(nullable NSString *)tag {
    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    headers[ContentTypeHeader] = @"application/json";
    if (tag) {
        headers[IfNoneMatchHeader] = tag;
    }
    headers[BugsnagHTTPHeaderNameApiKey] = self.configuration.apiKey;
    headers[BugsnagHTTPHeaderNameNotifierName] = self.notifier.name;
    headers[BugsnagHTTPHeaderNameNotifierVersion] = self.notifier.version;
    if (self.device.id.length > 0) {
        headers[DeviceIdHeader] = self.device.id;
    }
    
    NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    NSURLQueryItem *versionQueryItem = [NSURLQueryItem queryItemWithName:VersionQueryParam
                                                                   value:self.app.version];
    NSURLQueryItem *bundleVersionQueryItem = [NSURLQueryItem queryItemWithName:BundleVersionQueryParam
                                                                         value:self.app.bundleVersion];
    NSURLQueryItem *osVersionQueryItem = [NSURLQueryItem queryItemWithName:OSVersionQueryParam
                                                                     value:self.device.osVersion];
    NSURLQueryItem *releaseStageQueryItem = [NSURLQueryItem queryItemWithName:ReleaseStageQueryParam
                                                                        value:self.app.releaseStage];
    NSURLQueryItem *binaryArchQueryItem = [NSURLQueryItem queryItemWithName:BinaryArchQueryParam
                                                                      value:self.app.binaryArch];
    NSURLQueryItem *appIdQueryItem = [NSURLQueryItem queryItemWithName:AppIdQueryParam
                                                                 value:self.app.id];
    NSURLQueryItem *payloadVersionQueryItem = [NSURLQueryItem queryItemWithName:PayloadVersionParam
                                                                          value:CurrentPayloadVersion];
    
    
    urlComponents.queryItems = @[versionQueryItem,
                                 bundleVersionQueryItem,
                                 osVersionQueryItem,
                                 releaseStageQueryItem,
                                 binaryArchQueryItem,
                                 appIdQueryItem,
                                 payloadVersionQueryItem];
    NSURL *finalUrl = urlComponents.URL;
    
    if (!finalUrl) {
        return nil;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:finalUrl];
    request.allHTTPHeaderFields = headers;
    request.HTTPMethod = @"GET";
    request.cachePolicy = NSURLRequestReloadIgnoringCacheData;
    request.timeoutInterval = RequestTimeoutInterval;
    
    return request;
}

@end
