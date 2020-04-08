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
#import "BSG_SSKeychain.h"


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
- (BSG_KSCrashType)mapKSToBSGCrashTypes:(BSGEnabledErrorType)bsgCrashMask;
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
    [config setEndpointsForNotify:@"http://localhost:1234" sessions:@"http://localhost:8000"];
    XCTAssertEqualObjects([NSURL URLWithString:@"http://localhost:8000"], config.sessionURL);
}

- (void)testSetEmptySessionsEndpoint {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    [config setEndpointsForNotify:@"http://notify.example.com" sessions:@""];
    BugsnagSessionTracker *sessionTracker
            = [[BugsnagSessionTracker alloc] initWithConfig:config postRecordCallback:nil];

    XCTAssertNil(sessionTracker.runningSession);
    [sessionTracker startNewSession];
    XCTAssertNil(sessionTracker.runningSession);
}

- (void)testSetMalformedSessionsEndpoint {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    [config setEndpointsForNotify:@"http://notify.example.com" sessions:@"f"];
    BugsnagSessionTracker *sessionTracker
            = [[BugsnagSessionTracker alloc] initWithConfig:config postRecordCallback:nil];

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
    [config setEndpointsForNotify:@"http://notreal.bugsnag.com" sessions:@"http://notreal.bugsnag.com"];
    XCTAssertEqual([[config onSessionBlocks] count], 0);
    BugsnagOnSessionBlock sessionBlock = ^(NSMutableDictionary * _Nonnull sessionPayload) {
        // We expect the session block to be called
        [expectation fulfill];
    };
    [config addOnSessionBlock:sessionBlock];
    XCTAssertEqual([[config onSessionBlocks] count], 1);
    
    // Call onSession blocks
    [Bugsnag startBugsnagWithConfiguration:config];
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
    [config setEndpointsForNotify:@"http://notreal.bugsnag.com" sessions:@"http://notreal.bugsnag.com"];
    XCTAssertEqual([[config onSessionBlocks] count], 0);
    BugsnagOnSessionBlock sessionBlock = ^(NSMutableDictionary * _Nonnull sessionPayload) {
        [calledExpectation fulfill];
    };
    
    // It's there (and from other tests we know it gets called) and then it's not there
    [config addOnSessionBlock:sessionBlock];
    XCTAssertEqual([[config onSessionBlocks] count], 1);
    [config removeOnSessionBlock:sessionBlock];
    XCTAssertEqual([[config onSessionBlocks] count], 0);

    [Bugsnag startBugsnagWithConfiguration:config];

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
    expectation4.inverted = YES;

    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    [config setEndpointsForNotify:@"http://notreal.bugsnag.com" sessions:@"http://notreal.bugsnag.com"];
    XCTAssertEqual([[config onSessionBlocks] count], 0);
    
    BugsnagOnSessionBlock sessionBlock = ^(NSMutableDictionary * _Nonnull sessionPayload) {
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
    };
    
    [config addOnSessionBlock:sessionBlock];
    XCTAssertEqual([[config onSessionBlocks] count], 1);
    
    // Call onSession blocks
    [Bugsnag startBugsnagWithConfiguration:config];
    [self waitForExpectations:@[expectation1] timeout:1.0];
    
    // Check it's called on new session start
    [Bugsnag pauseSession];
    called++;
    [Bugsnag startSession];
    [self waitForExpectations:@[expectation2] timeout:1.0];

    // Check it's still called once the block's deleted (block has been copied in client init)
    [Bugsnag pauseSession];
    called++;
    [config removeOnSessionBlock:sessionBlock];
    [Bugsnag startSession];
    [self waitForExpectations:@[expectation3] timeout:1.0];
    
    // Check it's NOT called on session resume
    [Bugsnag pauseSession];
    called++;
    [config addOnSessionBlock:sessionBlock];
    [Bugsnag resumeSession];
    [self waitForExpectations:@[expectation4] timeout:1.0];
}

/**
 * Make sure slightly invalid removals and duplicate additions don't break things
 */
- (void)testRemoveNonexistentOnSessionBlocks {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertEqual([[config onSessionBlocks] count], 0);
    BugsnagOnSessionBlock sessionBlock1 = ^(NSMutableDictionary * _Nonnull sessionPayload) {};
    BugsnagOnSessionBlock sessionBlock2 = ^(NSMutableDictionary * _Nonnull sessionPayload) {};
    
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
    config.enabledReleaseStages = @[];
    XCTAssertTrue([config shouldSendReports]);
}

