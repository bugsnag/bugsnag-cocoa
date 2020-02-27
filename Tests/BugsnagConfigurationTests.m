#import "Bugsnag.h"
#import "BugsnagSessionTracker.h"
#import "BugsnagUser.h"

#import <XCTest/XCTest.h>
#import "BugsnagTestConstants.h"
#import "BugsnagConfiguration.h"
#import "BugsnagCrashSentry.h"
#import "BSG_KSCrashType.h"

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
    XCTAssertFalse([config reportOOMs]);
#else
    XCTAssertTrue([config reportOOMs]);
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
    XCTAssertNil(config.currentUser);
    
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
    XCTAssertEqual([config enabledErrorTypes], BSGErrorTypesOOMs | BSGErrorTypesNSExceptions | BSGErrorTypesSignals | BSGErrorTypesMach | BSGErrorTypesCPP);
    
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
}

@end
