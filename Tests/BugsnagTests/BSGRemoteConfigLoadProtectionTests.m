//
//  BSGRemoteConfigLoadProtectionTests.m
//  Bugsnag
//

#import <XCTest/XCTest.h>
#import "BugsnagConfiguration+Private.h"
#import "BugsnagTestConstants.h"
#import "BSGRemoteConfigHandler.h"
#import "BSGRemoteConfigService.h"
#import "BSGRemoteConfigStore.h"
#import "BSGFileLocations.h"

static NSString * const BSGLegacyRemoteConfigCooldownPreference = @"com.bugsnag.remote-config.cooldown-until";
static NSString * const BSGLegacyRemoteConfigExpiryRefreshAttemptPreference = @"com.bugsnag.remote-config.expiry-refresh-attempt";

static NSTimeInterval const Minute = 60;
static NSTimeInterval const Hour = 60 * 60;

@interface BSGTestRemoteConfigConfiguration : BugsnagConfiguration
@property (nonatomic, strong) NSURL *testConfigurationURL;
@end
@implementation BSGTestRemoteConfigConfiguration
- (NSURL *)configurationURL { return self.testConfigurationURL; }
@end

@interface BSGRecordingRemoteConfigService : BSGRemoteConfigService
@property (nonatomic) NSUInteger requestCount;
@property (nonatomic, strong) NSString *currentTag;
@property (nonatomic, strong) BSGRemoteConfigServiceResponse *response;
/// Returned in order before falling back to `response`.
@property (nonatomic, strong) NSMutableArray<BSGRemoteConfigServiceResponse *> *queuedResponses;
@property (nonatomic, strong) NSMutableArray *requestedTags;
@end
@implementation BSGRecordingRemoteConfigService
- (void)loadRemoteConfigWithCurrentTag:(NSString *)tag completion:(BSGRemoteConfigServiceCompletion)completion {
    self.requestCount++;
    self.currentTag = tag;
    if (!self.requestedTags) { self.requestedTags = [NSMutableArray array]; }
    [self.requestedTags addObject:tag ?: [NSNull null]];
    BSGRemoteConfigServiceResponse *response = self.response;
    if (self.queuedResponses.count > 0) {
        response = self.queuedResponses.firstObject;
        [self.queuedResponses removeObjectAtIndex:0];
    }
    if (response) { completion(response); }
}
@end

@interface BSGInMemoryRemoteConfigStore : BSGRemoteConfigStore
@property (nonatomic, strong) BSGRemoteConfiguration *configuration;
@property (nonatomic, strong) NSDictionary *fetchStateJson;
@property (nonatomic) BOOL shouldFailSave;
@property (nonatomic) BOOL shouldFailExpiryUpdate;
@property (nonatomic) BOOL attemptWasPersistedBeforeRequest;
@end
@implementation BSGInMemoryRemoteConfigStore
- (BSGRemoteConfiguration *)loadConfiguration { return self.configuration; }
- (BSGRemoteConfiguration *)saveConfiguration:(BSGRemoteConfiguration *)configuration {
    if (self.shouldFailSave) {
        return nil;
    }
    self.configuration = configuration;
    return configuration;
}
- (void)clear { self.configuration = nil; }
- (BSGRemoteConfiguration *)updateExpiryDate:(NSDate *)expiryDate configurationTag:(NSString *)configurationTag {
    if (self.shouldFailExpiryUpdate) {
        return nil;
    }
    if (![self.configuration.configurationTag isEqualToString:configurationTag]) { return nil; }
    self.configuration.expiryDate = expiryDate;
    return self.configuration;
}
// Stored as JSON so each handler sees a fresh copy, as it would after a restart.
- (BSGRemoteConfigFetchState *)loadFetchState { return [BSGRemoteConfigFetchState stateFromJson:self.fetchStateJson]; }
- (BOOL)saveFetchState:(BSGRemoteConfigFetchState *)fetchState {
    if (fetchState.attemptInProgress) {
        self.attemptWasPersistedBeforeRequest = YES;
    }
    self.fetchStateJson = [fetchState toJson];
    return YES;
}
- (void)clearFetchState { self.fetchStateJson = nil; }
- (BSGRemoteConfigFetchState *)fetchState { return [self loadFetchState]; }
- (void)setFetchStateWithAppVersion:(NSString *)appVersion
                       failureCount:(NSUInteger)failureCount
                 nextAllowedFetchAt:(NSDate *)nextAllowedFetchAt
                  attemptInProgress:(BOOL)attemptInProgress {
    BSGRemoteConfigFetchState *state = [BSGRemoteConfigFetchState new];
    state.appVersion = appVersion;
    state.fetchFailureCount = failureCount;
    state.nextAllowedFetchAt = nextAllowedFetchAt;
    state.attemptInProgress = attemptInProgress;
    self.fetchStateJson = [state toJson];
}
@end

static BSGRemoteConfigServiceResponse *BSGResponseWithType(BSGRemoteConfigServiceResponseType type) {
    BSGRemoteConfigServiceResponse *response = [BSGRemoteConfigServiceResponse new];
    response.type = type;
    return response;
}

@interface BSGRemoteConfigLoadProtectionTests : XCTestCase
@end
@implementation BSGRemoteConfigLoadProtectionTests