- (void)testEnabledReleaseStagesIncludedSends {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.releaseStage = @"beta";
    config.enabledReleaseStages = @[ @"beta" ];
    XCTAssertTrue([config shouldSendReports]);
}

- (void)testEnabledReleaseStagesIncludedInManySends {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.releaseStage = @"beta";
    config.enabledReleaseStages = @[ @"beta", @"production" ];
    XCTAssertTrue([config shouldSendReports]);
}

- (void)testEnabledReleaseStagesExcludedSkipsSending {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.releaseStage = @"beta";
    config.enabledReleaseStages = @[ @"production" ];
    XCTAssertFalse([config shouldSendReports]);
}

- (void)testDefaultReleaseStage {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
#if DEBUG
    XCTAssertEqualObjects(@"development", config.releaseStage);
#else
    XCTAssertEqualObjects(@"production", config.releaseStage);
#endif
}

// =============================================================================
// MARK: - Endpoint-related
// =============================================================================

- (void)testNotifyEndpoint {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertEqualObjects([NSURL URLWithString:@"https://notify.bugsnag.com/"], config.notifyURL);

    // Test overriding the notify endpoint (use dummy endpoints to avoid hitting production)
    [config setEndpointsForNotify:@"http://localhost:1234" sessions:@"http://localhost:8000"];
    XCTAssertEqualObjects([NSURL URLWithString:@"http://localhost:1234"], config.notifyURL);
}

- (void)testSetEndpoints {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    [config setEndpointsForNotify:@"http://notify.example.com" sessions:@"http://sessions.example.com"];
    XCTAssertEqualObjects([NSURL URLWithString:@"http://notify.example.com"], config.notifyURL);
    XCTAssertEqualObjects([NSURL URLWithString:@"http://sessions.example.com"], config.sessionURL);
}

// in debug these throw exceptions though in release are "tolerated"
- (void)testSetNilNotifyEndpoint {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    NSString *notify = @"foo";
    notify = nil;
#if DEBUG
    XCTAssertThrowsSpecificNamed([config setEndpointsForNotify:notify sessions:@"http://sessions.example.com"],
            NSException, NSInternalInconsistencyException);
#else
    XCTAssertNoThrow([config setEndpointsForNotify:@"" sessions:@"http://sessions.example.com"]);
#endif
}

// in debug these throw exceptions though in release are "tolerated"
- (void)testSetEmptyNotifyEndpoint {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
#if DEBUG
    XCTAssertThrowsSpecificNamed([config setEndpointsForNotify:@"" sessions:@"http://sessions.example.com"],
            NSException, NSInternalInconsistencyException);
#else
    XCTAssertNoThrow([config setEndpointsForNotify:@"" sessions:@"http://sessions.example.com"]);
#endif
}

// in debug these throw exceptions though in release are "tolerated"
- (void)testSetMalformedNotifyEndpoint {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
#if DEBUG
    XCTAssertThrowsSpecificNamed([config setEndpointsForNotify:@"http://" sessions:@"http://sessions.example.com"],
            NSException, NSInternalInconsistencyException);
#else
    XCTAssertNoThrow([config setEndpointsForNotify:@"http://" sessions:@"http://sessions.example.com"]);
#endif
}

// =============================================================================
// MARK: - User persistence tests
// =============================================================================
/**
 * We'd like to test user persistence here but we're not able to.  Keychain access requires correct
 * entitlements, and these can only be associated with an application, not a framework.  Creating a
 * dummy app and associating it with the test target is possible but raises issues around signing
 * as well as breaking preexisting tests.
 *
 * See e.g. https://forums.developer.apple.com/thread/60617 for some background.
 *    also: https://forums.developer.apple.com/message/179846
 *     and: https://github.com/samsoffes/sskeychain
 *
 * The solution is to shift the testing of the user persistence feature to the end-to-end integration
 * tests, located in <project>/features/user_persistence.feature.  These do have an associated test app,
 * but require the bugsnag-mazerunner project (available on github) to run locally.
 *
 * For the purposes of contributing to coverage and in case the Entitlement situation is mitigated in the
 * future the tests are left in place, but have had failing assertions commented out.
 */

