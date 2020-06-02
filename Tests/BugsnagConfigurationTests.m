/**
 * Unit test the BugsnagConfiguration class
 */

#import <XCTest/XCTest.h>

#import "BugsnagTestConstants.h"
#import "Bugsnag.h"
#import "BugsnagConfiguration.h"
#import "BugsnagCrashSentry.h"
#import "BugsnagKeys.h"
#import "BugsnagSessionTracker.h"
#import "BugsnagUser.h"
#import "BSG_KSCrashType.h"

// =============================================================================
// MARK: - Required private methods
// =============================================================================

@interface BugsnagConfiguration ()
@property(nonatomic, readwrite, strong) NSMutableArray *onSendBlocks;
@property(nonatomic, readwrite, strong) NSMutableArray *onSessionBlocks;
@property(readonly, retain, nullable) NSURL *sessionURL;
@property(readonly, retain, nullable) NSURL *notifyURL;
- (void)deletePersistedUserData;
- (BOOL)shouldSendReports;
- (NSDictionary *_Nonnull)errorApiHeaders;
- (NSDictionary *_Nonnull)sessionApiHeaders;
@end

@interface BugsnagCrashSentry ()
- (BSG_KSCrashType)mapKSToBSGCrashTypes:(BugsnagErrorTypes *)errorTypes;
@end

@interface BugsnagClient ()
- (void)start;
@end

// =============================================================================
// MARK: - Tests
// =============================================================================

@interface BugsnagConfigurationTests : XCTestCase
@end

@implementation BugsnagConfigurationTests

// =============================================================================
// MARK: - Session-related
// =============================================================================

- (void)testDefaultSessionNotNil {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertNotNil(config.session);
}

- (void)testDefaultSessionConfig {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertTrue([config autoTrackSessions]);
}

- (void)testSessionApiHeaders {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    NSDictionary *headers = [config sessionApiHeaders];
    XCTAssertEqualObjects(config.apiKey, headers[@"Bugsnag-Api-Key"]);
    XCTAssertNotNil(headers[@"Bugsnag-Sent-At"]);
    XCTAssertNotNil(headers[@"Bugsnag-Payload-Version"]);
}

- (void)testSessionEndpoints {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];

    // Default endpoints
    XCTAssertEqualObjects([NSURL URLWithString:@"https://sessions.bugsnag.com"], config.sessionURL);

    // Test overriding the session endpoint (use dummy endpoints to avoid hitting production)

    config.endpoints = [[BugsnagEndpointConfiguration alloc] initWithNotify:@"http://localhost:1234"
                                                                   sessions:@"http://localhost:8000"];
    XCTAssertEqualObjects([NSURL URLWithString:@"http://localhost:8000"], config.sessionURL);
}

- (void)testSetEmptySessionsEndpoint {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.endpoints = [[BugsnagEndpointConfiguration alloc] initWithNotify:@"http://notify.example.com"
                                                                   sessions:@""];
    BugsnagSessionTracker *sessionTracker
            = [[BugsnagSessionTracker alloc] initWithConfig:config client:nil postRecordCallback:nil];

    XCTAssertNil(sessionTracker.runningSession);
    [sessionTracker startNewSession];
    XCTAssertNil(sessionTracker.runningSession);
}

- (void)testSetMalformedSessionsEndpoint {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.endpoints = [[BugsnagEndpointConfiguration alloc] initWithNotify:@"http://notify.example.com"
                                                                   sessions:@"f"];
    BugsnagSessionTracker *sessionTracker
            = [[BugsnagSessionTracker alloc] initWithConfig:config client:nil postRecordCallback:nil];

    XCTAssertNil(sessionTracker.runningSession);
    [sessionTracker startNewSession];
    XCTAssertNil(sessionTracker.runningSession);
}

/**
 * Test that onSession blocks get called once added
 */