- (void)setUp {
    [super setUp];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:BSGLegacyRemoteConfigCooldownPreference];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:BSGLegacyRemoteConfigExpiryRefreshAttemptPreference];
}
- (void)tearDown {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:BSGLegacyRemoteConfigCooldownPreference];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:BSGLegacyRemoteConfigExpiryRefreshAttemptPreference];
    [super tearDown];
}
- (BSGRemoteConfigHandler *)handlerWithService:(BSGRecordingRemoteConfigService *)service
                                         store:(BSGInMemoryRemoteConfigStore *)store
                              configurationURL:(NSURL *)configurationURL
                                    appVersion:(NSString *)appVersion {
    return [self handlerWithService:service store:store configurationURL:configurationURL
                         appVersion:appVersion firstFetchJitter:0];
}
- (BSGRemoteConfigHandler *)handlerWithService:(BSGRecordingRemoteConfigService *)service
                                         store:(BSGInMemoryRemoteConfigStore *)store
                              configurationURL:(NSURL *)configurationURL
                                    appVersion:(NSString *)appVersion
                              firstFetchJitter:(NSTimeInterval)firstFetchJitter {
    BSGTestRemoteConfigConfiguration *configuration =
        [[BSGTestRemoteConfigConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    configuration.testConfigurationURL = configurationURL;
    configuration.appVersion = appVersion;
    // Most tests check what a fetch does, so they fetch immediately; the first-fetch jitter tests opt in.
    configuration.remoteConfigFirstFetchJitter = firstFetchJitter;
    return [BSGRemoteConfigHandler handlerWithService:service store:store configuration:configuration];
}
- (BSGRemoteConfigHandler *)jitteredHandlerWithService:(BSGRecordingRemoteConfigService *)service
                                                  store:(BSGInMemoryRemoteConfigStore *)store
                                       firstFetchJitter:(NSTimeInterval)firstFetchJitter {
    return [self handlerWithService:service store:store
                   configurationURL:[NSURL URLWithString:@"https://example.com/config"]
                         appVersion:@"1.0" firstFetchJitter:firstFetchJitter];
}
- (void)waitFor:(NSTimeInterval)seconds {
    XCTestExpectation *expectation = [self expectationWithDescription:@"waited"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [expectation fulfill]; });
    [self waitForExpectations:@[expectation] timeout:seconds + 5];
}
- (BSGRemoteConfigHandler *)handlerWithService:(BSGRecordingRemoteConfigService *)service
                                         store:(BSGInMemoryRemoteConfigStore *)store
                              configurationURL:(NSURL *)configurationURL {
    return [self handlerWithService:service store:store configurationURL:configurationURL appVersion:@"1.0"];
}
- (BSGRemoteConfigHandler *)enabledHandlerWithService:(BSGRecordingRemoteConfigService *)service
                                                 store:(BSGInMemoryRemoteConfigStore *)store {
    return [self handlerWithService:service store:store configurationURL:[NSURL URLWithString:@"https://example.com/config"]];
}
- (void)waitForInitialization {
    XCTestExpectation *expectation = [self expectationWithDescription:@"initialization completed"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [expectation fulfill]; });
    [self waitForExpectations:@[expectation] timeout:1];
}
- (void)assertCooldownOfStore:(BSGInMemoryRemoteConfigStore *)store
                  isBetween:(NSTimeInterval)minimumWait
                        and:(NSTimeInterval)maximumWait
                      since:(NSDate *)beforeRequest
                      until:(NSDate *)afterRequest {
    NSDate *nextAllowedFetchAt = store.fetchState.nextAllowedFetchAt;
    XCTAssertNotNil(nextAllowedFetchAt);
    // Allow one second either side for the time taken between capturing the bounds and recording the cooldown.
    XCTAssertGreaterThanOrEqual([nextAllowedFetchAt timeIntervalSinceDate:beforeRequest], minimumWait - 1);
    XCTAssertLessThanOrEqual([nextAllowedFetchAt timeIntervalSinceDate:afterRequest], maximumWait + 1);
}

#pragma mark - Startup and trigger model

- (void)testInitializeAndStartDoNotFetchRemoteConfig {
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigHandler *handler = [self enabledHandlerWithService:service store:[BSGInMemoryRemoteConfigStore new]];
    [handler initialize]; [handler start];
    [self waitForInitialization];
    XCTAssertEqual(service.requestCount, 0);
}
- (void)testValidCachedConfigDoesNotFetchRemoteConfig {
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    store.configuration = [BSGRemoteConfiguration configFromJson:@{} eTag:@"etag" expiryDate:[NSDate dateWithTimeIntervalSinceNow:60]];
    BSGRemoteConfigHandler *handler = [self enabledHandlerWithService:service store:store];
    XCTAssertEqual([handler currentConfiguration], store.configuration);
    XCTAssertEqual(service.requestCount, 0);
}
- (void)testDisabledRemoteConfigDoesNotFetch {
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigHandler *handler = [self handlerWithService:service store:[BSGInMemoryRemoteConfigStore new] configurationURL:nil];
    XCTAssertNil([handler currentConfiguration]);
    XCTAssertEqual(service.requestCount, 0);
}
- (void)testDisabledRemoteConfigClearsFetchState {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    [store setFetchStateWithAppVersion:@"1.0" failureCount:2 nextAllowedFetchAt:[NSDate dateWithTimeIntervalSinceNow:Hour] attemptInProgress:NO];
    BSGRemoteConfigHandler *handler = [self handlerWithService:[BSGRecordingRemoteConfigService new] store:store configurationURL:nil];
    [handler initialize];
    [self waitForInitialization];
    XCTAssertNil(store.fetchStateJson);
}
- (void)testRemoteConfigEnabledReflectsConfigurationURL {
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    XCTAssertTrue([[self enabledHandlerWithService:service
                                             store:[BSGInMemoryRemoteConfigStore new]] isRemoteConfigEnabled]);
    XCTAssertFalse([[self handlerWithService:service
                                       store:[BSGInMemoryRemoteConfigStore new]
                            configurationURL:nil] isRemoteConfigEnabled]);
}
- (void)testConcurrentCacheMissesStartOnlyOneRequest {
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigHandler *handler = [self enabledHandlerWithService:service
                                                                 store:[BSGInMemoryRemoteConfigStore new]];

    dispatch_apply(100, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t __unused index) {
        [handler currentConfiguration];
    });

    XCTAssertEqual(service.requestCount, 1);
}
- (void)testAttemptIsPersistedBeforeRequestIsSent {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    [[self enabledHandlerWithService:[BSGRecordingRemoteConfigService new] store:store] currentConfiguration];
    XCTAssertTrue(store.attemptWasPersistedBeforeRequest);
    XCTAssertTrue(store.fetchState.attemptInProgress);
}

#pragma mark - Backoff calculation

- (void)testBackoffDelayCeilings {
    XCTAssertEqual([BSGRemoteConfigHandler backoffDelayForFailureIndex:0], 15 * Minute);
    XCTAssertEqual([BSGRemoteConfigHandler backoffDelayForFailureIndex:1], 60 * Minute);
    XCTAssertEqual([BSGRemoteConfigHandler backoffDelayForFailureIndex:2], 240 * Minute);
    XCTAssertEqual([BSGRemoteConfigHandler backoffDelayForFailureIndex:3], 960 * Minute);
    XCTAssertEqual([BSGRemoteConfigHandler backoffDelayForFailureIndex:4], 24 * Hour);
    XCTAssertEqual([BSGRemoteConfigHandler backoffDelayForFailureIndex:10], 24 * Hour);
    XCTAssertEqual([BSGRemoteConfigHandler backoffDelayForFailureIndex:NSUIntegerMax], 24 * Hour);
}
- (void)testBackoffWaitBoundsUseEqualJitter {
    XCTAssertEqual([BSGRemoteConfigHandler backoffWaitForFailureIndex:0 randomFraction:0], 7.5 * Minute);
    XCTAssertEqual([BSGRemoteConfigHandler backoffWaitForFailureIndex:0 randomFraction:1], 15 * Minute);
    XCTAssertEqual([BSGRemoteConfigHandler backoffWaitForFailureIndex:2 randomFraction:0.5], 3 * Hour);
    XCTAssertEqual([BSGRemoteConfigHandler backoffWaitForFailureIndex:4 randomFraction:0], 12 * Hour);
    XCTAssertEqual([BSGRemoteConfigHandler backoffWaitForFailureIndex:4 randomFraction:1], 24 * Hour);
    // Out-of-range fractions are clamped so the floor and ceiling always hold.
    XCTAssertEqual([BSGRemoteConfigHandler backoffWaitForFailureIndex:1 randomFraction:-1], 30 * Minute);
    XCTAssertEqual([BSGRemoteConfigHandler backoffWaitForFailureIndex:1 randomFraction:2], 60 * Minute);
}
- (void)testSampledBackoffWaitsStayWithinFleetWindows {
    for (NSUInteger failureIndex = 0; failureIndex <= 5; failureIndex++) {
        NSTimeInterval delay = [BSGRemoteConfigHandler backoffDelayForFailureIndex:failureIndex];
        NSTimeInterval minimumSeen = DBL_MAX;
        NSTimeInterval maximumSeen = 0;
        for (int sample = 0; sample < 10000; sample++) {
            double fraction = (double)arc4random() / (double)UINT32_MAX;
            NSTimeInterval wait = [BSGRemoteConfigHandler backoffWaitForFailureIndex:failureIndex randomFraction:fraction];
            minimumSeen = MIN(minimumSeen, wait);
            maximumSeen = MAX(maximumSeen, wait);
        }
        XCTAssertGreaterThanOrEqual(minimumSeen, delay / 2);
        XCTAssertLessThanOrEqual(maximumSeen, delay);
        // Waits are spread across the window rather than clustered at one point.
        XCTAssertLessThan(minimumSeen, delay / 2 + delay * 0.05);
        XCTAssertGreaterThan(maximumSeen, delay - delay * 0.05);
    }
}

