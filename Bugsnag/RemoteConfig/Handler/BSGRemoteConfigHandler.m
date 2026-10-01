//
//  BSGRemoteConfigHandler.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 12/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <stdlib.h>
#import "BSGRemoteConfigHandler.h"
#import "BugsnagLogger.h"
#import "BugsnagConfiguration+Private.h"

@interface BSGRemoteConfigHandler ()

@property (nonatomic, strong) BSGRemoteConfigService *service;
@property (nonatomic, strong) BSGRemoteConfigStore *store;
@property (nonatomic, strong) BugsnagConfiguration *configuration;
@property (nonatomic, strong) BSGRemoteConfiguration *remoteConfig;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSDate *lastConfigUpdateTime;
@property (nonatomic) BOOL didReadLocalConfig;
@property (nonatomic) BOOL isLoadingRemoteConfig;
@property (nonatomic) BOOL didClearLocalStore;
@property (nonatomic, strong) NSString *expiredConfigTag;
@property (nonatomic, strong) NSDate *expiredConfigExpiryDate;

@end

@implementation BSGRemoteConfigHandler

static NSString * const BSGRemoteConfigCooldownPreference = @"com.bugsnag.remote-config.cooldown-until";
static NSString * const BSGRemoteConfigExpiryRefreshAttemptPreference = @"com.bugsnag.remote-config.expiry-refresh-attempt";
static NSTimeInterval const BSGRemoteConfigCooldownInterval = 24 * 60 * 60;
static NSTimeInterval const BSGRemoteConfigCooldownJitter = 2 * 60 * 60;

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
            if ([strongSelf isRemoteConfigEnabled]) {
                [strongSelf loadLocalConfigIfNeeded];
                [strongSelf clearConfigIfNotValid];
            } else {
                if (!strongSelf.didClearLocalStore) {
                    [strongSelf clearLocalStore];
                }
            }
        }
    });
}

- (BSGRemoteConfiguration *)currentConfiguration {
    @synchronized (self) {
        if (![self isRemoteConfigEnabled]) {
            return nil;
        }
        [self loadLocalConfigIfNeeded];
        [self clearConfigIfNotValid];
        [self updateRemoteConfigIfNeeded];
        return self.remoteConfig;
    }
}

- (void)start {
    // Remote Config is fetched asynchronously after an error requires a refresh.
    /*
    @synchronized (self) {
        if ([self isRemoteConfigEnabled]) {
            [self startPeriodicUpdateTimer];
        }
    }
    */
}

- (void)dealloc {
    /*
    [self.timer invalidate];
    */
}

- (void)setRemoteConfig:(BSGRemoteConfiguration *)remoteConfig {
    _remoteConfig = remoteConfig;
    self.lastConfigUpdateTime = [NSDate date];
}

- (BOOL)hasValidConfig {
    return self.remoteConfig.expiryDate &&
        [self.remoteConfig.expiryDate timeIntervalSinceNow] > 0;
}

#pragma mark - Helpers

- (BOOL)isRemoteConfigEnabled {
    return self.configuration.configurationURL != nil;
}

- (void)updateRemoteConfig {
    NSString *currentTag = nil;
    @synchronized (self) {
        if (self.isLoadingRemoteConfig) {
            return;
        }
        BOOL isRefreshingExpiredConfig = [self canRefreshExpiredConfig];
        if ([self isCooldownActive] && !isRefreshingExpiredConfig) {
            return;
        }
        self.isLoadingRemoteConfig = YES;
        [self setCooldownUntil:[NSDate dateWithTimeIntervalSinceNow:[self cooldownInterval]]];
        if (isRefreshingExpiredConfig) {
            [self recordExpiredConfigRefreshAttempt];
        }

        currentTag = self.remoteConfig.configurationTag;
        if (currentTag == nil) {
            // If in-memory config was cleared after expiry, reuse the persisted tag for revalidation.
            currentTag = [self.store loadConfiguration].configurationTag;
        }
    }
    [self.service loadRemoteConfigWithCurrentTag:currentTag
                                      completion:^(BSGRemoteConfigServiceResponse *response) {
        @synchronized (self) {
            switch (response.type) {
                case BSGRemoteConfigServiceResponseTypeSuccess: {
                    if (response.configuration == nil) {
                        bsg_log_debug(@"Received invalid remote config");
                        break;
                    }
                    BSGRemoteConfiguration *storedConfiguration = [self.store saveConfiguration:response.configuration];
                    if (storedConfiguration) {
                        self.remoteConfig = storedConfiguration;
                    } else {
                        self.remoteConfig = response.configuration;
                        bsg_log_debug(@"Unable to persist remote config");
                    }
                    [self clearExpiredConfigRefreshAttempt];
                    break;
                }
                case BSGRemoteConfigServiceResponseTypeError:
                    break;
                case BSGRemoteConfigServiceResponseTypeNotModified: {
                    NSString *configurationTag = response.configurationTag ?: currentTag;
                    self.remoteConfig = [self.store updateExpiryDate:response.expiryDate
                                                    configurationTag:configurationTag];
                    if (self.remoteConfig) {
                        [self clearExpiredConfigRefreshAttempt];
                    }
                    break;
                }
            }
            self.isLoadingRemoteConfig = NO;
        }
    }];
}