- (void)testAddOnSessionBlock {

    // Setup
    __block XCTestExpectation *expectation = [self expectationWithDescription:@"Remove On Session Block"];
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.endpoints = [[BugsnagEndpointConfiguration alloc] initWithNotify:@"http://notreal.bugsnag.com"
                                                                   sessions:@"http://notreal.bugsnag.com"];
    XCTAssertEqual([[config onSessionBlocks] count], 0);
    BugsnagOnSessionBlock sessionBlock = ^BOOL(BugsnagSession * _Nonnull sessionPayload) {
        // We expect the session block to be called
        [expectation fulfill];
        return true;
    };
    [config addOnSessionBlock:sessionBlock];
    XCTAssertEqual([[config onSessionBlocks] count], 1);

    // Call onSession blocks
    BugsnagClient *client = [[BugsnagClient alloc] initWithConfiguration:config];
    [client start];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

/**
 * Test that onSession blocks do not get called once they've been removed
 */
- (void)testRemoveOnSessionBlock {
    // Setup
    // We expect NOT to be called
    __block XCTestExpectation *calledExpectation = [self expectationWithDescription:@"Remove On Session Block"];
    calledExpectation.inverted = YES;

    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.endpoints = [[BugsnagEndpointConfiguration alloc] initWithNotify:@"http://notreal.bugsnag.com"
                                                                   sessions:@"http://notreal.bugsnag.com"];
    XCTAssertEqual([[config onSessionBlocks] count], 0);
    BugsnagOnSessionBlock sessionBlock = ^BOOL(BugsnagSession * _Nonnull sessionPayload) {
        [calledExpectation fulfill];
        return true;
    };

    // It's there (and from other tests we know it gets called) and then it's not there
    [config addOnSessionBlock:sessionBlock];
    XCTAssertEqual([[config onSessionBlocks] count], 1);
    [config removeOnSessionBlock:sessionBlock];
    XCTAssertEqual([[config onSessionBlocks] count], 0);

    BugsnagClient *client = [[BugsnagClient alloc] initWithConfiguration:config];
    [client start];

    // Wait a second NOT to be called
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}
/**
 * Test that an onSession block is called after being added, then NOT called after being removed.
 * This test could be expanded to verify the behaviour when multiple blocks are added.
 */
- (void)testAddOnSessionBlockThenRemove {

    __block int called = 0; // A counter

    // Setup
    __block XCTestExpectation *expectation1 = [self expectationWithDescription:@"Remove On Session Block 1"];
    __block XCTestExpectation *expectation2 = [self expectationWithDescription:@"Remove On Session Block 2"];
    __block XCTestExpectation *expectation3 = [self expectationWithDescription:@"Remove On Session Block 3"];
    __block XCTestExpectation *expectation4 = [self expectationWithDescription:@"Remove On Session Block 4"];
    expectation3.inverted = YES;
    expectation4.inverted = YES;

    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.endpoints = [[BugsnagEndpointConfiguration alloc] initWithNotify:@"http://notreal.bugsnag.com"
                                                                   sessions:@"http://notreal.bugsnag.com"];
    XCTAssertEqual([[config onSessionBlocks] count], 0);

    BugsnagOnSessionBlock sessionBlock = ^BOOL(BugsnagSession * _Nonnull sessionPayload) {
        switch (called) {
        case 0:
            [expectation1 fulfill];
            break;
        case 1:
            [expectation2 fulfill];
            break;
        case 2:
            // Should NOT be called
            [expectation3 fulfill];
            break;
        case 3:
            // Should NOT be called
            [expectation4 fulfill];
            break;
        }
        return true;
    };

    [config addOnSessionBlock:sessionBlock];
    XCTAssertEqual([[config onSessionBlocks] count], 1);

    // Call onSession blocks
    BugsnagClient *client = [[BugsnagClient alloc] initWithConfiguration:config];
    [client start];
    [self waitForExpectations:@[expectation1] timeout:1.0];

    // Check it's called on new session start
    [client pauseSession];
    called++;
    [client startSession];
    [self waitForExpectations:@[expectation2] timeout:1.0];

    // Check block is not called after removing and initialisation
    [client pauseSession];
    called++;
    [config removeOnSessionBlock:sessionBlock];
    [client startSession];
    [self waitForExpectations:@[expectation3] timeout:1.0];

    // Check it's NOT called on session resume
    [client pauseSession];
    called++;
    [config addOnSessionBlock:sessionBlock];
    [client resumeSession];
    [self waitForExpectations:@[expectation4] timeout:1.0];
}

/**
 * Make sure slightly invalid removals and duplicate additions don't break things
 */
- (void)testRemoveNonexistentOnSessionBlocks {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertEqual([[config onSessionBlocks] count], 0);
    BugsnagOnSessionBlock sessionBlock1 = ^BOOL(BugsnagSession * _Nonnull sessionPayload) { return true; };
    BugsnagOnSessionBlock sessionBlock2 = ^BOOL(BugsnagSession * _Nonnull sessionPayload) { return true; };

    [config addOnSessionBlock:sessionBlock1];
    XCTAssertEqual([[config onSessionBlocks] count], 1);
    [config removeOnSessionBlock:sessionBlock2];
    XCTAssertEqual([[config onSessionBlocks] count], 1);
    [config removeOnSessionBlock:sessionBlock1];
    XCTAssertEqual([[config onSessionBlocks] count], 0);
    [config removeOnSessionBlock:sessionBlock2];
    XCTAssertEqual([[config onSessionBlocks] count], 0);
    [config removeOnSessionBlock:sessionBlock1];
    XCTAssertEqual([[config onSessionBlocks] count], 0);

    [config addOnSessionBlock:sessionBlock1];
    XCTAssertEqual([[config onSessionBlocks] count], 1);
    [config addOnSessionBlock:sessionBlock1];
    XCTAssertEqual([[config onSessionBlocks] count], 2);
    [config addOnSessionBlock:sessionBlock1];
    XCTAssertEqual([[config onSessionBlocks] count], 3);
}

// =============================================================================
// MARK: - Release stage-related
// =============================================================================

- (void)testEnabledReleaseStagesDefaultSends {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertTrue([config shouldSendReports]);
}

- (void)testEnabledReleaseStagesNilSends {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.releaseStage = @"beta";
    config.enabledReleaseStages = nil;
    XCTAssertTrue([config shouldSendReports]);
}

- (void)testEnabledReleaseStagesEmptySends {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.releaseStage = @"beta";
    config.enabledReleaseStages = [NSSet setWithArray:@[]];
    XCTAssertTrue([config shouldSendReports]);
}

- (void)testEnabledReleaseStagesIncludedSends {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.releaseStage = @"beta";
    config.enabledReleaseStages = [NSSet setWithArray:@[ @"beta" ]];
    XCTAssertTrue([config shouldSendReports]);
}

- (void)testEnabledReleaseStagesIncludedInManySends {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.releaseStage = @"beta";
    config.enabledReleaseStages = [NSSet setWithArray:@[ @"beta", @"production" ]];
    XCTAssertTrue([config shouldSendReports]);
}

- (void)testEnabledReleaseStagesExcludedSkipsSending {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.releaseStage = @"beta";
    config.enabledReleaseStages = [NSSet setWithArray:@[ @"production" ]];
    XCTAssertFalse([config shouldSendReports]);
}

// =============================================================================
// MARK: - Endpoint-related
// =============================================================================

- (void)testNotifyEndpoint {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertEqualObjects([NSURL URLWithString:@"https://notify.bugsnag.com/"], config.notifyURL);

    // Test overriding the notify endpoint (use dummy endpoints to avoid hitting production)
    config.endpoints = [[BugsnagEndpointConfiguration alloc] initWithNotify:@"http://localhost:1234"
                                                                   sessions:@"http://localhost:8000"];
    XCTAssertEqualObjects([NSURL URLWithString:@"http://localhost:1234"], config.notifyURL);
}

- (void)testSetEndpoints {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.endpoints = [[BugsnagEndpointConfiguration alloc] initWithNotify:@"http://notify.example.com"
                                                                   sessions:@"http://sessions.example.com"];
    XCTAssertEqualObjects([NSURL URLWithString:@"http://notify.example.com"], config.notifyURL);
    XCTAssertEqualObjects([NSURL URLWithString:@"http://sessions.example.com"], config.sessionURL);
}

// in debug these throw exceptions though in release are "tolerated"
- (void)testSetNilNotifyEndpoint {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    NSString *notify = @"foo";
    notify = nil;
#if DEBUG
    XCTAssertThrowsSpecificNamed([config setEndpoints:[[BugsnagEndpointConfiguration alloc] initWithNotify:notify
                                                                                                  sessions:@"http://sessions.example.com"]],
            NSException, NSInternalInconsistencyException);
#else
    XCTAssertNoThrow([config setEndpoints:[[BugsnagEndpointConfiguration alloc] initWithNotify:@""
                                                                                                  sessions:@"http://sessions.example.com"]]);
#endif
}

// in debug these throw exceptions though in release are "tolerated"
- (void)testSetEmptyNotifyEndpoint {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
#if DEBUG
    XCTAssertThrowsSpecificNamed([config setEndpoints:[[BugsnagEndpointConfiguration alloc] initWithNotify:@""
            sessions:@"http://sessions.example.com"]],
            NSException, NSInternalInconsistencyException);
#else
    XCTAssertNoThrow([config setEndpoints:[[BugsnagEndpointConfiguration alloc] initWithNotify:@""
            sessions:@"http://sessions.example.com"]]);
#endif
}

// in debug these throw exceptions though in release are "tolerated"
- (void)testSetMalformedNotifyEndpoint {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
#if DEBUG
    XCTAssertThrowsSpecificNamed([config setEndpoints:[[BugsnagEndpointConfiguration alloc] initWithNotify:@"http://"
                                                                                                  sessions:@"http://sessions.example.com"]],
            NSException, NSInternalInconsistencyException);
#else
    XCTAssertNoThrow([config setEndpoints:[[BugsnagEndpointConfiguration alloc] initWithNotify:@"http://"
            sessions:@"http://sessions.example.com"]]);
#endif
}

// =============================================================================
// MARK: - User persistence tests
// =============================================================================

NSString * const kBugsnagUserEmailAddress = @"BugsnagUserEmailAddress";
NSString * const kBugsnagUserName = @"BugsnagUserName";
NSString * const kBugsnagUserUserId = @"BugsnagUserUserId";

// Helper
- (void)getName:(NSString **)name email:(NSString **)email id:(NSString **  )id {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    *email = [userDefaults objectForKey:kBugsnagUserEmailAddress];
    *id = [userDefaults objectForKey:kBugsnagUserUserId];
    *name = [userDefaults objectForKey:kBugsnagUserName];
}

- (void)testUserPersistence {
    NSString *userDefaultEmail, *userDefaultName, *userDefaultUserId;
    NSString *email  = @"test@example.com";
    NSString *name   = @"foo";
    NSString *userId = @"123";

    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];

    // Check property defaults to True
    XCTAssertTrue(config.persistUser);

    // Start with no persisted user data
    [config deletePersistedUserData];
    [self getName:&userDefaultName email:&userDefaultEmail id:&userDefaultUserId];
    XCTAssertNil(userDefaultEmail);
    XCTAssertNil(userDefaultName);
    XCTAssertNil(userDefaultUserId);

    // user should be persisted by default
    [config setUser:userId withEmail:email andName:name];

    // Check values manually
    [self getName:&userDefaultName email:&userDefaultEmail id:&userDefaultUserId];
    XCTAssertEqualObjects(userDefaultEmail, email);
    XCTAssertEqualObjects(userDefaultName, name);
    XCTAssertEqualObjects(userDefaultUserId, userId);

    // Check persistence between invocations (when values have been set)
    BugsnagConfiguration *config2 = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertEqualObjects(config2.user.email, email);
    XCTAssertEqualObjects(config2.user.name, name);
    XCTAssertEqualObjects(config2.user.id, userId);

    // Check that values we know to have been persisted are actuallty deleted.
    [config2 deletePersistedUserData];
    [self getName:&userDefaultName email:&userDefaultEmail id:&userDefaultUserId];
    XCTAssertNil(userDefaultEmail);
    XCTAssertNil(userDefaultName);
    XCTAssertNil(userDefaultUserId);
}