#pragma mark - Failure handling

- (void)testFailedFetchPersistsFirstBackoffWindow {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    service.response = BSGResponseWithType(BSGRemoteConfigServiceResponseTypeError);
    NSDate *beforeRequest = [NSDate date];
    XCTAssertNil([[self enabledHandlerWithService:service store:store] currentConfiguration]);
    NSDate *afterRequest = [NSDate date];

    XCTAssertEqual(service.requestCount, 1);
    XCTAssertEqual(store.fetchState.fetchFailureCount, 1);
    XCTAssertFalse(store.fetchState.attemptInProgress);
    XCTAssertEqualObjects(store.fetchState.appVersion, @"1.0");
    [self assertCooldownOfStore:store isBetween:7.5 * Minute and:15 * Minute since:beforeRequest until:afterRequest];
}
- (void)testConsecutiveFailuresFollowExponentialBackoff {
    NSTimeInterval expectedWindows[][2] = {
        {7.5 * Minute, 15 * Minute},
        {30 * Minute, 60 * Minute},
        {2 * Hour, 4 * Hour},
        {8 * Hour, 16 * Hour},
        {12 * Hour, 24 * Hour},
        {12 * Hour, 24 * Hour},
    };
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    for (NSUInteger failureIndex = 0; failureIndex < 6; failureIndex++) {
        // Simulate the previous cooldown having elapsed.
        [store setFetchStateWithAppVersion:@"1.0"
                              failureCount:failureIndex
                        nextAllowedFetchAt:[NSDate dateWithTimeIntervalSinceNow:-1]
                         attemptInProgress:NO];
        BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
        service.response = BSGResponseWithType(BSGRemoteConfigServiceResponseTypeError);
        NSDate *beforeRequest = [NSDate date];
        [[self enabledHandlerWithService:service store:store] currentConfiguration];
        NSDate *afterRequest = [NSDate date];

        XCTAssertEqual(service.requestCount, 1);
        XCTAssertEqual(store.fetchState.fetchFailureCount, failureIndex + 1);
        [self assertCooldownOfStore:store
                          isBetween:expectedWindows[failureIndex][0]
                                and:expectedWindows[failureIndex][1]
                              since:beforeRequest
                              until:afterRequest];
    }
}
- (void)testInvalidConfigResponseCountsAsFailure {
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    service.response = BSGResponseWithType(BSGRemoteConfigServiceResponseTypeSuccess);
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    store.shouldFailSave = YES;
    BSGRemoteConfigHandler *handler = [self enabledHandlerWithService:service store:store];

    XCTAssertNil([handler currentConfiguration]);
    XCTAssertNil(store.configuration);
    XCTAssertFalse([handler hasValidConfig]);
    XCTAssertEqual(store.fetchState.fetchFailureCount, 1);
}
- (void)testRetryAfterExtendsCooldown {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigServiceResponse *response = BSGResponseWithType(BSGRemoteConfigServiceResponseTypeError);
    response.retryAfter = 3 * Hour;
    service.response = response;
    NSDate *beforeRequest = [NSDate date];
    [[self enabledHandlerWithService:service store:store] currentConfiguration];
    NSDate *afterRequest = [NSDate date];
    [self assertCooldownOfStore:store isBetween:3 * Hour and:3 * Hour since:beforeRequest until:afterRequest];
}
- (void)testRetryAfterIsCappedAt24Hours {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigServiceResponse *response = BSGResponseWithType(BSGRemoteConfigServiceResponseTypeError);
    response.retryAfter = 7 * 24 * Hour;
    service.response = response;
    NSDate *beforeRequest = [NSDate date];
    [[self enabledHandlerWithService:service store:store] currentConfiguration];
    NSDate *afterRequest = [NSDate date];
    [self assertCooldownOfStore:store isBetween:24 * Hour and:24 * Hour since:beforeRequest until:afterRequest];
}

#pragma mark - Cooldown enforcement

- (void)testCooldownSuppressesFetchAcrossRestart {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    BSGRecordingRemoteConfigService *firstService = [BSGRecordingRemoteConfigService new];
    firstService.response = BSGResponseWithType(BSGRemoteConfigServiceResponseTypeError);
    [[self enabledHandlerWithService:firstService store:store] currentConfiguration];
    XCTAssertEqual(firstService.requestCount, 1);

    BSGRecordingRemoteConfigService *secondService = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigHandler *secondHandler = [self enabledHandlerWithService:secondService store:store];
    XCTAssertNil([secondHandler currentConfiguration]);
    XCTAssertNil([secondHandler currentConfiguration]);
    XCTAssertEqual(secondService.requestCount, 0);
    XCTAssertEqual(store.fetchState.fetchFailureCount, 1);
}
- (void)testCooldownSuppressesFetchForExpiredCachedConfig {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    store.configuration = [BSGRemoteConfiguration configFromJson:@{} eTag:@"expired-etag" expiryDate:[NSDate dateWithTimeIntervalSinceNow:-1]];
    [store setFetchStateWithAppVersion:@"1.0" failureCount:2 nextAllowedFetchAt:[NSDate dateWithTimeIntervalSinceNow:Hour] attemptInProgress:NO];
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigHandler *handler = [self enabledHandlerWithService:service store:store];
    XCTAssertNil([handler currentConfiguration]);
    XCTAssertEqual(service.requestCount, 0);
}
- (void)testElapsedCooldownAllowsFetch {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    [store setFetchStateWithAppVersion:@"1.0" failureCount:2 nextAllowedFetchAt:[NSDate dateWithTimeIntervalSinceNow:-1] attemptInProgress:NO];
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    [[self enabledHandlerWithService:service store:store] currentConfiguration];
    XCTAssertEqual(service.requestCount, 1);
}
- (void)testFutureCooldownIsClampedTo24Hours {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    [store setFetchStateWithAppVersion:@"1.0" failureCount:5 nextAllowedFetchAt:[NSDate dateWithTimeIntervalSinceNow:30 * 24 * Hour] attemptInProgress:NO];
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    [[self enabledHandlerWithService:service store:store] currentConfiguration];
    XCTAssertEqual(service.requestCount, 0);
    XCTAssertLessThanOrEqual([store.fetchState.nextAllowedFetchAt timeIntervalSinceNow], 24 * Hour + 1);
    XCTAssertEqual(store.fetchState.fetchFailureCount, 5);
}

