//
//  BSGRemoteConfigHandler.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 12/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

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
    BOOL isConfigObsolete = remoteConfig.appVersion != self.configuration.appVersion;
    BOOL configExpired = remoteConfig.expiryDate && [remoteConfig.expiryDate timeIntervalSinceNow] < 0;
    if (isConfigObsolete || configExpired) {
        return nil;
    }
    return remoteConfig;
}

- (void)startPeriodicUpdateTimer {
    __block __weak __typeof(self) weakSelf = self;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:self.configuration.remoteConfigUpdateInterval
                                                 repeats:YES
                                                   block:^(NSTimer * _Nonnull timer) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            @synchronized (strongSelf) {
                [strongSelf updateRemoteConfig];
            }
        } else {
            [timer invalidate];
        }
    }];
    self.timer.tolerance = self.configuration.remoteConfigUpdateTolerance;
}

- (void)clearLocalStore {
    [self.store clear];
    self.remoteConfig = nil;
    self.didClearLocalStore = YES;
}

@end