/**
 * Test that user data is (as far as we can tell) not persisted
 */
- (void)testUserNonPesistence {
    NSString *userDefaultEmail, *userDefaultName, *userDefaultUserId;

    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.persistUser = false;
    [config deletePersistedUserData];

    // Should be no persisted data, and should not persist between invocations
    [config deletePersistedUserData];
    [self getName:&userDefaultName email:&userDefaultEmail id:&userDefaultUserId];
    XCTAssertNil(userDefaultEmail);
    XCTAssertNil(userDefaultName);
    XCTAssertNil(userDefaultUserId);

    BugsnagConfiguration *config2 = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertNotNil(config2.user);
    XCTAssertNil(config2.user.id);
    XCTAssertNil(config2.user.name);
    XCTAssertNil(config2.user.email);
}

/**
 * Test partial parsistence
 */

- (void)testPartialPesistence {
    NSString *userDefaultEmail, *userDefaultName, *userDefaultUserId;
    [self getName:&userDefaultName email:&userDefaultEmail id:&userDefaultUserId];
    
    NSString *email  = @"test@example.com";
    NSString *name   = @"foo";
    NSString *userId = @"123";
    
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertTrue(config.persistUser);
    [config deletePersistedUserData];

    // Should be no persisted data
    [config deletePersistedUserData];
    [self getName:&userDefaultName email:&userDefaultEmail id:&userDefaultUserId];
    XCTAssertNil(userDefaultEmail);
    XCTAssertNil(userDefaultName);
    XCTAssertNil(userDefaultUserId);
    
    [config setUser:userId withEmail:nil andName:nil];
    [self getName:&userDefaultName email:&userDefaultEmail id:&userDefaultUserId];
    XCTAssertNil(userDefaultEmail);
    XCTAssertNil(userDefaultName);
    XCTAssertEqualObjects(userDefaultUserId, userId);
    
    [config setUser:nil withEmail:email andName:nil];
    [self getName:&userDefaultName email:&userDefaultEmail id:&userDefaultUserId];
    XCTAssertNil(userDefaultName);
    XCTAssertEqualObjects(userDefaultEmail, email);
    XCTAssertNil(userDefaultUserId);

    [config setUser:nil withEmail:nil andName:name];
    [self getName:&userDefaultName email:&userDefaultEmail id:&userDefaultUserId];
    XCTAssertEqualObjects(userDefaultName, name);
    XCTAssertNil(userDefaultEmail);
    XCTAssertNil(userDefaultUserId);
}

