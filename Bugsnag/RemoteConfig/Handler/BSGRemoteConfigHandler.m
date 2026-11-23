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
@property (nonatomic, strong) BSGRemoteConfigFetchState *fetchState;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSDate *lastConfigUpdateTime;
@property (nonatomic) BOOL didReadLocalConfig;
@property (nonatomic) BOOL didLoadFetchState;
@property (nonatomic) BOOL isLoadingRemoteConfig;
@property (nonatomic) BOOL didClearLocalStore;

@end

@implementation BSGRemoteConfigHandler

// Keys written by the previous fixed 24h cooldown implementation.
static NSString * const BSGLegacyRemoteConfigCooldownPreference = @"com.bugsnag.remote-config.cooldown-until";
static NSString * const BSGLegacyRemoteConfigExpiryRefreshAttemptPreference = @"com.bugsnag.remote-config.expiry-refresh-attempt";

static NSTimeInterval const BSGRemoteConfigBackoffBase = 15 * 60;
static double const BSGRemoteConfigBackoffMultiplier = 4.0;
static NSTimeInterval const BSGRemoteConfigBackoffCap = 24 * 60 * 60;
static NSTimeInterval const BSGRemoteConfigNetworkUnavailableRetryInterval = 5 * 60;

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
            [strongSelf removeLegacyCooldownPreferences];
            if ([strongSelf isRemoteConfigEnabled]) {
                [strongSelf loadLocalConfigIfNeeded];
                [strongSelf loadFetchStateIfNeeded];
                [strongSelf clearConfigIfNotValid];
            } else {
                if (!strongSelf.didClearLocalStore) {
                    [strongSelf clearLocalStore];
                    [strongSelf.store clearFetchState];
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
        [self loadFetchStateIfNeeded];
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

#pragma mark - Backoff

+ (NSTimeInterval)backoffDelayForFailureIndex:(NSUInteger)failureIndex {
    NSTimeInterval delay = BSGRemoteConfigBackoffBase * pow(BSGRemoteConfigBackoffMultiplier, (double)failureIndex);
    return MIN(BSGRemoteConfigBackoffCap, delay);
}

+ (NSTimeInterval)backoffWaitForFailureIndex:(NSUInteger)failureIndex randomFraction:(double)randomFraction {
    NSTimeInterval halfDelay = [self backoffDelayForFailureIndex:failureIndex] / 2;
    double fraction = MIN(1.0, MAX(0.0, randomFraction));
    return halfDelay + halfDelay * fraction;
}

#pragma mark - Helpers

- (BOOL)isRemoteConfigEnabled {
    return self.configuration.configurationURL != nil;
}

- (void)updateRemoteConfig {
    NSString *currentTag = nil;
    @synchronized (self) {
        if (self.isLoadingRemoteConfig || [self isCooldownActive]) {
            return;
        }
        self.isLoadingRemoteConfig = YES;
        // Persisted before the request so an attempt interrupted by process death is counted as a failure on next launch.
        self.fetchState.attemptInProgress = YES;
        [self.store saveFetchState:self.fetchState];

        currentTag = self.remoteConfig.configurationTag;
        if (currentTag == nil) {
            // If in-memory config was cleared after expiry, reuse the persisted tag for revalidation.
            currentTag = [self.store loadConfiguration].configurationTag;
        }
    }
    [self loadRemoteConfigWithCurrentTag:currentTag allowsUnconditionalRetry:YES];
}

- (void)loadRemoteConfigWithCurrentTag:(NSString *)currentTag allowsUnconditionalRetry:(BOOL)allowsUnconditionalRetry {
    [self.service loadRemoteConfigWithCurrentTag:currentTag
                                      completion:^(BSGRemoteConfigServiceResponse *response) {
        @synchronized (self) {
            BOOL didSucceed = NO;
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
                    didSucceed = YES;
                    break;
                }
                case BSGRemoteConfigServiceResponseTypeError:
                    break;
                case BSGRemoteConfigServiceResponseTypeNotModified: {
                    NSString *configurationTag = response.configurationTag ?: currentTag;
                    self.remoteConfig = [self.store updateExpiryDate:response.expiryDate
                                                    configurationTag:configurationTag];
                    if (self.remoteConfig) {
                        didSucceed = YES;
                    } else {
                        // The cached config no longer matches the server's validator (or is missing),
                        // so drop it and immediately request a full response once.
                        bsg_log_debug(@"Unable to revalidate cached remote config");
                        [self.store clear];
                        if (currentTag && allowsUnconditionalRetry) {
                            [self loadRemoteConfigWithCurrentTag:nil allowsUnconditionalRetry:NO];
                            return;
                        }
                    }
                    break;
                }
            }
            if (didSucceed) {
                [self recordFetchSuccess];
            } else if (response.networkUnavailable) {
                [self recordNetworkUnavailable];
            } else {
                [self recordFetchFailureWithRetryAfter:response.retryAfter];
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

- (void)loadFetchStateIfNeeded {
    if (self.didLoadFetchState) {
        return;
    }
    self.didLoadFetchState = YES;

    NSString *appVersion = self.configuration.appVersion;
    BSGRemoteConfigFetchState *state = [self.store loadFetchState];
    if (state && ![state.appVersion ?: @"" isEqualToString:appVersion ?: @""]) {
        // Retry state is scoped to the app version so a new binary is not locked out by a previous version's cooldown.
        [self.store clearFetchState];
        state = nil;
    }
    if (state == nil) {
        state = [BSGRemoteConfigFetchState new];
        state.appVersion = appVersion;
    }
    self.fetchState = state;

    if (state.attemptInProgress) {
        // The previous process ended before the attempt's outcome was recorded (e.g. a crash during the fetch).
        [self recordFetchFailureWithRetryAfter:0];
    } else if (state.nextAllowedFetchAt &&
               [state.nextAllowedFetchAt timeIntervalSinceNow] > BSGRemoteConfigBackoffCap) {
        // Guards against the device clock having been ahead when the cooldown was stored.
        state.nextAllowedFetchAt = [NSDate dateWithTimeIntervalSinceNow:BSGRemoteConfigBackoffCap];
        [self.store saveFetchState:state];
    }
}

- (void)clearConfigIfNotValid {
    if (![self hasValidConfig]) {
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
    NSDate *nextAllowedFetchAt = self.fetchState.nextAllowedFetchAt;
    return nextAllowedFetchAt && [nextAllowedFetchAt timeIntervalSinceNow] > 0;
}

- (void)recordFetchSuccess {
    self.fetchState.fetchFailureCount = 0;
    self.fetchState.nextAllowedFetchAt = nil;
    self.fetchState.attemptInProgress = NO;
    [self.store saveFetchState:self.fetchState];
}

- (void)recordFetchFailureWithRetryAfter:(NSTimeInterval)retryAfter {
    NSUInteger failureIndex = self.fetchState.fetchFailureCount;
    double randomFraction = (double)arc4random() / (double)UINT32_MAX;
    NSTimeInterval wait = [[self class] backoffWaitForFailureIndex:failureIndex randomFraction:randomFraction];
    wait = MIN(BSGRemoteConfigBackoffCap, MAX(wait, retryAfter));

    self.fetchState.nextAllowedFetchAt = [NSDate dateWithTimeIntervalSinceNow:wait];
    self.fetchState.fetchFailureCount = failureIndex + 1;
    self.fetchState.attemptInProgress = NO;
    [self.store saveFetchState:self.fetchState];
}

// Being offline is not a config service failure, so retry soon without advancing the backoff.
- (void)recordNetworkUnavailable {
    self.fetchState.nextAllowedFetchAt = [NSDate dateWithTimeIntervalSinceNow:BSGRemoteConfigNetworkUnavailableRetryInterval];
    self.fetchState.attemptInProgress = NO;
    [self.store saveFetchState:self.fetchState];
}

- (void)removeLegacyCooldownPreferences {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    for (NSString *key in @[BSGLegacyRemoteConfigCooldownPreference,
                            BSGLegacyRemoteConfigExpiryRefreshAttemptPreference]) {
        if ([defaults objectForKey:key]) {
            [defaults removeObjectForKey:key];
        }
    }
}

@end
