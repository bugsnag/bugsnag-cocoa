#import "Bugsnag.h"
#import "BugsnagSessionTracker.h"
#import "BugsnagUser.h"

#import <XCTest/XCTest.h>
#import "BugsnagTestConstants.h"
#import "BugsnagConfiguration.h"
#import "BugsnagCrashSentry.h"
#import "BSG_KSCrashType.h"
#import "BugsnagKeys.h"
#import "BSG_SSKeychain.h"

@interface BugsnagConfiguration ()
- (void)deletePersistedUserData;
@end

@interface BugsnagConfigurationTests : XCTestCase
@end

@interface BugsnagCrashSentry ()
- (BSG_KSCrashType)mapKSToBSGCrashTypes:(BSGErrorType)bsgCrashMask;
@end

@implementation BugsnagConfigurationTests

- (void)testDefaultSessionNotNil {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    XCTAssertNotNil(config.session);
}

- (void)testNotifyReleaseStagesDefaultSends {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    XCTAssertTrue([config shouldSendReports]);
}

- (void)testNotifyReleaseStagesNilSends {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    config.releaseStage = @"beta";
    config.notifyReleaseStages = nil;
    XCTAssertTrue([config shouldSendReports]);
}

- (void)testNotifyReleaseStagesEmptySends {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    config.releaseStage = @"beta";
    config.notifyReleaseStages = @[];
    XCTAssertTrue([config shouldSendReports]);
}

- (void)testNotifyReleaseStagesIncludedSends {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    config.releaseStage = @"beta";
    config.notifyReleaseStages = @[ @"beta" ];
    XCTAssertTrue([config shouldSendReports]);
}

- (void)testNotifyReleaseStagesIncludedInManySends {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    config.releaseStage = @"beta";
    config.notifyReleaseStages = @[ @"beta", @"production" ];
    XCTAssertTrue([config shouldSendReports]);
}

- (void)testNotifyReleaseStagesExcludedSkipsSending {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    config.releaseStage = @"beta";
    config.notifyReleaseStages = @[ @"production" ];
    XCTAssertFalse([config shouldSendReports]);
}

- (void)testDefaultReleaseStage {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
#if DEBUG
    XCTAssertEqualObjects(@"development", config.releaseStage);
#else
    XCTAssertEqualObjects(@"production", config.releaseStage);
#endif
}

- (void)testDefaultSessionConfig {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    XCTAssertTrue([config autoTrackSessions]);
}

/**
 * Test correct population of an NSError in the case of an invalid apiKey
 */
-(void)testDesignatedInitializerInvalidApiKey {
    NSError *error;
    BugsnagConfiguration *invalidApiConfig = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_16CHAR error:&error];
    XCTAssertNil(invalidApiConfig);
    XCTAssertNotNil(error);
    XCTAssertEqual([error domain], BSGConfigurationErrorDomain);
    XCTAssertEqual([error code], BSGConfigurationErrorInvalidApiKey);
    
    XCTAssertTrue([[error domain] isEqualToString:@"com.Bugsnag.CocoaNotifier.Configuration"]);
    XCTAssertEqual([error code], 0);

// As per the docs the behaviour varies by platform
//     https://developer.apple.com/documentation/foundation/nserror/1411580-userinfo?language=objc
#if TARGET_OS_MAC
    XCTAssertTrue([[error userInfo] isKindOfClass:[NSDictionary class]]);
    XCTAssertEqual([(NSDictionary *)[error userInfo] count], 1);
#else
    XCTAssertNil([error userInfo]);
#endif
}

/**
* Test NSError is not populated in the case of a valid apiKey
*/
-(void)testDesignatedInitializerValidApiKey {
    NSError *error;
    BugsnagConfiguration *validApiConfig1 = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:&error];
    XCTAssertNotNil(validApiConfig1);
    XCTAssertNil(error);
    XCTAssertEqual([validApiConfig1 apiKey], DUMMY_APIKEY_32CHAR_1);
    
    BugsnagConfiguration *validApiConfig2 = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_2 error:nil];
    XCTAssertNotNil(validApiConfig2);
    XCTAssertNil(error);
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
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
#if DEBUG
    XCTAssertFalse([config enabledErrorTypes] & BSGErrorTypesOOMs);