/**
 * Test that persisting a BugsnagUser with all nil fields behaves as expected
 */
- (void)testAllUserDataNilPersistence {
    NSString *userDefaultEmail, *userDefaultName, *userDefaultUserId;
    
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertTrue(config.persistUser);
    [config deletePersistedUserData];

    [config setUser:nil withEmail:nil andName:nil];

    // currentUser should have been set
    XCTAssertNotNil(config.user);

    // But there hould be no persisted data
    [self getName:&userDefaultName email:&userDefaultEmail id:&userDefaultUserId];
    XCTAssertNil(userDefaultName);
    XCTAssertNil(userDefaultEmail);
    XCTAssertNil(userDefaultUserId);
}

/**
 * Test that the configuration metadata is set correctly.
 */
- (void)testUserPersistenceAndMetadata {
    NSString *userDefaultEmail, *userDefaultName, *userDefaultUserId;
    NSString *email  = @"test@example.com";
    NSString *name   = @"foo";
    NSString *userId = @"123";

    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertTrue(config.persistUser);
    [config deletePersistedUserData];

    // Should be no persisted data
    [self getName:&userDefaultName email:&userDefaultEmail id:&userDefaultUserId];
    XCTAssertNil(userDefaultName);
    XCTAssertNil(userDefaultEmail);
    XCTAssertNil(userDefaultUserId);

    // Persist user data
    [config setUser:userId withEmail:email andName:name];

    // Check that retrieving persisted user data also sets configuration metadata
    // Check persistence between invocations (when values have been set)
    BugsnagConfiguration *config2 = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertEqualObjects(config2.user.email, email);
    XCTAssertEqualObjects(config2.user.name, name);
    XCTAssertEqualObjects(config2.user.id, userId);
    
    XCTAssertEqualObjects(config2.  user.email, email);
    XCTAssertEqualObjects(config2.user.name, name);
    XCTAssertEqualObjects(config2.user.id, userId);
}