#pragma mark - Success handling

- (void)testSuccessfulFetchResetsBackoffState {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    [store setFetchStateWithAppVersion:@"1.0" failureCount:3 nextAllowedFetchAt:[NSDate dateWithTimeIntervalSinceNow:-1] attemptInProgress:NO];
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigServiceResponse *response = BSGResponseWithType(BSGRemoteConfigServiceResponseTypeSuccess);
    response.configuration = [BSGRemoteConfiguration configFromJson:@{} eTag:@"etag" expiryDate:[NSDate dateWithTimeIntervalSinceNow:60]];
    service.response = response;
    BSGRemoteConfigHandler *handler = [self enabledHandlerWithService:service store:store];

    XCTAssertEqual([handler currentConfiguration], store.configuration);
    XCTAssertEqual(store.fetchState.fetchFailureCount, 0);
    XCTAssertNil(store.fetchState.nextAllowedFetchAt);
    XCTAssertFalse(store.fetchState.attemptInProgress);
}
- (void)testSuccessfulFetchDoesNotStartCooldown {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    BSGRecordingRemoteConfigService *firstService = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigServiceResponse *response = BSGResponseWithType(BSGRemoteConfigServiceResponseTypeSuccess);
    response.configuration = [BSGRemoteConfiguration configFromJson:@{} eTag:@"etag" expiryDate:[NSDate dateWithTimeIntervalSinceNow:60]];
    firstService.response = response;
    [[self enabledHandlerWithService:firstService store:store] currentConfiguration];

    // Once the cached config expires, the next error can refresh it immediately.
    store.configuration.expiryDate = [NSDate dateWithTimeIntervalSinceNow:-1];
    BSGRecordingRemoteConfigService *secondService = [BSGRecordingRemoteConfigService new];
    [[self enabledHandlerWithService:secondService store:store] currentConfiguration];
    XCTAssertEqual(secondService.requestCount, 1);
    XCTAssertEqualObjects(secondService.currentTag, @"etag");
}
- (void)testEmptyConfigResponseIsStoredAsValidConfig {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    [store setFetchStateWithAppVersion:@"1.0" failureCount:1 nextAllowedFetchAt:[NSDate dateWithTimeIntervalSinceNow:-1] attemptInProgress:NO];
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigServiceResponse *response = BSGResponseWithType(BSGRemoteConfigServiceResponseTypeSuccess);
    response.configuration = [BSGRemoteConfiguration configFromJson:@{} eTag:@"empty-etag" expiryDate:[NSDate dateWithTimeIntervalSinceNow:60]];
    service.response = response;
    BSGRemoteConfigHandler *handler = [self enabledHandlerWithService:service store:store];
    XCTAssertEqual([handler currentConfiguration], store.configuration);
    XCTAssertEqual(store.configuration.discardRules.count, 0);
    XCTAssertTrue([handler hasValidConfig]);
    XCTAssertEqual(store.fetchState.fetchFailureCount, 0);
    XCTAssertNil(store.fetchState.nextAllowedFetchAt);
}
- (void)testValidConfigRemainsActiveWhenPersistenceFails {
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigServiceResponse *response = BSGResponseWithType(BSGRemoteConfigServiceResponseTypeSuccess);
    response.configuration = [BSGRemoteConfiguration configFromJson:@{}
                                                               eTag:@"memory-only-etag"
                                                         expiryDate:[NSDate dateWithTimeIntervalSinceNow:60]];
    service.response = response;
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    store.shouldFailSave = YES;
    BSGRemoteConfigHandler *handler = [self enabledHandlerWithService:service store:store];

    XCTAssertEqual([handler currentConfiguration], response.configuration);
    XCTAssertNil(store.configuration);
    XCTAssertTrue([handler hasValidConfig]);
    XCTAssertEqual(store.fetchState.fetchFailureCount, 0);
}

#pragma mark - 304 revalidation

