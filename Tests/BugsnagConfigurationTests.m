#import "Bugsnag.h"
#import "BugsnagSessionTracker.h"
#import "BugsnagUser.h"

#import <XCTest/XCTest.h>
#import "BugsnagTestConstants.h"

@interface BugsnagConfigurationTests : XCTestCase
@end

@implementation BugsnagConfigurationTests

- (void)testDefaultSessionNotNil {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertNotNil(config.session);
}

- (void)testNotifyReleaseStagesDefaultSends {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertTrue([config shouldSendReports]);
}

- (void)testNotifyReleaseStagesNilSends {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.releaseStage = @"beta";
    config.notifyReleaseStages = nil;
    XCTAssertTrue([config shouldSendReports]);
}

- (void)testNotifyReleaseStagesEmptySends {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.releaseStage = @"beta";
    config.notifyReleaseStages = @[];
    XCTAssertTrue([config shouldSendReports]);
}

- (void)testNotifyReleaseStagesIncludedSends {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.releaseStage = @"beta";
    config.notifyReleaseStages = @[ @"beta" ];
    XCTAssertTrue([config shouldSendReports]);
}

- (void)testNotifyReleaseStagesIncludedInManySends {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.releaseStage = @"beta";
    config.notifyReleaseStages = @[ @"beta", @"production" ];
    XCTAssertTrue([config shouldSendReports]);
}

- (void)testNotifyReleaseStagesExcludedSkipsSending {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.releaseStage = @"beta";
    config.notifyReleaseStages = @[ @"production" ];
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

- (void)testDefaultSessionConfig {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertTrue([config autoTrackSessions]);
}

-(void)testDesignatedInitializer {
    NSString *apiKey = @"shortAPIKey";
    XCTAssertThrows([[BugsnagConfiguration alloc] initWithApiKey:apiKey]);
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertNotNil(config);
    XCTAssertTrue([[config apiKey] isEqualToString:DUMMY_APIKEY_32CHAR_1]);
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
    XCTAssertFalse([config reportOOMs]);
#else
    XCTAssertTrue([config reportOOMs]);
#endif
}

- (void)testErrorApiHeaders {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    NSDictionary *headers = [config errorApiHeaders];
    XCTAssertEqualObjects(config.apiKey, headers[@"Bugsnag-Api-Key"]);
    XCTAssertNotNil(headers[@"Bugsnag-Sent-At"]);
    XCTAssertNotNil(headers[@"Bugsnag-Payload-Version"]);
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

- (void)testUser {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    XCTAssertNil(config.currentUser);
    
    [config setUser:@"123" withName:@"foo" andEmail:@"test@example.com"];
    
    XCTAssertEqualObjects(@"123", config.currentUser.userId);
    XCTAssertEqualObjects(@"foo", config.currentUser.name);
    XCTAssertEqualObjects(@"test@example.com", config.currentUser.emailAddress);
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

@end