- (void)testSettingPersistUser {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertTrue(config.persistUser);
    [config setPersistUser:false];
    XCTAssertFalse(config.persistUser);
    [config setPersistUser:true];
    XCTAssertTrue(config.persistUser);
}

// =============================================================================
// MARK: - Max Breadcrumb
// =============================================================================

- (void)testMaxBreadcrumb {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertEqual(25, config.maxBreadcrumbs);

    // alter to valid value
    config.maxBreadcrumbs = 10;
    XCTAssertEqual(10, config.maxBreadcrumbs);

    // alter to max value
    config.maxBreadcrumbs = 100;
    XCTAssertEqual(100, config.maxBreadcrumbs);

    // alter to min value
    config.maxBreadcrumbs = 0;
    XCTAssertEqual(0, config.maxBreadcrumbs);

    // alter to negative value
    config.maxBreadcrumbs = -1;
    XCTAssertEqual(0, config.maxBreadcrumbs);

    // alter to negative value (overflows)
    config.maxBreadcrumbs = 500;
    XCTAssertEqual(0, config.maxBreadcrumbs);
}

// =============================================================================
// MARK: - Default configuration values
// =============================================================================

- (void)testDefaultConfigurationValues {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];

#if TARGET_OS_TV
    XCTAssertEqualObjects(@"tvOS", config.appType);
#elif TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
    XCTAssertEqualObjects(@"iOS", config.appType);
#elif TARGET_OS_MAC
    XCTAssertEqualObjects(@"macOS", config.appType);