#else
    XCTAssertTrue([config enabledErrorTypes] & BSGErrorTypesOOMs);
#endif
}

- (void)testErrorApiHeaders {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    NSDictionary *headers = [config errorApiHeaders];
    XCTAssertEqualObjects(config.apiKey, headers[@"Bugsnag-Api-Key"]);
    XCTAssertNotNil(headers[@"Bugsnag-Sent-At"]);
    XCTAssertNotNil(headers[@"Bugsnag-Payload-Version"]);
}

- (void)testSessionApiHeaders {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    NSDictionary *headers = [config sessionApiHeaders];
    XCTAssertEqualObjects(config.apiKey, headers[@"Bugsnag-Api-Key"]);
    XCTAssertNotNil(headers[@"Bugsnag-Sent-At"]);
    XCTAssertNotNil(headers[@"Bugsnag-Payload-Version"]);
}

- (void)testSessionEndpoints {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    
    // Default endpoints
    XCTAssertEqualObjects([NSURL URLWithString:@"https://sessions.bugsnag.com"], config.sessionURL);
    
    // Test overriding the session endpoint (use dummy endpoints to avoid hitting production)
    [config setEndpointsForNotify:@"http://localhost:1234" sessions:@"http://localhost:8000"];
    XCTAssertEqualObjects([NSURL URLWithString:@"http://localhost:8000"], config.sessionURL);
}

- (void)testNotifyEndpoint {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    XCTAssertEqualObjects([NSURL URLWithString:@"https://notify.bugsnag.com/"], config.notifyURL);

    // Test overriding the notify endpoint (use dummy endpoints to avoid hitting production)
    [config setEndpointsForNotify:@"http://localhost:1234" sessions:@"http://localhost:8000"];
    XCTAssertEqualObjects([NSURL URLWithString:@"http://localhost:1234"], config.notifyURL);
}

- (void)testSetEndpoints {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    [config setEndpointsForNotify:@"http://notify.example.com" sessions:@"http://sessions.example.com"];
    XCTAssertEqualObjects([NSURL URLWithString:@"http://notify.example.com"], config.notifyURL);
    XCTAssertEqualObjects([NSURL URLWithString:@"http://sessions.example.com"], config.sessionURL);
}

// in debug these throw exceptions though in release are "tolerated"
- (void)testSetNilNotifyEndpoint {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
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
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
#if DEBUG
    XCTAssertThrowsSpecificNamed([config setEndpointsForNotify:@"" sessions:@"http://sessions.example.com"],
            NSException, NSInternalInconsistencyException);
#else
    XCTAssertNoThrow([config setEndpointsForNotify:@"" sessions:@"http://sessions.example.com"]);
#endif
}

// in debug these throw exceptions though in release are "tolerated"
- (void)testSetMalformedNotifyEndpoint {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
#if DEBUG
    XCTAssertThrowsSpecificNamed([config setEndpointsForNotify:@"http://" sessions:@"http://sessions.example.com"],
            NSException, NSInternalInconsistencyException);
#else
    XCTAssertNoThrow([config setEndpointsForNotify:@"http://" sessions:@"http://sessions.example.com"]);
#endif
}

- (void)testSetEmptySessionsEndpoint {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    [config setEndpointsForNotify:@"http://notify.example.com" sessions:@""];
    BugsnagSessionTracker *sessionTracker
            = [[BugsnagSessionTracker alloc] initWithConfig:config postRecordCallback:nil];

    XCTAssertNil(sessionTracker.runningSession);
    [sessionTracker startNewSession];
    XCTAssertNil(sessionTracker.runningSession);
}

- (void)testSetMalformedSessionsEndpoint {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    [config setEndpointsForNotify:@"http://notify.example.com" sessions:@"f"];
    BugsnagSessionTracker *sessionTracker
            = [[BugsnagSessionTracker alloc] initWithConfig:config postRecordCallback:nil];

    XCTAssertNil(sessionTracker.runningSession);
    [sessionTracker startNewSession];
    XCTAssertNil(sessionTracker.runningSession);
}

