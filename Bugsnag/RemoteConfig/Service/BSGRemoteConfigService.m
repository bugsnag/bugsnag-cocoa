//
//  BSGRemoteConfigService.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 11/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

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

static NSString *ContentTypeHeader = @"Content-Type";
static NSString *IfNoneMatchHeader = @"If-None-Match";
static NSString *ETagHeader = @"ETag";
static NSString *CacheControlHeader = @"Cache-Control";
static NSString *CacheControlMaxAgePrefix = @"max-age=";

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

- (void)loadRemoteConfigWithCurrentTag:(NSString *)tag completion:(BSGRemoteConfigServiceCompletion)completion {
    NSURL *configUrl = self.configuration.configurationURL;
    if (!configUrl) {
        completion(nil, [self noUrlError]);
        return;
    }
    NSURLRequest *request = [self requestWithUrl:configUrl currentTag:tag];
    if (!request) {
        completion(nil, [self requestBuildingError]);
        return;
    }
    [self downloadRemoteConfigWithRequest:request
                                 didRetry:NO
                               completion:completion];
}

#pragma mark - Helpers

- (void)downloadRemoteConfigWithRequest:(NSURLRequest *)request
                               didRetry:(BOOL)didRetry
                             completion:(BSGRemoteConfigServiceCompletion)completion {
    __weak typeof(self) weakSelf = self;
    [[self.session dataTaskWithRequest:request
                     completionHandler:^(NSData * _Nullable data,
                                         NSURLResponse * _Nullable response,
                                         NSError * _Nullable error) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {
            completion(nil, error);
            return;
        }
        if (!data) {
            completion(nil, error);
            return;
        }
        
        NSData *content = data;
        NSError *jsonError = nil;
        NSDictionary *configJson = BSGJSONDictionaryFromData(content, 0, &jsonError);
        if (!configJson) {
            completion(nil, jsonError);
            return;
        }
        
        BSGRemoteConfiguration *remoteConfig;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            NSString *etag = httpResponse.allHeaderFields[ETagHeader];
            NSString *cacheControl = httpResponse.allHeaderFields[CacheControlHeader];
            
            NSDate *expiryDate = [strongSelf expiryDateFromCacheControl:cacheControl];
            
            remoteConfig = [BSGRemoteConfiguration configFromJson:configJson
                                                             eTag:etag
                                                       expiryDate:expiryDate
                                                       appVersion:strongSelf.configuration.appVersion];
        } else {
            remoteConfig = [BSGRemoteConfiguration configFromJson:configJson];
        }
        
        if (remoteConfig) {
            completion(remoteConfig, nil);
        } else {
            if (didRetry) {
                completion(nil, [strongSelf configNotValidError]);
            } else {
                [strongSelf downloadRemoteConfigWithRequest:request didRetry:YES completion:completion];
            }
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

- (NSDate *)expiryDateFromCacheControl:(NSString *)cacheControl {
    NSTimeInterval maxAge = [self parseMaxAgeFromCacheControl:cacheControl];
    if (maxAge > 0) {
        return [NSDate dateWithTimeIntervalSinceNow:maxAge];
    }
    
    NSTimeInterval defaultExpireTime = self.configuration.remoteConfigUpdateInterval +
                                        self.configuration.remoteConfigUpdateTolerance;
    return [NSDate dateWithTimeIntervalSinceNow:defaultExpireTime];
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

- (NSURLRequest *)requestWithUrl:(NSURL *)url currentTag:(NSString *)tag {
    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    headers[ContentTypeHeader] = @"application/json";
    if (tag) {
        headers[IfNoneMatchHeader] = tag;
    }
    headers[BugsnagHTTPHeaderNameApiKey] = self.configuration.apiKey;
    headers[BugsnagHTTPHeaderNameNotifierName] = self.notifier.name;
    headers[BugsnagHTTPHeaderNameNotifierVersion] = self.notifier.version;
    
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
    
    
    urlComponents.queryItems = @[versionQueryItem,
                                 bundleVersionQueryItem,
                                 osVersionQueryItem,
                                 releaseStageQueryItem,
                                 binaryArchQueryItem,
                                 appIdQueryItem];
    NSURL *finalUrl = urlComponents.URL;
    
    if (!finalUrl) {
        return nil;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:finalUrl];
    request.allHTTPHeaderFields = headers;
    request.HTTPMethod = @"GET";
    
    return request;
}

@end