#endif

    XCTAssertNil(config.appVersion);
    XCTAssertTrue(config.autoDetectErrors);
    XCTAssertTrue(config.autoTrackSessions);
    XCTAssertEqualObjects(NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"], config.bundleVersion);
    XCTAssertNil(config.context);
    XCTAssertEqual(BSGEnabledBreadcrumbTypeAll, config.enabledBreadcrumbTypes);
    XCTAssertTrue(config.enabledErrorTypes.cppExceptions);
    XCTAssertTrue(config.enabledErrorTypes.machExceptions);
    XCTAssertTrue(config.enabledErrorTypes.signals);
    XCTAssertTrue(config.enabledErrorTypes.unhandledExceptions);
    XCTAssertTrue(config.enabledErrorTypes.unhandledRejections);

#if DEBUG
    XCTAssertFalse(config.enabledErrorTypes.ooms);
#else
    XCTAssertTrue(config.enabledErrorTypes.ooms);
#endif

    XCTAssertNil(config.enabledReleaseStages);
    XCTAssertEqualObjects(@"https://notify.bugsnag.com", config.endpoints.notify);
    XCTAssertEqualObjects(@"https://sessions.bugsnag.com", config.endpoints.sessions);
    XCTAssertEqual(25, config.maxBreadcrumbs);
    XCTAssertTrue(config.persistUser);
    XCTAssertEqual(1, [config.redactedKeys count]);
    XCTAssertEqualObjects(@"password", [config.redactedKeys allObjects][0]);

#if DEBUG
    XCTAssertEqualObjects(@"development", config.releaseStage);
#else
    XCTAssertEqualObjects(@"production", config.releaseStage);
#endif

    XCTAssertEqual(BSGThreadSendPolicyAlways, config.sendThreads);
}

// =============================================================================
// MARK: - Other tests
// =============================================================================

- (void)testInitWithApiKeyThrowsWhenMissing {
    NSString *nilKey = nil;

    XCTAssertThrows([[BugsnagConfiguration alloc] initWithApiKey:nilKey]);
    XCTAssertThrows([[BugsnagConfiguration alloc] initWithApiKey:@""]);
}

/**
 * When passed an invalid API Key we log a warning message but will still use the key
 */
- (void)testInitWithApiKeyUsesInvalidApiKeys {
    BugsnagConfiguration *invalidApiConfig = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_16CHAR];
    XCTAssertNotNil(invalidApiConfig);
    XCTAssertEqualObjects(invalidApiConfig.apiKey, DUMMY_APIKEY_16CHAR);
}

-(void)testDesignatedInitializerValidApiKey {
    BugsnagConfiguration *validApiConfig1 = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertNotNil(validApiConfig1);
    XCTAssertEqual([validApiConfig1 apiKey], DUMMY_APIKEY_32CHAR_1);

    BugsnagConfiguration *validApiConfig2 = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_2];
    XCTAssertNotNil(validApiConfig2);
    XCTAssertEqual([validApiConfig2 apiKey], DUMMY_APIKEY_32CHAR_2);
}

/**
 * [BugsnagConfiguration init] is explicitly made unavailable.
 * Test that it throws if it *is* called.  An explanation of the reason for
 * the slightly involved code to call the method is given here (hint: ARC):
 *
 *     https://stackoverflow.com/a/20058585/2431627
 */
-(void)testUnavailableConvenienceInitializer {
    BugsnagConfiguration *config = [BugsnagConfiguration alloc];
    SEL selector = NSSelectorFromString(@"init");
    IMP imp = [config methodForSelector:selector];
    void (*func)(id, SEL) = (void *)imp;
    XCTAssertThrows(func(config, selector));
}

- (void)testErrorApiHeaders {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    NSDictionary *headers = [config errorApiHeaders];
    XCTAssertEqualObjects(config.apiKey, headers[@"Bugsnag-Api-Key"]);
    XCTAssertNotNil(headers[@"Bugsnag-Sent-At"]);
    XCTAssertNotNil(headers[@"Bugsnag-Payload-Version"]);
}

- (void)testUser {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    
    [config setUser:@"123" withEmail:@"test@example.com" andName:@"foo"];
    
    XCTAssertEqualObjects(@"123", config.user.id);
    XCTAssertEqualObjects(@"foo", config.user.name);
    XCTAssertEqualObjects(@"test@example.com", config.user.email);
}