- (void)testUserPersistence {
    NSString *email  = @"test@example.com";
    NSString *name   = @"foo";
    NSString *userId = @"123";
    
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    
    // Check property defaults to True
    XCTAssertTrue(config.persistUser);
    
    // Start with no persisted user data
    [config deletePersistedUserData];
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserEmailAddress account:kBugsnagUserKeychainAccount]);
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserName account:kBugsnagUserKeychainAccount]);
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserUserId account:kBugsnagUserKeychainAccount]);
    
    // user should be persisted by default
    [config setUser:userId withEmail:email andName:name];
    
    // Check values manually
//    XCTAssertEqualObjects([bsg_SSKeychain passwordForService:kBugsnagUserEmailAddress account:kBugsnagUserKeychainAccount], email);
//    XCTAssertEqualObjects([bsg_SSKeychain passwordForService:kBugsnagUserName account:kBugsnagUserKeychainAccount], name);
//    XCTAssertEqualObjects([bsg_SSKeychain passwordForService:kBugsnagUserUserId account:kBugsnagUserKeychainAccount], userId);
    
    // Check persistence between invocations (when values have been set)
    BugsnagConfiguration *config2 = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    
//    XCTAssertEqualObjects(config2.currentUser.emailAddress, email);
//    XCTAssertTrue([config2.currentUser.name isEqualToString:name]);
//    XCTAssertTrue([config2.currentUser.userId isEqualToString:userId]);
    
    // Check that values we know to have been persisted are actuallty deleted.
    [config2 deletePersistedUserData];
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserEmailAddress account:kBugsnagUserKeychainAccount]);
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserName account:kBugsnagUserKeychainAccount]);
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserUserId account:kBugsnagUserKeychainAccount]);
}

/**
 * Test that user data is (as far as we can tell) not persisted
 */
- (void)testUserNonPesistence {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.persistUser = false;
    [config deletePersistedUserData];
    
    // Should be no persisted data, and should not persist between invocations
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserEmailAddress account:kBugsnagUserKeychainAccount]);
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserName account:kBugsnagUserKeychainAccount]);
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserUserId account:kBugsnagUserKeychainAccount]);

    BugsnagConfiguration *config2 = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertNotNil(config2.user);
    XCTAssertNil(config2.user.userId);
    XCTAssertNil(config2.user.name);
    XCTAssertNil(config2.user.emailAddress);
}

/**
 * Test partial parsistence
 */
- (void)testPartialPesistence {
    NSString *email  = @"test@example.com";
    NSString *name   = @"foo";
    NSString *userId = @"123";
    
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertTrue(config.persistUser);
    [config deletePersistedUserData];

    // Should be no persisted data
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserEmailAddress account:kBugsnagUserKeychainAccount]);
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserName account:kBugsnagUserKeychainAccount]);
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserUserId account:kBugsnagUserKeychainAccount]);

    [config setUser:userId withEmail:nil andName:nil];
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserEmailAddress account:kBugsnagUserKeychainAccount]);
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserName account:kBugsnagUserKeychainAccount]);
//    XCTAssertEqualObjects([bsg_SSKeychain passwordForService:kBugsnagUserUserId account:kBugsnagUserKeychainAccount], userId);
    [config setUser:nil withEmail:email andName:nil];
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserEmailAddress account:kBugsnagUserKeychainAccount]);
//    XCTAssertEqualObjects([bsg_SSKeychain passwordForService:kBugsnagUserName account:kBugsnagUserKeychainAccount], name);
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserUserId account:kBugsnagUserKeychainAccount]);

    [config setUser:nil withEmail:nil andName:name];
//    XCTAssertEqualObjects([bsg_SSKeychain passwordForService:kBugsnagUserEmailAddress account:kBugsnagUserKeychainAccount], email);
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserName account:kBugsnagUserKeychainAccount]);
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserUserId account:kBugsnagUserKeychainAccount]);
}

/**
 * Test that persisting a BugsnagUser with all nil fields behaves as expected
 */
- (void)testAllUserDataNilPersistence {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertTrue(config.persistUser);
    [config deletePersistedUserData];

    [config setUser:nil withEmail:nil andName:nil];

    // currentUser should have been set
    XCTAssertNotNil(config.user);

    // But there hould be no persisted data
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserEmailAddress account:kBugsnagUserKeychainAccount]);
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserName account:kBugsnagUserKeychainAccount]);
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserUserId account:kBugsnagUserKeychainAccount]);
}