- (void)testExpiredConfigUsesCachedETagFor304Revalidation {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    store.configuration = [BSGRemoteConfiguration configFromJson:@{} eTag:@"cached-etag" expiryDate:[NSDate dateWithTimeIntervalSinceNow:-1]];
    [store setFetchStateWithAppVersion:@"1.0" failureCount:2 nextAllowedFetchAt:[NSDate dateWithTimeIntervalSinceNow:-1] attemptInProgress:NO];
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigServiceResponse *response = BSGResponseWithType(BSGRemoteConfigServiceResponseTypeNotModified);
    response.configurationTag = @"cached-etag";
    response.expiryDate = [NSDate dateWithTimeIntervalSinceNow:60];
    service.response = response;
    BSGRemoteConfigHandler *handler = [self enabledHandlerWithService:service store:store];

    XCTAssertEqual([handler currentConfiguration], store.configuration);
    XCTAssertEqualObjects(service.currentTag, @"cached-etag");
    XCTAssertTrue([handler hasValidConfig]);
    XCTAssertEqual(store.fetchState.fetchFailureCount, 0);
    XCTAssertNil(store.fetchState.nextAllowedFetchAt);
}
- (void)test304RevalidationRetainsDiscardRules {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    store.configuration = [BSGRemoteConfiguration configFromJson:@{
        @"discardRules": @[@{@"matchType": @"ALL"}],
    } eTag:@"cached-etag" expiryDate:[NSDate dateWithTimeIntervalSinceNow:-1]];

    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigServiceResponse *response = BSGResponseWithType(BSGRemoteConfigServiceResponseTypeNotModified);
    response.configurationTag = @"cached-etag";
    response.expiryDate = [NSDate dateWithTimeIntervalSinceNow:60];
    service.response = response;

    BSGRemoteConfigHandler *handler = [self enabledHandlerWithService:service store:store];
    BSGRemoteConfiguration *configuration = [handler currentConfiguration];
    XCTAssertEqualObjects(service.currentTag, @"cached-etag");
    XCTAssertEqual(configuration.discardRules.count, 1);
    XCTAssertEqualObjects(configuration.discardRules.firstObject.matchType, @"ALL");
    XCTAssertTrue([handler hasValidConfig]);
}
- (void)testMismatched304RetriesOnceWithoutETag {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    store.configuration = [BSGRemoteConfiguration configFromJson:@{} eTag:@"cached-etag" expiryDate:[NSDate dateWithTimeIntervalSinceNow:-1]];
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigServiceResponse *notModified = BSGResponseWithType(BSGRemoteConfigServiceResponseTypeNotModified);
    notModified.configurationTag = @"different-etag";
    notModified.expiryDate = [NSDate dateWithTimeIntervalSinceNow:60];
    BSGRemoteConfigServiceResponse *success = BSGResponseWithType(BSGRemoteConfigServiceResponseTypeSuccess);
    success.configuration = [BSGRemoteConfiguration configFromJson:@{} eTag:@"different-etag" expiryDate:[NSDate dateWithTimeIntervalSinceNow:60]];
    service.queuedResponses = [@[notModified, success] mutableCopy];
    BSGRemoteConfigHandler *handler = [self enabledHandlerWithService:service store:store];

    XCTAssertEqual([handler currentConfiguration], success.configuration);
    XCTAssertEqual(service.requestCount, 2);
    XCTAssertEqualObjects(service.requestedTags, (@[@"cached-etag", [NSNull null]]));
    XCTAssertEqual(store.fetchState.fetchFailureCount, 0);
    XCTAssertNil(store.fetchState.nextAllowedFetchAt);
}
- (void)testMismatched304RetryFailureBacksOffAfterOneRetry {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    store.configuration = [BSGRemoteConfiguration configFromJson:@{} eTag:@"cached-etag" expiryDate:[NSDate dateWithTimeIntervalSinceNow:-1]];
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigServiceResponse *response = BSGResponseWithType(BSGRemoteConfigServiceResponseTypeNotModified);
    response.configurationTag = @"different-etag";
    response.expiryDate = [NSDate dateWithTimeIntervalSinceNow:60];
    service.response = response;
    BSGRemoteConfigHandler *handler = [self enabledHandlerWithService:service store:store];

    XCTAssertNil([handler currentConfiguration]);
    XCTAssertEqual(service.requestCount, 2);
    XCTAssertNil(store.configuration);
    XCTAssertEqual(store.fetchState.fetchFailureCount, 1);
    XCTAssertNotNil(store.fetchState.nextAllowedFetchAt);
    XCTAssertFalse(store.fetchState.attemptInProgress);
}
- (void)test304WithoutCachedConfigDoesNotRetry {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigServiceResponse *response = BSGResponseWithType(BSGRemoteConfigServiceResponseTypeNotModified);
    response.expiryDate = [NSDate dateWithTimeIntervalSinceNow:60];
    service.response = response;
    BSGRemoteConfigHandler *handler = [self enabledHandlerWithService:service store:store];

    // No ETag was sent, so a retry without one would be the same request.
    XCTAssertNil([handler currentConfiguration]);
    XCTAssertEqual(service.requestCount, 1);
    XCTAssertEqual(store.fetchState.fetchFailureCount, 1);
}

#pragma mark - Network unavailable

- (void)testNetworkUnavailableRetriesSoonWithoutAdvancingBackoff {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    [store setFetchStateWithAppVersion:@"1.0" failureCount:2 nextAllowedFetchAt:[NSDate dateWithTimeIntervalSinceNow:-1] attemptInProgress:NO];
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigServiceResponse *response = BSGResponseWithType(BSGRemoteConfigServiceResponseTypeError);
    response.networkUnavailable = YES;
    service.response = response;
    NSDate *beforeRequest = [NSDate date];
    [[self enabledHandlerWithService:service store:store] currentConfiguration];
    NSDate *afterRequest = [NSDate date];

    XCTAssertEqual(service.requestCount, 1);
    XCTAssertEqual(store.fetchState.fetchFailureCount, 2);
    XCTAssertFalse(store.fetchState.attemptInProgress);
    [self assertCooldownOfStore:store isBetween:5 * Minute and:5 * Minute since:beforeRequest until:afterRequest];
}
- (void)testNetworkUnavailableCooldownSuppressesFetch {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    BSGRecordingRemoteConfigService *firstService = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigServiceResponse *response = BSGResponseWithType(BSGRemoteConfigServiceResponseTypeError);
    response.networkUnavailable = YES;
    firstService.response = response;
    [[self enabledHandlerWithService:firstService store:store] currentConfiguration];

    BSGRecordingRemoteConfigService *secondService = [BSGRecordingRemoteConfigService new];
    [[self enabledHandlerWithService:secondService store:store] currentConfiguration];
    XCTAssertEqual(secondService.requestCount, 0);
    XCTAssertEqual(store.fetchState.fetchFailureCount, 0);
}

#pragma mark - Version scope

- (void)testAppVersionChangeResetsBackoffState {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    [store setFetchStateWithAppVersion:@"1.0" failureCount:4 nextAllowedFetchAt:[NSDate dateWithTimeIntervalSinceNow:12 * Hour] attemptInProgress:NO];
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigServiceResponse *response = BSGResponseWithType(BSGRemoteConfigServiceResponseTypeSuccess);
    response.configuration = [BSGRemoteConfiguration configFromJson:@{} eTag:@"v2" expiryDate:[NSDate dateWithTimeIntervalSinceNow:60]];
    service.response = response;
    BSGRemoteConfigHandler *handler = [self handlerWithService:service
                                                         store:store
                                              configurationURL:[NSURL URLWithString:@"https://example.com/config"]
                                                    appVersion:@"2.0"];

    XCTAssertNotNil([handler currentConfiguration]);
    XCTAssertEqual(service.requestCount, 1);
    XCTAssertEqualObjects(store.fetchState.appVersion, @"2.0");
    XCTAssertEqual(store.fetchState.fetchFailureCount, 0);
    XCTAssertNil(store.fetchState.nextAllowedFetchAt);
}
- (void)testAppVersionChangeStartsBackoffFromFirstWindow {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    [store setFetchStateWithAppVersion:@"1.0" failureCount:4 nextAllowedFetchAt:[NSDate dateWithTimeIntervalSinceNow:12 * Hour] attemptInProgress:NO];
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    service.response = BSGResponseWithType(BSGRemoteConfigServiceResponseTypeError);
    NSDate *beforeRequest = [NSDate date];
    [[self handlerWithService:service
                        store:store
             configurationURL:[NSURL URLWithString:@"https://example.com/config"]
                   appVersion:@"2.0"] currentConfiguration];
    NSDate *afterRequest = [NSDate date];

    XCTAssertEqual(service.requestCount, 1);
    XCTAssertEqual(store.fetchState.fetchFailureCount, 1);
    [self assertCooldownOfStore:store isBetween:7.5 * Minute and:15 * Minute since:beforeRequest until:afterRequest];
}

#pragma mark - Interrupted attempts