- (void)testApiKeySetter {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertEqual(DUMMY_APIKEY_32CHAR_1, config.apiKey);

    config.apiKey = DUMMY_APIKEY_32CHAR_1;
    XCTAssertEqual(DUMMY_APIKEY_32CHAR_1, config.apiKey);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertThrows(config.apiKey = nil);
#pragma clang diagnostic pop

    XCTAssertEqual(DUMMY_APIKEY_32CHAR_1, config.apiKey);

    XCTAssertThrows(config.apiKey = @"");
    XCTAssertEqual(DUMMY_APIKEY_32CHAR_1, config.apiKey);

    config.apiKey = DUMMY_APIKEY_16CHAR;
    XCTAssertEqual(DUMMY_APIKEY_16CHAR, config.apiKey);

    config.apiKey = DUMMY_APIKEY_32CHAR_1;
    XCTAssertEqual(DUMMY_APIKEY_32CHAR_1, config.apiKey);
}

-(void)testBSGErrorTypes {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];

    // Test all are set by default
    // See config init for details.  OOMs are disabled in debug.
    config.enabledErrorTypes.ooms = true;

    XCTAssertTrue(config.enabledErrorTypes.ooms);
    XCTAssertTrue(config.enabledErrorTypes.signals);
    XCTAssertTrue(config.enabledErrorTypes.cppExceptions);
    XCTAssertTrue(config.enabledErrorTypes.unhandledExceptions);
    XCTAssertTrue(config.enabledErrorTypes.machExceptions);
    XCTAssertTrue(config.enabledErrorTypes.unhandledRejections);

    // Test that we can set it
    config.enabledErrorTypes.ooms = false;
    config.enabledErrorTypes.signals = false;
    config.enabledErrorTypes.cppExceptions = false;
    config.enabledErrorTypes.unhandledExceptions = false;
    config.enabledErrorTypes.unhandledRejections = false;
    config.enabledErrorTypes.machExceptions = false;
    XCTAssertFalse(config.enabledErrorTypes.ooms);
    XCTAssertFalse(config.enabledErrorTypes.signals);
    XCTAssertFalse(config.enabledErrorTypes.cppExceptions);
    XCTAssertFalse(config.enabledErrorTypes.unhandledExceptions);
    XCTAssertFalse(config.enabledErrorTypes.unhandledRejections);
    XCTAssertFalse(config.enabledErrorTypes.machExceptions);
}

/**
 * Test the mapping between BSGErrorTypes and KSCrashTypes
 */
-(void)testCrashTypeMapping {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    BugsnagCrashSentry *sentry = [BugsnagCrashSentry new];
    BSG_KSCrashType crashTypes = BSG_KSCrashTypeNSException
                               | BSG_KSCrashTypeMachException
                               | BSG_KSCrashTypeSignal
                               | BSG_KSCrashTypeCPPException;

    XCTAssertEqual(crashTypes, [sentry mapKSToBSGCrashTypes:[config enabledErrorTypes]]);

    crashTypes = crashTypes | BSG_KSCrashTypeUserReported;

    XCTAssertNotEqual(crashTypes, [sentry mapKSToBSGCrashTypes:[config enabledErrorTypes]]);

    // Check partial sets
    BugsnagErrorTypes *errorTypes = [BugsnagErrorTypes new];
    errorTypes.ooms = false;
    errorTypes.signals = false;
    errorTypes.machExceptions = false;
    crashTypes = BSG_KSCrashTypeNSException | BSG_KSCrashTypeCPPException;
    XCTAssertEqual((NSUInteger)crashTypes, [sentry mapKSToBSGCrashTypes:errorTypes]);

    errorTypes.signals = true;
    errorTypes.cppExceptions = false;
    crashTypes = BSG_KSCrashTypeNSException | BSG_KSCrashTypeSignal;
    XCTAssertEqual((NSUInteger)crashTypes, [sentry mapKSToBSGCrashTypes:errorTypes]);

    errorTypes.cppExceptions = true;
    errorTypes.unhandledExceptions = false;
    crashTypes = BSG_KSCrashTypeCPPException | BSG_KSCrashTypeSignal;
    XCTAssertEqual((NSUInteger)crashTypes, [sentry mapKSToBSGCrashTypes:errorTypes]);
}

/**
 * Test that removeOnSendBlock() performs as expected.
 * Note: We don't test that set blocks are executed since this is tested elsewhere
 * (e.g. in BugsnagBreadcrumbsTest)
 */
- (void) testRemoveOnSendBlock {
    // Prevent sending events
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertEqual([[configuration onSendBlocks] count], 0);

    BugsnagOnSendErrorBlock block = ^BOOL(BugsnagEvent * _Nonnull event) { return false; };

    [configuration addOnSendErrorBlock:block];
    BugsnagClient *client = [[BugsnagClient alloc] initWithConfiguration:configuration];
    [client start];

    XCTAssertEqual([[configuration onSendBlocks] count], 1);

    [configuration removeOnSendErrorBlock:block];
    XCTAssertEqual([[configuration onSendBlocks] count], 0);
}