/**
 * Test that the configuration metadata is set correctly.
 */
- (void)testUserPersistenceAndMetadata {
    NSString *email  = @"test@example.com";
    NSString *name   = @"foo";
    NSString *userId = @"123";
    
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertTrue(config.persistUser);
    [config deletePersistedUserData];

    // Should be no persisted data
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserEmailAddress account:kBugsnagUserKeychainAccount]);
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserName account:kBugsnagUserKeychainAccount]);
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserUserId account:kBugsnagUserKeychainAccount]);
    
    // Persist user data
    [config setUser:userId withEmail:email andName:name];

    // Check that retrieving persisted user data also sets configuration metadata
    // Check persistence between invocations (when values have been set)
//    BugsnagConfiguration *config2 = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
//    XCTAssertTrue([config2.currentUser.emailAddress isEqualToString:email]);
//    XCTAssertTrue([config2.currentUser.name isEqualToString:name]);
//    XCTAssertTrue([config2.currentUser.userId isEqualToString:userId]);

//    XCTAssertEqualObjects([config2.metadata getMetadata:BSGKeyUser key:BSGKeyEmail], email);
//    XCTAssertEqualObjects([config2.metadata getMetadata:BSGKeyUser key:BSGKeyName], name);
//    XCTAssertEqualObjects([config2.metadata getMetadata:BSGKeyUser key:BSGKeyId], userId);
}

/**
 * Test that non-persisted user data interacts correctly with the configuration metadata
 */
- (void)testNonPersistenceAndMetadata {
    
    NSString *email  = @"test@example.com";
    NSString *name   = @"foo";
    NSString *userId = @"123";
    
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertTrue(config.persistUser);
    [config setPersistUser:false];
    [config deletePersistedUserData];
    
    BugsnagConfiguration *config2 = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
//    XCTAssertNil([[config2 metadata] getMetadata:BSGKeyUser key:BSGKeyId]);
//    XCTAssertNil([[config2 metadata] getMetadata:BSGKeyUser key:BSGKeyName]);
//    XCTAssertNil([[config2 metadata] getMetadata:BSGKeyUser key:BSGKeyEmail]);
    
    [config2 setUser:userId withEmail:email andName:name];
//    XCTAssertEqualObjects([config2.metadata getMetadata:BSGKeyUser key:BSGKeyEmail], email);
//    XCTAssertEqualObjects([config2.metadata getMetadata:BSGKeyUser key:BSGKeyName], name);
//    XCTAssertEqualObjects([config2.metadata getMetadata:BSGKeyUser key:BSGKeyId], userId);
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
// MARK: - Other tests
// =============================================================================

/**
 * Test correct population of an NSError in the case of an invalid apiKey
 */
-(void)testDesignatedInitializerInvalidApiKey {
    BugsnagConfiguration *invalidApiConfig = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_16CHAR];
    XCTAssertNotNil(invalidApiConfig);
    XCTAssertEqualObjects(invalidApiConfig.apiKey, DUMMY_APIKEY_16CHAR);
}

/**
* Test NSError is not populated in the case of a valid apiKey
*/
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

- (void)testDefaultReportOOMs {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
#if DEBUG
    XCTAssertFalse([config enabledErrorTypes] & BSGErrorTypesOOMs);
#else
    XCTAssertTrue([config enabledErrorTypes] & BSGErrorTypesOOMs);
#endif
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
    
    XCTAssertEqualObjects(@"123", config.user.userId);
    XCTAssertEqualObjects(@"foo", config.user.name);
    XCTAssertEqualObjects(@"test@example.com", config.user.emailAddress);
}

- (void)testApiKeySetter {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertTrue([config.apiKey isEqualToString:DUMMY_APIKEY_32CHAR_1]);
    config.apiKey = DUMMY_APIKEY_32CHAR_1;
    XCTAssertEqual(DUMMY_APIKEY_32CHAR_1, config.apiKey);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertThrows(config.apiKey = nil);
#pragma clang diagnostic pop

    XCTAssertTrue([config.apiKey isEqualToString:DUMMY_APIKEY_32CHAR_1]);
    
    XCTAssertThrows(config.apiKey = DUMMY_APIKEY_16CHAR);
    XCTAssertThrows(config.apiKey = DUMMY_APIKEY_16CHAR);
}