- (void)testInterruptedAttemptCountsAsFailureOnNextLaunch {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    [store setFetchStateWithAppVersion:@"1.0" failureCount:0 nextAllowedFetchAt:nil attemptInProgress:YES];
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    NSDate *beforeLaunch = [NSDate date];
    XCTAssertNil([[self enabledHandlerWithService:service store:store] currentConfiguration]);
    NSDate *afterLaunch = [NSDate date];

    XCTAssertEqual(service.requestCount, 0);
    XCTAssertEqual(store.fetchState.fetchFailureCount, 1);
    XCTAssertFalse(store.fetchState.attemptInProgress);
    [self assertCooldownOfStore:store isBetween:7.5 * Minute and:15 * Minute since:beforeLaunch until:afterLaunch];
}
- (void)testRepeatedlyInterruptedAttemptsBackOff {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    for (NSUInteger launch = 0; launch < 3; launch++) {
        // Each launch starts after the previous cooldown and dies before the fetch completes.
        BSGRemoteConfigFetchState *state = store.fetchState;
        [store setFetchStateWithAppVersion:@"1.0"
                              failureCount:state.fetchFailureCount
                        nextAllowedFetchAt:[NSDate dateWithTimeIntervalSinceNow:-1]
                         attemptInProgress:state.attemptInProgress];
        BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
        [[self enabledHandlerWithService:service store:store] currentConfiguration];
        XCTAssertEqual(service.requestCount, launch == 0 ? 1 : 0);
        if (launch > 0) {
            XCTAssertEqual(store.fetchState.fetchFailureCount, launch);
            // Simulate the cooldown elapsing and the next attempt being interrupted too.
            [store setFetchStateWithAppVersion:@"1.0"
                                  failureCount:store.fetchState.fetchFailureCount
                            nextAllowedFetchAt:nil
                             attemptInProgress:YES];
        }
    }
    XCTAssertGreaterThanOrEqual(store.fetchState.fetchFailureCount, 2);
}

#pragma mark - Persistence

- (void)testFetchStateJsonRoundTrip {
    BSGRemoteConfigFetchState *state = [BSGRemoteConfigFetchState new];
    state.appVersion = @"2.1";
    state.fetchFailureCount = 3;
    state.nextAllowedFetchAt = [NSDate dateWithTimeIntervalSince1970:1800000000];
    state.attemptInProgress = YES;

    BSGRemoteConfigFetchState *decoded = [BSGRemoteConfigFetchState stateFromJson:[state toJson]];
    XCTAssertEqualObjects(decoded.appVersion, @"2.1");
    XCTAssertEqual(decoded.fetchFailureCount, 3);
    XCTAssertEqualObjects(decoded.nextAllowedFetchAt, state.nextAllowedFetchAt);
    XCTAssertTrue(decoded.attemptInProgress);
}
- (void)testFetchStateIgnoresMalformedJson {
    XCTAssertNil([BSGRemoteConfigFetchState stateFromJson:nil]);
    BSGRemoteConfigFetchState *decoded = [BSGRemoteConfigFetchState stateFromJson:@{
        @"appVersion": @1,
        @"fetchFailureCount": @"three",
        @"nextAllowedFetchAt": @"tomorrow",
        @"attemptInProgress": @"yes",
    }];
    XCTAssertNil(decoded.appVersion);
    XCTAssertEqual(decoded.fetchFailureCount, 0);
    XCTAssertNil(decoded.nextAllowedFetchAt);
    XCTAssertFalse(decoded.attemptInProgress);
}
#pragma mark - First-fetch jitter

- (void)testFirstFetchJitterDefaultsToTenSecondsAndIsCopied {
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertEqual(configuration.remoteConfigFirstFetchJitter, 10);
    configuration.remoteConfigFirstFetchJitter = 3;
    XCTAssertEqual(((BugsnagConfiguration *)[configuration copy]).remoteConfigFirstFetchJitter, 3);
}
- (void)testFirstFetchIsDelayedWithinJitterWindow {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    service.response = BSGResponseWithType(BSGRemoteConfigServiceResponseTypeError);
    BSGRemoteConfigHandler *handler = [self jitteredHandlerWithService:service store:store firstFetchJitter:0.5];

    XCTAssertNil([handler currentConfiguration]);
    // The request has not started, so an app killed during the delay is not counted as a failed attempt.
    XCTAssertFalse(store.attemptWasPersistedBeforeRequest);
    [self waitFor:1.0];
    XCTAssertEqual(service.requestCount, 1);
    XCTAssertTrue(store.attemptWasPersistedBeforeRequest);
    XCTAssertEqual(store.fetchState.fetchFailureCount, 1);
}
- (void)testCacheMissesDuringFirstFetchDelayStartOnlyOneRequest {
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigHandler *handler = [self jitteredHandlerWithService:service
                                                                  store:[BSGInMemoryRemoteConfigStore new]
                                                       firstFetchJitter:0.3];
    dispatch_apply(100, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t __unused index) {
        [handler currentConfiguration];
    });
    [self waitFor:0.6];
    XCTAssertEqual(service.requestCount, 1);
}
- (void)testExpiredCachedConfigRefreshIsNotDelayed {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    store.configuration = [BSGRemoteConfiguration configFromJson:@{} eTag:@"expired-etag" expiryDate:[NSDate dateWithTimeIntervalSinceNow:-1]];
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    [[self jitteredHandlerWithService:service store:store firstFetchJitter:60] currentConfiguration];
    XCTAssertEqual(service.requestCount, 1);
    XCTAssertEqualObjects(service.currentTag, @"expired-etag");
}
- (void)testRetryAfterFailedFetchIsNotDelayed {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    [store setFetchStateWithAppVersion:@"1.0" failureCount:1 nextAllowedFetchAt:[NSDate dateWithTimeIntervalSinceNow:-1] attemptInProgress:NO];
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    [[self jitteredHandlerWithService:service store:store firstFetchJitter:60] currentConfiguration];
    XCTAssertEqual(service.requestCount, 1);
}

- (void)testLegacyCooldownPreferencesAreRemoved {
    [[NSUserDefaults standardUserDefaults] setObject:[NSDate dateWithTimeIntervalSinceNow:Hour]
                                              forKey:BSGLegacyRemoteConfigCooldownPreference];
    [[NSUserDefaults standardUserDefaults] setObject:@{@"configurationTag": @"old"}
                                              forKey:BSGLegacyRemoteConfigExpiryRefreshAttemptPreference];
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigHandler *handler = [self enabledHandlerWithService:service store:[BSGInMemoryRemoteConfigStore new]];
    [handler initialize];
    [self waitForInitialization];

    XCTAssertNil([[NSUserDefaults standardUserDefaults] objectForKey:BSGLegacyRemoteConfigCooldownPreference]);
    XCTAssertNil([[NSUserDefaults standardUserDefaults] objectForKey:BSGLegacyRemoteConfigExpiryRefreshAttemptPreference]);
    XCTAssertEqual(service.requestCount, 0);
}
@end

#pragma mark - Store persistence (real files)

@interface BSGRemoteConfigFetchStatePersistenceTests : XCTestCase
@property (nonatomic, strong) BSGRemoteConfigStore *store;
@end
@implementation BSGRemoteConfigFetchStatePersistenceTests