- (void)testUser {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    
    [config setUser:@"123" withName:@"foo" andEmail:@"test@example.com"];
    
    XCTAssertEqualObjects(@"123", config.currentUser.userId);
    XCTAssertEqualObjects(@"foo", config.currentUser.name);
    XCTAssertEqualObjects(@"test@example.com", config.currentUser.emailAddress);
}

- (void)testApiKeySetter {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
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
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];

    XCTAssertThrows(config.apiKey = DUMMY_APIKEY_16CHAR);
    XCTAssertTrue([config.apiKey isEqualToString:DUMMY_APIKEY_32CHAR_1]);
    
    config.apiKey = DUMMY_APIKEY_32CHAR_2;
    XCTAssertTrue([config.apiKey isEqualToString:DUMMY_APIKEY_32CHAR_2]);
}

-(void)testBSGErrorTypes {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    
    // Test all are set by default
    BSGErrorType enabledErrors = BSGErrorTypesNSExceptions
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
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    BugsnagCrashSentry *sentry = [BugsnagCrashSentry new];
    BSG_KSCrashType crashTypes = BSG_KSCrashTypeNSException
                               | BSG_KSCrashTypeMachException
                               | BSG_KSCrashTypeSignal
                               | BSG_KSCrashTypeCPPException;
    
    XCTAssertEqual(crashTypes, [sentry mapKSToBSGCrashTypes:[config enabledErrorTypes]]);
    
    crashTypes = crashTypes | BSG_KSCrashTypeUserReported;

    XCTAssertNotEqual(crashTypes, [sentry mapKSToBSGCrashTypes:[config enabledErrorTypes]]);
    
    // Check partial sets
    BSGErrorType partialErrors = BSGErrorTypesNSExceptions | BSGErrorTypesCPP;
    crashTypes = BSG_KSCrashTypeNSException | BSG_KSCrashTypeCPPException;
    XCTAssertEqual((NSUInteger)crashTypes, [sentry mapKSToBSGCrashTypes:(NSUInteger)partialErrors]);
    
    partialErrors = BSGErrorTypesNSExceptions | BSGErrorTypesSignals;
    crashTypes = BSG_KSCrashTypeNSException | BSG_KSCrashTypeSignal;
    XCTAssertEqual((NSUInteger)crashTypes, [sentry mapKSToBSGCrashTypes:(NSUInteger)partialErrors]);

    partialErrors = BSGErrorTypesCPP | BSGErrorTypesSignals;
    crashTypes = BSG_KSCrashTypeCPPException | BSG_KSCrashTypeSignal;
    XCTAssertEqual((NSUInteger)crashTypes, [sentry mapKSToBSGCrashTypes:(NSUInteger)partialErrors]);
// MARK: - BEGIN User persistence tests

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
    
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    
    // Check property defaults to True
    XCTAssertTrue(config.persistUser);
    
    // Start with no persisted user data
    [config deletePersistedUserData];
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserEmailAddress account:kBugsnagUserKeychainAccount]);
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserName account:kBugsnagUserKeychainAccount]);
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserUserId account:kBugsnagUserKeychainAccount]);
    
    // user should be persisted by default
    [config setUser:userId withName:name andEmail:email];
    
    // Check values manually
//    XCTAssertEqualObjects([bsg_SSKeychain passwordForService:kBugsnagUserEmailAddress account:kBugsnagUserKeychainAccount], email);
//    XCTAssertEqualObjects([bsg_SSKeychain passwordForService:kBugsnagUserName account:kBugsnagUserKeychainAccount], name);
//    XCTAssertEqualObjects([bsg_SSKeychain passwordForService:kBugsnagUserUserId account:kBugsnagUserKeychainAccount], userId);
    
    // Check persistence between invocations (when values have been set)
    BugsnagConfiguration *config2 = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    
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
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    config.persistUser = false;
    [config deletePersistedUserData];
    
    // Should be no persisted data, and should not persist between invocations
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserEmailAddress account:kBugsnagUserKeychainAccount]);
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserName account:kBugsnagUserKeychainAccount]);
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserUserId account:kBugsnagUserKeychainAccount]);

    BugsnagConfiguration *config2 = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    XCTAssertNil(config2.currentUser);
}

