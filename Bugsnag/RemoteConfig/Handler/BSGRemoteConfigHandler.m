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
#import "BSGDefines.h"

#if BSG_HAVE_REACHABILITY
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>
#endif

// YES only when the device definitely has no network connection (e.g. airplane mode). An unknown state
// counts as online, as for event delivery. A network that is up but cannot reach the internet (a captive
// portal, say) counts as online, so its failures still back off.
static BOOL BSGRemoteConfigDeviceIsOffline(void) {
#if BSG_HAVE_REACHABILITY
    struct sockaddr_in zeroAddress = {0};
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(NULL, (const struct sockaddr *)&zeroAddress);
    if (!reachability) {
        return NO;
    }
    SCNetworkReachabilityFlags flags = 0;
    BOOL gotFlags = SCNetworkReachabilityGetFlags(reachability, &flags);
    CFRelease(reachability);
    return gotFlags && (flags & kSCNetworkReachabilityFlagsReachable) == 0;
#else
    return NO;
#endif
}

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
/// Whether the device is offline. Replaceable in tests.
@property (nonatomic, copy) BOOL (^isDeviceOffline)(void);
/// How long to wait before re-checking the network after a request failed with no response. The system
/// can report a lost network a few milliseconds after the request that it broke has already failed.
@property (nonatomic) NSTimeInterval networkLossGracePeriod;
/// Where fetch results are handled. Nil handles them on the queue that delivered them (tests).
@property (nonatomic, strong) dispatch_queue_t completionQueue;

@end

@implementation BSGRemoteConfigHandler

// Keys written by the previous fixed 24h cooldown implementation.
static NSString * const BSGLegacyRemoteConfigCooldownPreference = @"com.bugsnag.remote-config.cooldown-until";
static NSString * const BSGLegacyRemoteConfigExpiryRefreshAttemptPreference = @"com.bugsnag.remote-config.expiry-refresh-attempt";

static NSTimeInterval const BSGRemoteConfigBackoffBase = 15 * 60;
static double const BSGRemoteConfigBackoffMultiplier = 4.0;
static NSTimeInterval const BSGRemoteConfigBackoffCap = 24 * 60 * 60;
static NSTimeInterval const BSGRemoteConfigNetworkUnavailableRetryInterval = 5 * 60;
// The backoff delay reaches its cap at failure index 4 (15 min * 4^4 = 64 h > 24 h), so higher counts
// change nothing; the count stops growing here instead of increasing on every failure.
static NSUInteger const BSGRemoteConfigMaxFetchFailureCount = 5;
// A config is refreshed on an error during the last part of its lifetime, so new rules arrive before the
// current ones expire: the last hour, or the last 10% of a lifetime shorter than 10 hours.
static NSTimeInterval const BSGRemoteConfigRefreshWindow = 60 * 60;
static double const BSGRemoteConfigRefreshWindowFraction = 0.1;
static NSTimeInterval const BSGRemoteConfigNetworkLossGracePeriod = 0.5;

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
        _isDeviceOffline = ^{ return BSGRemoteConfigDeviceIsOffline(); };
        _networkLossGracePeriod = BSGRemoteConfigNetworkLossGracePeriod;
        _completionQueue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
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

// Also read by the event upload thread while a fetch result may be changing the config on another thread.
- (BOOL)hasValidConfig {
    @synchronized (self) {
        NSDate *expiryDate = self.remoteConfig.expiryDate;
        return expiryDate && [expiryDate timeIntervalSinceNow] > 0;
    }
}