- (void)loadLocalConfigIfNeeded {
    if (self.remoteConfig || self.didReadLocalConfig) {
        return;
    }
    self.remoteConfig = [self.store loadConfiguration];
    if (self.remoteConfig == nil) {
        [self clearLocalStore];
    }

    self.didReadLocalConfig = YES;
}

- (void)clearConfigIfNotValid {
    if (![self hasValidConfig]) {
        if (self.remoteConfig.expiryDate &&
            [self.remoteConfig.expiryDate timeIntervalSinceNow] <= 0) {
            self.expiredConfigTag = self.remoteConfig.configurationTag;
            self.expiredConfigExpiryDate = self.remoteConfig.expiryDate;
        }
        self.remoteConfig = nil;
    }
}

/*
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
*/

- (void)clearLocalStore {
    [self.store clear];
    self.remoteConfig = nil;
    self.didClearLocalStore = YES;
}

- (void)updateRemoteConfigIfNeeded {
    if (self.remoteConfig == nil &&
        !self.isLoadingRemoteConfig) {
        [self updateRemoteConfig];
    }
}

- (BOOL)isCooldownActive {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:BSGRemoteConfigCooldownPreference];
    if (![value isKindOfClass:[NSDate class]]) {
        return NO;
    }
    return [(NSDate *)value timeIntervalSinceNow] > 0;
}

- (void)setCooldownUntil:(NSDate *)cooldownUntil {
    [[NSUserDefaults standardUserDefaults] setObject:cooldownUntil
                                              forKey:BSGRemoteConfigCooldownPreference];
}

- (NSTimeInterval)cooldownInterval {
    uint32_t jitterRange = (uint32_t)(BSGRemoteConfigCooldownJitter * 2) + 1;
    return BSGRemoteConfigCooldownInterval - BSGRemoteConfigCooldownJitter +
        arc4random_uniform(jitterRange);
}

- (BOOL)canRefreshExpiredConfig {
    if (self.expiredConfigExpiryDate == nil) {
        return NO;
    }
    NSDictionary *lastAttempt = [[NSUserDefaults standardUserDefaults]
        dictionaryForKey:BSGRemoteConfigExpiryRefreshAttemptPreference];
    NSDate *expiryDate = lastAttempt[@"expiryDate"];
    NSString *configurationTag = lastAttempt[@"configurationTag"] ?: @"";
    if (![expiryDate isKindOfClass:[NSDate class]] ||
        ![configurationTag isKindOfClass:[NSString class]]) {
        return YES;
    }
    return ![expiryDate isEqualToDate:self.expiredConfigExpiryDate] ||
        ![configurationTag isEqualToString:self.expiredConfigTag ?: @""];
}

- (void)recordExpiredConfigRefreshAttempt {
    [[NSUserDefaults standardUserDefaults] setObject:@{
        @"expiryDate": self.expiredConfigExpiryDate,
        @"configurationTag": self.expiredConfigTag ?: @"",
    } forKey:BSGRemoteConfigExpiryRefreshAttemptPreference];
}

- (void)clearExpiredConfigRefreshAttempt {
    self.expiredConfigTag = nil;
    self.expiredConfigExpiryDate = nil;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:BSGRemoteConfigExpiryRefreshAttemptPreference];
}

@end