- (void)testHasValidApiKey {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];

    XCTAssertThrows(config.apiKey = DUMMY_APIKEY_16CHAR);
    XCTAssertTrue([config.apiKey isEqualToString:DUMMY_APIKEY_32CHAR_1]);
    
    config.apiKey = DUMMY_APIKEY_32CHAR_2;
    XCTAssertTrue([config.apiKey isEqualToString:DUMMY_APIKEY_32CHAR_2]);
}

-(void)testBSGErrorTypes {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    
    // Test all are set by default
    BSGEnabledErrorType enabledErrors = BSGErrorTypesNSExceptions
                               | BSGErrorTypesSignals
                               | BSGErrorTypesMach
                               | BSGErrorTypesCPP;
// See config init for details.  OOMs are disabled in debug.
#if !DEBUG
    enabledErrors |= BSGErrorTypesOOMs;
#endif
    
    XCTAssertEqual([config enabledErrorTypes], enabledErrors);
    
    // Test that we can set it
    config.enabledErrorTypes = BSGErrorTypesOOMs | BSGErrorTypesNSExceptions;
    XCTAssertEqual([config enabledErrorTypes], BSGErrorTypesOOMs | BSGErrorTypesNSExceptions);
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
    BSGEnabledErrorType partialErrors = BSGErrorTypesNSExceptions | BSGErrorTypesCPP;
    crashTypes = BSG_KSCrashTypeNSException | BSG_KSCrashTypeCPPException;
    XCTAssertEqual((NSUInteger)crashTypes, [sentry mapKSToBSGCrashTypes:(NSUInteger)partialErrors]);
    
    partialErrors = BSGErrorTypesNSExceptions | BSGErrorTypesSignals;
    crashTypes = BSG_KSCrashTypeNSException | BSG_KSCrashTypeSignal;
    XCTAssertEqual((NSUInteger)crashTypes, [sentry mapKSToBSGCrashTypes:(NSUInteger)partialErrors]);

    partialErrors = BSGErrorTypesCPP | BSGErrorTypesSignals;
    crashTypes = BSG_KSCrashTypeCPPException | BSG_KSCrashTypeSignal;
    XCTAssertEqual((NSUInteger)crashTypes, [sentry mapKSToBSGCrashTypes:(NSUInteger)partialErrors]);
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
    
    BugsnagOnSendBlock block = ^bool(BugsnagEvent * _Nonnull event) { return false; };
    
    [configuration addOnSendBlock:block];
    [Bugsnag startBugsnagWithConfiguration:configuration];
    
    XCTAssertEqual([[configuration onSendBlocks] count], 1);
    
    [configuration removeOnSendBlock:block];
    XCTAssertEqual([[configuration onSendBlocks] count], 0);
}

/**
 * Test that clearOnSendBlock() performs as expected.
 */
- (void) testClearOnSendBlock {
    // Prevent sending events
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertEqual([[configuration onSendBlocks] count], 0);
    
    BugsnagOnSendBlock block1 = ^bool(BugsnagEvent * _Nonnull event) { return false; };
    BugsnagOnSendBlock block2 = ^bool(BugsnagEvent * _Nonnull event) { return false; };
    
    // Add more than one
    [configuration addOnSendBlock:block1];
    [configuration addOnSendBlock:block2];
    
    [Bugsnag startBugsnagWithConfiguration:configuration];
    
    XCTAssertEqual([[configuration onSendBlocks] count], 2);
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
    BugsnagOnSendBlock onSendBlock1 = ^bool(BugsnagEvent * _Nonnull event) { return true; };
    BugsnagOnSendBlock onSendBlock2 = ^bool(BugsnagEvent * _Nonnull event) { return true; };

    NSArray *sendBlocks = @[ onSendBlock1, onSendBlock2 ];
    [config setOnSendBlocks:[sendBlocks mutableCopy]]; // Mutable arg required
    
    // Clone
    BugsnagConfiguration *clone = [config copy];
    XCTAssertNotEqual(config, clone);
    
    // Change values
    
    // Object
    [clone setUser:@"Cthulu" withEmail:@"hp@lovecraft.com" andName:@"Howard"];
    XCTAssertEqualObjects(config.user.userId, @"foo");
    XCTAssertEqualObjects(clone.user.userId, @"Cthulu");
    
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
    XCTAssertNotEqual(config.onSendBlocks, clone.onSendBlocks);
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