- (NSDate *)lastConfigUpdateTime {
    @synchronized (self) {
        return _lastConfigUpdateTime;
    }
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
    NSTimeInterval firstFetchDelay = 0;
    @synchronized (self) {
        // Callers normally load it first; this keeps the cooldown and attempt tracking working for any other caller.
        [self loadFetchStateIfNeeded];
        if (self.isLoadingRemoteConfig || [self isCooldownActive]) {
            return;
        }
        if (self.isDeviceOffline()) {
            // Not a failure: the next error once the device is back online fetches straight away.
            bsg_log_debug(@"Skipping remote config fetch because there is no network connection");
            return;
        }
        self.isLoadingRemoteConfig = YES;
        if ([self shouldDelayFetch]) {
            double randomFraction = (double)arc4random() / (double)UINT32_MAX;
            firstFetchDelay = MAX(0, self.configuration.remoteConfigFirstFetchJitter) * randomFraction;
        }
    }
    if (firstFetchDelay <= 0) {
        [self sendRemoteConfigRequest];
        return;
    }
    // Spread a fleet's first fetches so devices whose first errors arrive together do not all fetch at once.
    // Errors are still delivered meanwhile; they just do not have discard rules yet.
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(firstFetchDelay * NSEC_PER_SEC)),
                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [weakSelf sendRemoteConfigRequest];
    });
}

- (void)sendRemoteConfigRequest {
    NSString *currentTag = nil;
    @synchronized (self) {
        if (self.isDeviceOffline()) {
            // The network went away during the first-fetch delay.
            bsg_log_debug(@"Skipping remote config fetch because there is no network connection");
            self.isLoadingRemoteConfig = NO;
            return;
        }
        // Persisted before the request so an attempt interrupted by process death is counted as a failure on next launch.
        self.fetchState.attemptInProgress = YES;
        [self persistFetchState];

        currentTag = self.remoteConfig.configurationTag;
        if (currentTag == nil) {
            // If in-memory config was cleared after expiry, reuse the persisted tag for revalidation.
            currentTag = [self.store loadConfiguration].configurationTag;
        }
    }
    [self loadRemoteConfigWithCurrentTag:currentTag allowsUnconditionalRetry:YES];
}

// A fetch made with no valid config: the first one for this app version and build, or one after the cached
// config expired. Expiry times are spread, but the errors that trigger these fetches can come at the same moment
// across a fleet (a backend outage, say), so they get a random delay. Retries are already spread by the backoff
// and refreshes before expiry by the expiry jitter, so neither is delayed.
- (BOOL)shouldDelayFetch {
    return self.remoteConfig == nil && self.fetchState.fetchFailureCount == 0;
}

- (void)loadRemoteConfigWithCurrentTag:(NSString *)currentTag allowsUnconditionalRetry:(BOOL)allowsUnconditionalRetry {
    [self.service loadRemoteConfigWithCurrentTag:currentTag
                                      completion:^(BSGRemoteConfigServiceResponse *response) {
        // The completion runs on the URL session's delegate queue, which the host app's own requests on the
        // shared session also use. Handling the result takes the lock and writes files, so do it elsewhere.
        dispatch_queue_t queue = self.completionQueue;
        if (!queue) {
            [self handleResponse:response currentTag:currentTag allowsUnconditionalRetry:allowsUnconditionalRetry];
            return;
        }
        dispatch_async(queue, ^{
            [self handleResponse:response currentTag:currentTag allowsUnconditionalRetry:allowsUnconditionalRetry];
        });
    }];
}

- (void)handleResponse:(BSGRemoteConfigServiceResponse *)response
            currentTag:(NSString *)currentTag
allowsUnconditionalRetry:(BOOL)allowsUnconditionalRetry {
    @synchronized (self) {
        BOOL didSucceed = NO;
        switch (response.type) {
            case BSGRemoteConfigServiceResponseTypeSuccess: {
                if (response.configuration == nil) {
                    bsg_log_debug(@"Received invalid remote config");
                    break;
                }
                response.configuration.fetchedAt = [NSDate date];
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
                BSGRemoteConfiguration *revalidatedConfiguration = nil;
                BSGRemoteConfigExpiryUpdateResult result = [self.store updateExpiryDate:response.expiryDate
                                                                      configurationTag:configurationTag
                                                                         configuration:&revalidatedConfiguration];
                switch (result) {
                    case BSGRemoteConfigExpiryUpdateResultUpdated:
                        self.remoteConfig = revalidatedConfiguration;
                        didSucceed = YES;
                        break;
                    case BSGRemoteConfigExpiryUpdateResultWriteFailed:
                        // The server confirmed the cached config; only saving its new expiry failed.
                        // Keep it for this process rather than discarding it and fetching it again.
                        bsg_log_warn(@"Unable to persist revalidated remote config; it will be used until the app exits");
                        self.remoteConfig = revalidatedConfiguration;
                        didSucceed = YES;
                        break;
                    case BSGRemoteConfigExpiryUpdateResultMissing:
                    case BSGRemoteConfigExpiryUpdateResultTagMismatch:
                        // The cached config no longer matches the server's validator (or is missing),
                        // so drop it and immediately request a full response once.
                        bsg_log_debug(@"Unable to revalidate cached remote config");
                        self.remoteConfig = nil;
                        [self.store clear];
                        if (currentTag && allowsUnconditionalRetry) {
                            [self loadRemoteConfigWithCurrentTag:nil allowsUnconditionalRetry:NO];
                            return;
                        }
                        break;
                }
                break;
            }
        }
        if (didSucceed) {
            [self recordFetchSuccess];
        } else if (response.networkUnavailable || response.failedWithoutResponse) {
            [self recordFailureWithoutResponse:response];
            return;
        } else {
            [self recordFetchFailureWithRetryAfter:response.retryAfter];
        }
        self.isLoadingRemoteConfig = NO;
    }
}

