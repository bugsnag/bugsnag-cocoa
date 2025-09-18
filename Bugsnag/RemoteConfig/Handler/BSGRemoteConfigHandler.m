//
//  BSGRemoteConfigHandler.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 12/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BSGRemoteConfigHandler.h"
#import "BugsnagLogger.h"
#import "BugsnagConfiguration+Private.h"

@interface BSGRemoteConfigHandler ()

@property (nonatomic, strong) BSGRemoteConfigService *service;
@property (nonatomic, strong) BSGRemoteConfigStore *store;
@property (nonatomic, strong) BugsnagConfiguration *configuration;
@property (nonatomic, strong) BSGRemoteConfiguration *remoteConfig;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic) BOOL didReadLocalConfig;
@property (nonatomic) BOOL didClearLocalStore;

@end

@implementation BSGRemoteConfigHandler

+ (instancetype)handlerWithService:(BSGRemoteConfigService *)service
                             store:(BSGRemoteConfigStore *)store
                     configuration:(BugsnagConfiguration *)configuration {
    return [[self alloc] initWithService:service store:store configuration:configuration];
}

- (instancetype)initWithService:(BSGRemoteConfigService *)service
                          store:(BSGRemoteConfigStore *)store
                  configuration:(BugsnagConfiguration *)configuration {
    self = [super init];
    if (self) {
        _service = service;
        _store = store;
        _configuration = configuration;
    }
    return self;
}

- (void)initialize {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        @synchronized (strongSelf) {
            [strongSelf loadLocalConfigIfNeeded];
        }
    });
}

- (BSGRemoteConfiguration *)currentConfiguration {
    @synchronized (self) {
        if (![self isRemoteConfigEnabled]) {
            return nil;
        }
        [self loadLocalConfigIfNeeded];
        return self.remoteConfig;
    }
}

- (void)start {
    @synchronized (self) {
        if ([self isRemoteConfigEnabled]) {
            [self loadLocalConfigIfNeeded];
            [self updateRemoteConfig];
            [self startPeriodicUpdateTimer];
        } else {
            if (!self.didClearLocalStore) {
                [self clearLocalStore];
            }
        }
    }
}

- (void)dealloc {
    [self.timer invalidate];
}

#pragma mark - Helpers

- (BOOL)isRemoteConfigEnabled {
    return self.configuration.configurationURL != nil;
}

- (void)updateRemoteConfig {
    [self.service loadRemoteConfigWithCurrentTag:self.remoteConfig.configurationTag
                                      completion:^(BSGRemoteConfiguration * _Nullable config, NSError * _Nullable error) {
        @synchronized (self) {
            if (config) {
                self.remoteConfig = config;
                [self.store saveConfiguration:config];
            }
            if (error) {
                bsg_log_err(@"Unable to load remote config: %@", error);
            }
        }
    }];
}

- (void)loadLocalConfigIfNeeded {
    if (self.remoteConfig || self.didReadLocalConfig) {
        return;
    }
    self.remoteConfig = [self readAndValidateRemoteConfig];
    if (self.remoteConfig == nil) {
        [self clearLocalStore];
    }

    self.didReadLocalConfig = YES;
}

- (BSGRemoteConfiguration *)readAndValidateRemoteConfig {
    BSGRemoteConfiguration *remoteConfig = [self.store loadConfiguration];
    NSString *configVersion = remoteConfig.appVersion ?: @"";
    BOOL isConfigObsolete = ![remoteConfig.appVersion isEqualToString:configVersion];
    BOOL configExpired = remoteConfig.expiryDate && [remoteConfig.expiryDate timeIntervalSinceNow] < 0;
    if (isConfigObsolete || configExpired) {
        return nil;
    }
    return remoteConfig;
}

- (void)startPeriodicUpdateTimer {
    CGFloat randomMultiplier = (CGFloat)arc4random() / (CGFloat)UINT32_MAX;
    NSTimeInterval updateInterval = self.configuration.remoteConfigUpdateInterval -
                                     (self.configuration.remoteConfigUpdateTolerance * randomMultiplier);
    
    self.timer = [NSTimer scheduledTimerWithTimeInterval:updateInterval
                                                  target:self
                                                selector:@selector(updateRemoteConfig)
                                                userInfo:nil
                                                 repeats:YES];
    
    if (@available(iOS 10.0, macOS 10.12, tvOS 10.0, watchOS 3.0, *)) {
        self.timer.tolerance = self.configuration.remoteConfigUpdateTolerance;
    }
}

- (void)clearLocalStore {
    [self.store clear];
    self.remoteConfig = nil;
    self.didClearLocalStore = YES;
}

@end