/**
 * Test that clearOnSendBlock() performs as expected.
 */
- (void) testClearOnSendBlock {
    // Prevent sending events
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertEqual([[configuration onSendBlocks] count], 0);

    BugsnagOnSendErrorBlock block1 = ^BOOL(BugsnagEvent * _Nonnull event) { return false; };
    BugsnagOnSendErrorBlock block2 = ^BOOL(BugsnagEvent * _Nonnull event) { return false; };

    // Add more than one
    [configuration addOnSendErrorBlock:block1];
    [configuration addOnSendErrorBlock:block2];

    BugsnagClient *client = [[BugsnagClient alloc] initWithConfiguration:configuration];
    [client start];

    XCTAssertEqual([[configuration onSendBlocks] count], 2);
}

- (void)testSendThreadsDefault {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertEqual(BSGThreadSendPolicyAlways, config.sendThreads);
}

- (void)testNSCopying {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];

    // Set some arbirtary values:
    [config setUser:@"foo" withEmail:@"bar@baz.com" andName:@"Bill"];
    [config setApiKey:DUMMY_APIKEY_32CHAR_1];
    [config setAutoDetectErrors:YES];
    [config setContext:@"context1"];
    [config setAppType:@"The most amazing app, a brilliant app, the app to end all apps"];
    [config setPersistUser:YES];
    [config setSendThreads:BSGThreadSendPolicyUnhandledOnly];
    BugsnagOnSendErrorBlock onSendBlock1 = ^BOOL(BugsnagEvent * _Nonnull event) { return true; };
    BugsnagOnSendErrorBlock onSendBlock2 = ^BOOL(BugsnagEvent * _Nonnull event) { return true; };

    NSArray *sendBlocks = @[ onSendBlock1, onSendBlock2 ];
    [config setOnSendBlocks:[sendBlocks mutableCopy]]; // Mutable arg required

    // Clone
    BugsnagConfiguration *clone = [config copy];
    XCTAssertNotEqual(config, clone);

    // Change values

    // Redacted keys
    XCTAssertEqualObjects(config.redactedKeys, clone.redactedKeys);

    // sendThreads
    XCTAssertEqual(config.sendThreads, clone.sendThreads);

    // Object
    [clone setUser:@"Cthulu" withEmail:@"hp@lovecraft.com" andName:@"Howard"];
    XCTAssertEqualObjects(config.user.id, @"foo");
    XCTAssertEqualObjects(clone.user.id, @"Cthulu");

    // String
    [clone setApiKey:DUMMY_APIKEY_32CHAR_2];
    XCTAssertEqualObjects(config.apiKey, DUMMY_APIKEY_32CHAR_1);
    XCTAssertEqualObjects(clone.apiKey, DUMMY_APIKEY_32CHAR_2);

    // Bool
    [clone setAutoDetectErrors:NO];
    XCTAssertTrue(config.autoDetectErrors);
    XCTAssertFalse(clone.autoDetectErrors);

    // Block
    [clone setOnCrashHandler:config.onCrashHandler];
    XCTAssertEqual(config.onCrashHandler, clone.onCrashHandler);
    [clone setOnCrashHandler:(void *)^(const BSG_KSCrashReportWriter *_Nonnull writer){}];
    XCTAssertNotEqual(config.onCrashHandler, clone.onCrashHandler);

    // Array (of blocks)
    XCTAssertEqual(config.onSendBlocks, clone.onSendBlocks);
    XCTAssertEqual(config.onSendBlocks[0], clone.onSendBlocks[0]);
    [clone setOnSendBlocks:[@[ onSendBlock2 ] mutableCopy]];
    XCTAssertNotEqual(config.onSendBlocks[0], clone.onSendBlocks[0]);
}

- (void)testMetadataMutability {
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];

    // Immutable in, mutable out
    [configuration addMetadata:@{@"foo" : @"bar"} toSection:@"section1"];
    NSObject *metadata1 = [configuration getMetadataFromSection:@"section1"];
    XCTAssertTrue([metadata1 isKindOfClass:[NSMutableDictionary class]]);

    // Mutable in, mutable out
    [configuration addMetadata:[@{@"foo" : @"bar"} mutableCopy] toSection:@"section2"];
    NSObject *metadata2 = [configuration getMetadataFromSection:@"section2"];
    XCTAssertTrue([metadata2 isKindOfClass:[NSMutableDictionary class]]);
}

@end