- (void)setUp {
    [super setUp];
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    configuration.appVersion = @"1.0";
    self.store = [BSGRemoteConfigStore storeWithLocations:[BSGFileLocations current] configuration:configuration];
    [self.store clearFetchState];
}
- (void)tearDown {
    [self.store clearFetchState];
    [super tearDown];
}
- (BSGRemoteConfigFetchState *)stateWithFailureCount:(NSUInteger)failureCount {
    BSGRemoteConfigFetchState *state = [BSGRemoteConfigFetchState new];
    state.appVersion = @"1.0";
    state.fetchFailureCount = failureCount;
    state.nextAllowedFetchAt = [NSDate dateWithTimeIntervalSince1970:1800000000];
    state.attemptInProgress = YES;
    return state;
}
- (void)testFetchStateIsWrittenToDiskAndReadBack {
    XCTAssertTrue([self.store saveFetchState:[self stateWithFailureCount:3]]);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[BSGFileLocations current].remoteConfigFetchState]);

    // A new store instance reads what the previous process wrote.
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    BSGRemoteConfigFetchState *loaded = [[BSGRemoteConfigStore storeWithLocations:[BSGFileLocations current]
                                                                    configuration:configuration] loadFetchState];
    XCTAssertEqualObjects(loaded.appVersion, @"1.0");
    XCTAssertEqual(loaded.fetchFailureCount, 3);
    XCTAssertEqualObjects(loaded.nextAllowedFetchAt, [NSDate dateWithTimeIntervalSince1970:1800000000]);
    XCTAssertTrue(loaded.attemptInProgress);
}
- (void)testFetchStateFileIsOutsideConfigCacheDirectory {
    NSString *fetchStatePath = [BSGFileLocations current].remoteConfigFetchState;
    NSString *cacheDirectory = [BSGFileLocations current].remoteConfigurations;
    XCTAssertFalse([fetchStatePath hasPrefix:[cacheDirectory stringByAppendingString:@"/"]]);
}
- (void)testClearingConfigCacheKeepsFetchState {
    [self.store saveFetchState:[self stateWithFailureCount:2]];
    [self.store clear];
    XCTAssertEqual([self.store loadFetchState].fetchFailureCount, 2);
}
- (void)testClearFetchStateRemovesFile {
    [self.store saveFetchState:[self stateWithFailureCount:1]];
    [self.store clearFetchState];
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:[BSGFileLocations current].remoteConfigFetchState]);
    XCTAssertNil([self.store loadFetchState]);
}
- (void)testCorruptFetchStateFileIsIgnored {
    [[@"not json" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:[BSGFileLocations current].remoteConfigFetchState
                                                            atomically:YES];
    XCTAssertNil([self.store loadFetchState]);
}
@end

#pragma mark - Service (mocked network)

@interface BSGRemoteConfigDataTaskMock : NSObject
@property (nonatomic, copy) dispatch_block_t onResume;
@end
@implementation BSGRemoteConfigDataTaskMock
- (void)resume { self.onResume(); }
@end

@interface BSGRemoteConfigSessionMock : NSObject
@property (nonatomic, strong) NSURLRequest *lastRequest;
@property (nonatomic) NSInteger statusCode;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *headers;
@property (nonatomic, strong) NSData *body;
/// When set, the request fails with this error and no HTTP response.
@property (nonatomic, strong) NSError *error;
@end
@implementation BSGRemoteConfigSessionMock
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    self.lastRequest = request;
    if (self.error) {
        BSGRemoteConfigDataTaskMock *task = [BSGRemoteConfigDataTaskMock new];
        task.onResume = ^{ completionHandler(nil, nil, self.error); };
        return (NSURLSessionDataTask *)task;
    }
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:request.URL
                                                              statusCode:self.statusCode
                                                             HTTPVersion:@"HTTP/1.1"
                                                            headerFields:self.headers];
    BSGRemoteConfigDataTaskMock *task = [BSGRemoteConfigDataTaskMock new];
    task.onResume = ^{ completionHandler(self.body, response, nil); };
    return (NSURLSessionDataTask *)task;
}
@end

@interface BSGRemoteConfigServiceTests : XCTestCase
@end
@implementation BSGRemoteConfigServiceTests