/**
 * Test partial parsistence
 */
- (void)testPartialPesistence {
    NSString *email  = @"test@example.com";
    NSString *name   = @"foo";
    NSString *userId = @"123";
    
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    XCTAssertTrue(config.persistUser);
    [config deletePersistedUserData];

    // Should be no persisted data
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserEmailAddress account:kBugsnagUserKeychainAccount]);
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserName account:kBugsnagUserKeychainAccount]);
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserUserId account:kBugsnagUserKeychainAccount]);

    [config setUser:userId withName:nil andEmail:nil];
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserEmailAddress account:kBugsnagUserKeychainAccount]);
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserName account:kBugsnagUserKeychainAccount]);
//    XCTAssertEqualObjects([bsg_SSKeychain passwordForService:kBugsnagUserUserId account:kBugsnagUserKeychainAccount], userId);
    [config setUser:nil withName:name andEmail:nil];
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserEmailAddress account:kBugsnagUserKeychainAccount]);
//    XCTAssertEqualObjects([bsg_SSKeychain passwordForService:kBugsnagUserName account:kBugsnagUserKeychainAccount], name);
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserUserId account:kBugsnagUserKeychainAccount]);

    [config setUser:nil withName:nil andEmail:email];
//    XCTAssertEqualObjects([bsg_SSKeychain passwordForService:kBugsnagUserEmailAddress account:kBugsnagUserKeychainAccount], email);
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserName account:kBugsnagUserKeychainAccount]);
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserUserId account:kBugsnagUserKeychainAccount]);
}

/**
 * Test that persisting a BugsnagUser with all nil fields behaves as expected
 */
- (void)testAllUserDataNilPersistence {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    XCTAssertTrue(config.persistUser);
    [config deletePersistedUserData];

    [config setUser:nil withName:nil andEmail:nil];

    // currentUser should have been set
    XCTAssertNotNil(config.currentUser);

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
    
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    XCTAssertTrue(config.persistUser);
    [config deletePersistedUserData];

    // Should be no persisted data
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserEmailAddress account:kBugsnagUserKeychainAccount]);
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserName account:kBugsnagUserKeychainAccount]);
//    XCTAssertNil([bsg_SSKeychain passwordForService:kBugsnagUserUserId account:kBugsnagUserKeychainAccount]);
    
    // Persist user data
    [config setUser:userId withName:name andEmail:email];

    // Check that retrieving persisted user data also sets configuration metadata
    // Check persistence between invocations (when values have been set)
//    BugsnagConfiguration *config2 = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
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
    
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    XCTAssertTrue(config.persistUser);
    [config setPersistUser:false];
    [config deletePersistedUserData];
    
    BugsnagConfiguration *config2 = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
//    XCTAssertNil([[config2 metadata] getMetadata:BSGKeyUser key:BSGKeyId]);
//    XCTAssertNil([[config2 metadata] getMetadata:BSGKeyUser key:BSGKeyName]);
//    XCTAssertNil([[config2 metadata] getMetadata:BSGKeyUser key:BSGKeyEmail]);
    
    [config2 setUser:userId withName:name andEmail:email];
//    XCTAssertEqualObjects([config2.metadata getMetadata:BSGKeyUser key:BSGKeyEmail], email);
//    XCTAssertEqualObjects([config2.metadata getMetadata:BSGKeyUser key:BSGKeyName], name);
//    XCTAssertEqualObjects([config2.metadata getMetadata:BSGKeyUser key:BSGKeyId], userId);
}

- (void)testSettingPersistUser {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    XCTAssertTrue(config.persistUser);
    [config setPersistUser:false];
    XCTAssertFalse(config.persistUser);
    [config setPersistUser:true];
    XCTAssertTrue(config.persistUser);
}

@end
