//
//  BSGRemoteConfigHandler.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 12/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGRemoteConfigHandler.h"
#import "BugsnagLogger.h"

@interface BSGRemoteConfigHandler ()

@property (nonatomic, strong) BSGRemoteConfigService *service;
@property (nonatomic, strong) BSGRemoteConfigStore *store;
@property (nonatomic, strong) BugsnagConfiguration *configuration;
@property (nonatomic, strong) BSGRemoteConfiguration *remoteConfig;
@property (nonatomic) BOOL didReadLocalConfig;

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
        [self loadLocalConfigIfNeeded];
        return self.remoteConfig;
    }
}

- (void)start {
    @synchronized (self) {
        [self loadLocalConfigIfNeeded];
        [self updateRemoteConfig];
    }
}

#pragma mark - Helpers

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
    if (self.remoteConfig == nil && !self.didReadLocalConfig) {
        self.remoteConfig = [self.store loadConfiguration];
        self.didReadLocalConfig = YES;
    }
}

@end