- (BSGRemoteConfigServiceResponse *)responseForSession:(BSGRemoteConfigSessionMock *)session tag:(NSString *)tag {
    return [self responseForSession:session tag:tag device:[BugsnagDevice new]];
}
- (BSGRemoteConfigServiceResponse *)responseForSession:(BSGRemoteConfigSessionMock *)session
                                                   tag:(NSString *)tag
                                                device:(BugsnagDevice *)device {
    BSGTestRemoteConfigConfiguration *configuration =
        [[BSGTestRemoteConfigConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    configuration.testConfigurationURL = [NSURL URLWithString:@"https://example.com/config"];
    BSGRemoteConfigService *service = [BSGRemoteConfigService serviceWithSession:(NSURLSession *)session
                                                                   configuration:configuration
                                                                        notifier:[BugsnagNotifier new]
                                                                          device:device
                                                                             app:[BugsnagApp new]];
    __block BSGRemoteConfigServiceResponse *result = nil;
    [service loadRemoteConfigWithCurrentTag:tag completion:^(BSGRemoteConfigServiceResponse *response) {
        result = response;
    }];
    return result;
}
- (void)testRequestUsesTimeoutAndConditionalHeader {
    BSGRemoteConfigSessionMock *session = [BSGRemoteConfigSessionMock new];
    session.statusCode = 304;
    session.headers = @{@"ETag": @"\"v1-xyz\""};
    BSGRemoteConfigServiceResponse *response = [self responseForSession:session tag:@"\"v1-xyz\""];

    XCTAssertEqual(session.lastRequest.timeoutInterval, 30);
    XCTAssertEqualObjects([session.lastRequest valueForHTTPHeaderField:@"If-None-Match"], @"\"v1-xyz\"");
    XCTAssertEqual(response.type, BSGRemoteConfigServiceResponseTypeNotModified);
    XCTAssertEqual(response.retryAfter, 0);
}
- (void)testRequestSendsDeviceIdHeader {
    BSGRemoteConfigSessionMock *session = [BSGRemoteConfigSessionMock new];
    session.statusCode = 200;
    BugsnagDevice *device = [BugsnagDevice new];
    device.id = @"5f0c"; // same dummy device ID as EventApiValidationTest
    [self responseForSession:session tag:nil device:device];
    XCTAssertEqualObjects([session.lastRequest valueForHTTPHeaderField:@"Bugsnag-Device-Id"], device.id);
}
- (void)testRequestOmitsDeviceIdHeaderWithoutDeviceId {
    for (NSString *deviceId in @[[NSNull null], @""]) {
        BSGRemoteConfigSessionMock *session = [BSGRemoteConfigSessionMock new];
        session.statusCode = 200;
        BugsnagDevice *device = [BugsnagDevice new];
        device.id = [deviceId isKindOfClass:[NSString class]] ? (NSString *)deviceId : nil;
        [self responseForSession:session tag:nil device:device];
        XCTAssertNil([session.lastRequest valueForHTTPHeaderField:@"Bugsnag-Device-Id"]);
    }
}
- (void)testRetryAfterSecondsIsReadFromFailedResponse {
    BSGRemoteConfigSessionMock *session = [BSGRemoteConfigSessionMock new];
    session.statusCode = 503;
    session.headers = @{@"Retry-After": @" 120 "};
    BSGRemoteConfigServiceResponse *response = [self responseForSession:session tag:nil];
    XCTAssertEqual(response.type, BSGRemoteConfigServiceResponseTypeError);
    XCTAssertEqual(response.retryAfter, 120);
}
- (void)testRetryAfterHeaderNameIsCaseInsensitive {
    BSGRemoteConfigSessionMock *session = [BSGRemoteConfigSessionMock new];
    session.statusCode = 429;
    session.headers = @{@"retry-after": @"60"};
    XCTAssertEqual([self responseForSession:session tag:nil].retryAfter, 60);
}
- (void)testRetryAfterIgnoresHTTPDateAndInvalidValues {
    for (NSString *value in @[@"Wed, 21 Oct 2026 07:28:00 GMT", @"-5", @"0", @"abc", @"10s"]) {
        BSGRemoteConfigSessionMock *session = [BSGRemoteConfigSessionMock new];
        session.statusCode = 503;
        session.headers = @{@"Retry-After": value};
        XCTAssertEqual([self responseForSession:session tag:nil].retryAfter, 0, @"%@", value);
    }
}
- (void)testOfflineErrorsAreReportedAsNetworkUnavailable {
    for (NSNumber *code in @[@(NSURLErrorNotConnectedToInternet), @(NSURLErrorInternationalRoamingOff), @(NSURLErrorDataNotAllowed)]) {
        BSGRemoteConfigSessionMock *session = [BSGRemoteConfigSessionMock new];
        session.error = [NSError errorWithDomain:NSURLErrorDomain code:code.integerValue userInfo:nil];
        BSGRemoteConfigServiceResponse *response = [self responseForSession:session tag:nil];
        XCTAssertEqual(response.type, BSGRemoteConfigServiceResponseTypeError, @"%@", code);
        XCTAssertTrue(response.networkUnavailable, @"%@", code);
    }
}
- (void)testTimeoutAndServerUnreachableAreFailures {
    for (NSNumber *code in @[@(NSURLErrorTimedOut), @(NSURLErrorCannotConnectToHost), @(NSURLErrorNetworkConnectionLost)]) {
        BSGRemoteConfigSessionMock *session = [BSGRemoteConfigSessionMock new];
        session.error = [NSError errorWithDomain:NSURLErrorDomain code:code.integerValue userInfo:nil];
        BSGRemoteConfigServiceResponse *response = [self responseForSession:session tag:nil];
        XCTAssertEqual(response.type, BSGRemoteConfigServiceResponseTypeError, @"%@", code);
        XCTAssertFalse(response.networkUnavailable, @"%@", code);
    }
}
- (void)testClientErrorIsReportedAsFailure {
    BSGRemoteConfigSessionMock *session = [BSGRemoteConfigSessionMock new];
    session.statusCode = 404;
    XCTAssertEqual([self responseForSession:session tag:nil].type, BSGRemoteConfigServiceResponseTypeError);
}
- (void)testJitteredLifetimeShortensByUpToTenPercent {
    XCTAssertEqualWithAccuracy([BSGRemoteConfigService jitteredLifetime:1000 randomFraction:0], 1000, 0.001);
    XCTAssertEqualWithAccuracy([BSGRemoteConfigService jitteredLifetime:1000 randomFraction:0.5], 950, 0.001);
    XCTAssertEqualWithAccuracy([BSGRemoteConfigService jitteredLifetime:1000 randomFraction:1], 900, 0.001);
    XCTAssertEqualWithAccuracy([BSGRemoteConfigService jitteredLifetime:1000 randomFraction:-1], 1000, 0.001);
    XCTAssertEqualWithAccuracy([BSGRemoteConfigService jitteredLifetime:1000 randomFraction:2], 900, 0.001);
}
- (void)testMaxAgeExpiryIsJitteredWithinTenPercent {
    NSMutableSet *lifetimes = [NSMutableSet set];
    for (int i = 0; i < 20; i++) {
        BSGRemoteConfigSessionMock *session = [BSGRemoteConfigSessionMock new];
        session.statusCode = 200;
        session.headers = @{@"ETag": @"\"v1\"", @"Cache-Control": @"max-age=86400"};
        NSDate *before = [NSDate date];
        BSGRemoteConfigServiceResponse *response = [self responseForSession:session tag:nil];
        NSTimeInterval lifetime = [response.configuration.expiryDate timeIntervalSinceDate:before];
        XCTAssertGreaterThanOrEqual(lifetime, 86400 * 0.9 - 1);
        XCTAssertLessThanOrEqual(lifetime, 86400 + 1);
        [lifetimes addObject:@((NSInteger)lifetime)];
    }
    // Devices fetching at the same moment should not all expire at the same moment.
    XCTAssertGreaterThan(lifetimes.count, 1);
}
- (void)testNotModifiedExpiryIsJittered {
    BSGRemoteConfigSessionMock *session = [BSGRemoteConfigSessionMock new];
    session.statusCode = 304;
    session.headers = @{@"ETag": @"\"v1\"", @"Cache-Control": @"max-age=1000"};
    NSDate *before = [NSDate date];
    NSTimeInterval lifetime = [[self responseForSession:session tag:@"\"v1\""].expiryDate timeIntervalSinceDate:before];
    XCTAssertGreaterThanOrEqual(lifetime, 900 - 1);
    XCTAssertLessThanOrEqual(lifetime, 1000 + 1);
}
- (void)testDefaultExpiryWithoutMaxAgeIsJittered {
    BSGRemoteConfigSessionMock *session = [BSGRemoteConfigSessionMock new];
    session.statusCode = 200;
    session.headers = @{@"ETag": @"\"v1\""};
    NSDate *before = [NSDate date];
    NSTimeInterval lifetime = [[self responseForSession:session tag:nil].configuration.expiryDate timeIntervalSinceDate:before];
    NSTimeInterval defaultLifetime = 86400 + 7200;
    XCTAssertGreaterThanOrEqual(lifetime, defaultLifetime * 0.9 - 1);
    XCTAssertLessThanOrEqual(lifetime, defaultLifetime + 1);
}
- (void)testEmptySuccessBodyIsValidEmptyConfig {
    BSGRemoteConfigSessionMock *session = [BSGRemoteConfigSessionMock new];
    session.statusCode = 200;
    session.headers = @{@"ETag": @"\"empty\"", @"Cache-Control": @"max-age=60"};
    BSGRemoteConfigServiceResponse *response = [self responseForSession:session tag:nil];
    XCTAssertEqual(response.type, BSGRemoteConfigServiceResponseTypeSuccess);
    XCTAssertEqual(response.configuration.discardRules.count, 0);
}
@end