// The request failed before the config service answered. If that was because the device lost its network,
// it is not a config service failure, so no backoff is started. Must be called with the lock held; it
// clears isLoadingRemoteConfig once the outcome is recorded.
- (void)recordFailureWithoutResponse:(BSGRemoteConfigServiceResponse *)response {
    if (self.isDeviceOffline()) {
        [self recordNetworkLostForResponse:response];
        self.isLoadingRemoteConfig = NO;
        return;
    }
    if (response.networkUnavailable) {
        // The system said there was no connection, but the device now looks online.
        [self recordNetworkUnavailable];
        self.isLoadingRemoteConfig = NO;
        return;
    }
    // The device still looks online, but the system may not have reported the lost network yet.
    // Check once more after a short wait; the request stays in progress until then.
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.networkLossGracePeriod * NSEC_PER_SEC)),
                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        @synchronized (strongSelf) {
            if (strongSelf.isDeviceOffline()) {
                [strongSelf recordNetworkLostForResponse:response];
            } else {
                [strongSelf recordFetchFailureWithRetryAfter:response.retryAfter];
            }
            strongSelf.isLoadingRemoteConfig = NO;
        }
    });
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
    NSString *bundleVersion = self.configuration.bundleVersion;
    BSGRemoteConfigFetchState *state = [self.store loadFetchState];
    if (state && (![state.appVersion ?: @"" isEqualToString:appVersion ?: @""] ||
                  ![state.bundleVersion ?: @"" isEqualToString:bundleVersion ?: @""])) {
        // Retry state is scoped to the app version and build, so a new binary is not locked out by a
        // previous one's cooldown.
        [self.store clearFetchState];
        state = nil;
    }
    if (state == nil) {
        state = [BSGRemoteConfigFetchState new];
        state.appVersion = appVersion;
        state.bundleVersion = bundleVersion;
    }
    self.fetchState = state;

    if (state.attemptInProgress) {
        // The previous process ended before the attempt's outcome was recorded (e.g. a crash during the fetch).
        if (![self recordFetchFailureWithRetryAfter:0]) {
            // The file still says an attempt is in progress, so every launch would count this same attempt
            // again and start in a cooldown. Remove it; the backoff recorded above still applies to this run.
            [self.store clearFetchState];
        }
    } else if (state.nextAllowedFetchAt &&
               [state.nextAllowedFetchAt timeIntervalSinceNow] > BSGRemoteConfigBackoffCap) {
        // Guards against the device clock having been ahead when the cooldown was stored.
        state.nextAllowedFetchAt = [NSDate dateWithTimeIntervalSinceNow:BSGRemoteConfigBackoffCap];
        [self persistFetchState];
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

- (void)refreshConfigurationIfDue {
    @synchronized (self) {
        // Called for every event, so the cheap date check comes first; checking that remote config is
        // enabled parses the configuration URL.
        if (!self.isLoadingRemoteConfig && [self isRefreshDue] && [self isRemoteConfigEnabled]) {
            [self updateRemoteConfig];
        }
    }
}

- (void)updateRemoteConfigIfNeeded {
    if (!self.isLoadingRemoteConfig &&
        (self.remoteConfig == nil || [self isRefreshDue])) {
        [self updateRemoteConfig];
    }
}

// The cached config is still valid but is in the last part of its lifetime, so it is refreshed in the
// background while its rules keep applying.
- (BOOL)isRefreshDue {
    BSGRemoteConfiguration *config = self.remoteConfig;
    if (!config.expiryDate || !config.fetchedAt) {
        return NO;
    }
    NSTimeInterval lifetime = [config.expiryDate timeIntervalSinceDate:config.fetchedAt];
    NSTimeInterval remaining = [config.expiryDate timeIntervalSinceNow];
    NSTimeInterval window = MIN(BSGRemoteConfigRefreshWindow, lifetime * BSGRemoteConfigRefreshWindowFraction);
    return lifetime > 0 && remaining > 0 && remaining <= window;
}

- (BOOL)isCooldownActive {
    NSDate *nextAllowedFetchAt = self.fetchState.nextAllowedFetchAt;
    return nextAllowedFetchAt && [nextAllowedFetchAt timeIntervalSinceNow] > 0;
}

- (void)recordFetchSuccess {
    self.fetchState.fetchFailureCount = 0;
    self.fetchState.nextAllowedFetchAt = nil;
    self.fetchState.attemptInProgress = NO;
    if (![self persistFetchState]) {
        // Otherwise the file may still say an attempt is in progress, and the next launch would count
        // this successful fetch as a failure.
        [self.store clearFetchState];
    }
}

- (BOOL)recordFetchFailureWithRetryAfter:(NSTimeInterval)retryAfter {
    NSUInteger failureIndex = self.fetchState.fetchFailureCount;
    double randomFraction = (double)arc4random() / (double)UINT32_MAX;
    NSTimeInterval wait = [[self class] backoffWaitForFailureIndex:failureIndex randomFraction:randomFraction];
    wait = MIN(BSGRemoteConfigBackoffCap, MAX(wait, retryAfter));

    self.fetchState.nextAllowedFetchAt = [NSDate dateWithTimeIntervalSinceNow:wait];
    self.fetchState.fetchFailureCount = MIN(failureIndex + 1, BSGRemoteConfigMaxFetchFailureCount);
    self.fetchState.attemptInProgress = NO;
    return [self persistFetchState];
}

// Being offline is not a config service failure, so retry soon without advancing the backoff.
- (void)recordNetworkUnavailable {
    self.fetchState.nextAllowedFetchAt = [NSDate dateWithTimeIntervalSinceNow:BSGRemoteConfigNetworkUnavailableRetryInterval];
    self.fetchState.attemptInProgress = NO;
    if (![self persistFetchState]) {
        // Being offline is not a failure, so do not leave an in-progress attempt for the next launch to count.
        [self.store clearFetchState];
    }
}

// A request that timed out may have reached the config service, which may be the reason it was slow, so it
// waits as briefly as an offline error before the next attempt. Other requests that failed when the network
// went away did not get that far and need no wait.
- (void)recordNetworkLostForResponse:(BSGRemoteConfigServiceResponse *)response {
    if ([response.error.domain isEqualToString:NSURLErrorDomain] && response.error.code == NSURLErrorTimedOut) {
        [self recordNetworkUnavailable];
    } else {
        [self recordNetworkLost];
    }
}

// The device lost its network during the request. Not a failure, and no wait is needed: while the device is
// offline no request is sent, and the next error once it is back online fetches straight away.
- (void)recordNetworkLost {
    bsg_log_debug(@"Remote config request failed after the network connection was lost; not starting backoff");
    self.fetchState.attemptInProgress = NO;
    if (![self persistFetchState]) {
        // Do not leave an in-progress attempt for the next launch to count as a failure.
        [self.store clearFetchState];
    }
}

// The in-memory fetch state always governs this process; the file only carries it to the next launch.
- (BOOL)persistFetchState {
    if ([self.store saveFetchState:self.fetchState]) {
        return YES;
    }
    bsg_log_warn(@"Unable to save remote config retry state; the retry backoff applies until the app exits but will not carry over to the next launch");
    return NO;
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
