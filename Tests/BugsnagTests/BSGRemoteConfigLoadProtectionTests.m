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

static NSString * const BSGRemoteConfigCooldownPreference = @"com.bugsnag.remote-config.cooldown-until";
static NSString * const BSGRemoteConfigExpiryRefreshAttemptPreference = @"com.bugsnag.remote-config.expiry-refresh-attempt";

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
@end
@implementation BSGRecordingRemoteConfigService
- (void)loadRemoteConfigWithCurrentTag:(NSString *)tag completion:(BSGRemoteConfigServiceCompletion)completion {
    self.requestCount++;
    self.currentTag = tag;
    if (self.response) { completion(self.response); }
}
@end

@interface BSGInMemoryRemoteConfigStore : BSGRemoteConfigStore
@property (nonatomic, strong) BSGRemoteConfiguration *configuration;
@property (nonatomic) BOOL shouldFailSave;
@property (nonatomic) BOOL shouldFailExpiryUpdate;
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
@end

@interface BSGRemoteConfigLoadProtectionTests : XCTestCase
@end
@implementation BSGRemoteConfigLoadProtectionTests

- (void)setUp {
    [super setUp];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:BSGRemoteConfigCooldownPreference];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:BSGRemoteConfigExpiryRefreshAttemptPreference];
}
- (void)tearDown {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:BSGRemoteConfigCooldownPreference];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:BSGRemoteConfigExpiryRefreshAttemptPreference];
    [super tearDown];
}
- (BSGRemoteConfigHandler *)handlerWithService:(BSGRecordingRemoteConfigService *)service
                                         store:(BSGInMemoryRemoteConfigStore *)store
                              configurationURL:(NSURL *)configurationURL {
    BSGTestRemoteConfigConfiguration *configuration =
        [[BSGTestRemoteConfigConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    configuration.testConfigurationURL = configurationURL;
    return [BSGRemoteConfigHandler handlerWithService:service store:store configuration:configuration];
}
- (BSGRemoteConfigHandler *)enabledHandlerWithService:(BSGRecordingRemoteConfigService *)service
                                                 store:(BSGInMemoryRemoteConfigStore *)store {
    return [self handlerWithService:service store:store configurationURL:[NSURL URLWithString:@"https://example.com/config"]];
}
- (void)testInitializeAndStartDoNotFetchRemoteConfig {
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigHandler *handler = [self enabledHandlerWithService:service store:[BSGInMemoryRemoteConfigStore new]];
    [handler initialize]; [handler start];
    XCTestExpectation *expectation = [self expectationWithDescription:@"initialization completed"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [expectation fulfill]; });
    [self waitForExpectations:@[expectation] timeout:1];
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
- (void)testCacheMissFetchesOnlyOnceDuringPersistedCooldown {
    BSGRecordingRemoteConfigService *firstService = [BSGRecordingRemoteConfigService new];
    [[self enabledHandlerWithService:firstService store:[BSGInMemoryRemoteConfigStore new]] currentConfiguration];
    XCTAssertEqual(firstService.requestCount, 1);
    BSGRecordingRemoteConfigService *secondService = [BSGRecordingRemoteConfigService new];
    [[self enabledHandlerWithService:secondService store:[BSGInMemoryRemoteConfigStore new]] currentConfiguration];
    XCTAssertEqual(secondService.requestCount, 0);
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
- (void)testPersistedCooldownUsesPlusOrMinusTwoHourJitter {
    NSDate *beforeRequest = [NSDate date];
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    [[self enabledHandlerWithService:service store:[BSGInMemoryRemoteConfigStore new]] currentConfiguration];
    NSDate *afterRequest = [NSDate date];
    NSDate *cooldownUntil = [[NSUserDefaults standardUserDefaults]
        objectForKey:BSGRemoteConfigCooldownPreference];

    XCTAssertEqual(service.requestCount, 1);
    XCTAssertGreaterThanOrEqual([cooldownUntil timeIntervalSinceDate:beforeRequest],
                                22 * 60 * 60);
    XCTAssertLessThanOrEqual([cooldownUntil timeIntervalSinceDate:afterRequest],
                             26 * 60 * 60);
}
- (void)testExpiredConfigUsesCachedETagFor304Revalidation {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    store.configuration = [BSGRemoteConfiguration configFromJson:@{} eTag:@"cached-etag" expiryDate:[NSDate dateWithTimeIntervalSinceNow:-1]];
    [[NSUserDefaults standardUserDefaults] setObject:[NSDate dateWithTimeIntervalSinceNow:60]
                                              forKey:BSGRemoteConfigCooldownPreference];
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigServiceResponse *response = [BSGRemoteConfigServiceResponse new];
    response.type = BSGRemoteConfigServiceResponseTypeNotModified; response.configurationTag = @"cached-etag";
    response.expiryDate = [NSDate dateWithTimeIntervalSinceNow:60]; service.response = response;
    BSGRemoteConfigHandler *handler = [self enabledHandlerWithService:service store:store];
    NSDate *beforeRequest = [NSDate date];
    XCTAssertEqual([handler currentConfiguration], store.configuration);
    NSDate *afterRequest = [NSDate date];
    NSDate *cooldownUntil = [[NSUserDefaults standardUserDefaults]
        objectForKey:BSGRemoteConfigCooldownPreference];
    XCTAssertEqualObjects(service.currentTag, @"cached-etag");
    XCTAssertTrue([handler hasValidConfig]);
    XCTAssertGreaterThanOrEqual([cooldownUntil timeIntervalSinceDate:beforeRequest],
                                22 * 60 * 60);
    XCTAssertLessThanOrEqual([cooldownUntil timeIntervalSinceDate:afterRequest],
                             26 * 60 * 60);
}
- (void)test304RevalidationRetainsDiscardRules {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    store.configuration = [BSGRemoteConfiguration configFromJson:@{
        @"discardRules": @[@{@"matchType": @"ALL"}],
    } eTag:@"cached-etag" expiryDate:[NSDate dateWithTimeIntervalSinceNow:-1]];
    [[NSUserDefaults standardUserDefaults] setObject:[NSDate dateWithTimeIntervalSinceNow:60]
                                              forKey:BSGRemoteConfigCooldownPreference];

    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigServiceResponse *response = [BSGRemoteConfigServiceResponse new];
    response.type = BSGRemoteConfigServiceResponseTypeNotModified;
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
- (void)testFailedExpiredConfigRefreshUsesPersistedCooldown {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    store.configuration = [BSGRemoteConfiguration configFromJson:@{} eTag:@"expired-etag" expiryDate:[NSDate dateWithTimeIntervalSinceNow:-1]];
    [[NSUserDefaults standardUserDefaults] setObject:[NSDate dateWithTimeIntervalSinceNow:60]
                                              forKey:BSGRemoteConfigCooldownPreference];

    BSGRecordingRemoteConfigService *firstService = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigServiceResponse *response = [BSGRemoteConfigServiceResponse new];
    response.type = BSGRemoteConfigServiceResponseTypeError;
    firstService.response = response;
    BSGRemoteConfigHandler *firstHandler = [self enabledHandlerWithService:firstService store:store];
    XCTAssertNil([firstHandler currentConfiguration]);
    XCTAssertEqual(firstService.requestCount, 1);

    BSGRecordingRemoteConfigService *secondService = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigHandler *secondHandler = [self enabledHandlerWithService:secondService store:store];
    XCTAssertNil([secondHandler currentConfiguration]);
    XCTAssertEqual(secondService.requestCount, 0);
}
- (void)testNonDurable304RefreshUsesPersistedCooldown {
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    store.configuration = [BSGRemoteConfiguration configFromJson:@{} eTag:@"expired-etag" expiryDate:[NSDate dateWithTimeIntervalSinceNow:-1]];
    store.shouldFailExpiryUpdate = YES;
    [[NSUserDefaults standardUserDefaults] setObject:[NSDate dateWithTimeIntervalSinceNow:60]
                                              forKey:BSGRemoteConfigCooldownPreference];

    BSGRecordingRemoteConfigService *firstService = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigServiceResponse *response = [BSGRemoteConfigServiceResponse new];
    response.type = BSGRemoteConfigServiceResponseTypeNotModified;
    response.configurationTag = @"expired-etag";
    response.expiryDate = [NSDate dateWithTimeIntervalSinceNow:60];
    firstService.response = response;
    BSGRemoteConfigHandler *firstHandler = [self enabledHandlerWithService:firstService store:store];
    XCTAssertNil([firstHandler currentConfiguration]);
    XCTAssertEqual(firstService.requestCount, 1);

    BSGRecordingRemoteConfigService *secondService = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigHandler *secondHandler = [self enabledHandlerWithService:secondService store:store];
    XCTAssertNil([secondHandler currentConfiguration]);
    XCTAssertEqual(secondService.requestCount, 0);
}
- (void)testEmptyConfigResponseIsStoredAsValidConfig {
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigServiceResponse *response = [BSGRemoteConfigServiceResponse new];
    response.type = BSGRemoteConfigServiceResponseTypeSuccess;
    response.configuration = [BSGRemoteConfiguration configFromJson:@{} eTag:@"empty-etag" expiryDate:[NSDate dateWithTimeIntervalSinceNow:60]];
    service.response = response;
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    BSGRemoteConfigHandler *handler = [self enabledHandlerWithService:service store:store];
    XCTAssertEqual([handler currentConfiguration], store.configuration);
    XCTAssertEqual(store.configuration.discardRules.count, 0);
    XCTAssertTrue([handler hasValidConfig]);
}
- (void)testValidConfigRemainsActiveWhenPersistenceFails {
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigServiceResponse *response = [BSGRemoteConfigServiceResponse new];
    response.type = BSGRemoteConfigServiceResponseTypeSuccess;
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
}
- (void)testInvalidConfigResponseIsNotActivatedWhenPersistenceFails {
    BSGRecordingRemoteConfigService *service = [BSGRecordingRemoteConfigService new];
    BSGRemoteConfigServiceResponse *response = [BSGRemoteConfigServiceResponse new];
    response.type = BSGRemoteConfigServiceResponseTypeSuccess;
    service.response = response;
    BSGInMemoryRemoteConfigStore *store = [BSGInMemoryRemoteConfigStore new];
    store.shouldFailSave = YES;
    BSGRemoteConfigHandler *handler = [self enabledHandlerWithService:service store:store];

    XCTAssertNil([handler currentConfiguration]);
    XCTAssertNil(store.configuration);
    XCTAssertFalse([handler hasValidConfig]);
}
@end
