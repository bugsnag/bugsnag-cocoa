#import "Bugsnag.h"
#import "BugsnagConfiguration.h"
#import "BugsnagUser.h"
#import <XCTest/XCTest.h>

@interface BugsnagConfigurationTests : XCTestCase
@end

@implementation BugsnagConfigurationTests

- (void)testDefaultSessionNotNil {
    BugsnagConfiguration *config = [BugsnagConfiguration new];
    XCTAssertNotNil(config.session);
}

- (void)testNotifyReleaseStagesDefaultSends {
    BugsnagConfiguration *config = [BugsnagConfiguration new];
    XCTAssertTrue([config shouldSendReports]);
}

- (void)testNotifyReleaseStagesNilSends {
    BugsnagConfiguration *config = [BugsnagConfiguration new];
    config.releaseStage = @"beta";
    config.notifyReleaseStages = nil;
    XCTAssertTrue([config shouldSendReports]);
}

- (void)testNotifyReleaseStagesEmptySends {
    BugsnagConfiguration *config = [BugsnagConfiguration new];
    config.releaseStage = @"beta";
    config.notifyReleaseStages = @[];
    XCTAssertTrue([config shouldSendReports]);
}

- (void)testNotifyReleaseStagesIncludedSends {
    BugsnagConfiguration *config = [BugsnagConfiguration new];
    config.releaseStage = @"beta";
    config.notifyReleaseStages = @[ @"beta" ];
    XCTAssertTrue([config shouldSendReports]);
}

- (void)testNotifyReleaseStagesIncludedInManySends {
    BugsnagConfiguration *config = [BugsnagConfiguration new];
    config.releaseStage = @"beta";
    config.notifyReleaseStages = @[ @"beta", @"production" ];
    XCTAssertTrue([config shouldSendReports]);
}

- (void)testNotifyReleaseStagesExcludedSkipsSending {
    BugsnagConfiguration *config = [BugsnagConfiguration new];
    config.releaseStage = @"beta";
    config.notifyReleaseStages = @[ @"production" ];
    XCTAssertFalse([config shouldSendReports]);
}

- (void)testDefaultSessionConfig {
    BugsnagConfiguration *config = [BugsnagConfiguration new];
    XCTAssertFalse([config shouldAutoCaptureSessions]);
}

- (void)testErrorApiHeaders {
    BugsnagConfiguration *config = [BugsnagConfiguration new];
    NSDictionary *headers = [config errorApiHeaders];
    XCTAssertEqualObjects(config.apiKey, headers[@"Bugsnag-Api-Key"]);
    XCTAssertNotNil(headers[@"Bugsnag-Sent-At"]);
    XCTAssertNotNil(headers[@"Bugsnag-Payload-Version"]);
}

- (void)testSessionApiHeaders {
    BugsnagConfiguration *config = [BugsnagConfiguration new];
    NSDictionary *headers = [config sessionApiHeaders];
    XCTAssertEqualObjects(config.apiKey, headers[@"Bugsnag-Api-Key"]);
    XCTAssertNotNil(headers[@"Bugsnag-Sent-At"]);
    XCTAssertNotNil(headers[@"Bugsnag-Payload-Version"]);
}

- (void)testSessionEndpoints {
    BugsnagConfiguration *config = [BugsnagConfiguration new];
    
    // Default endpoints
    XCTAssertEqualObjects([NSURL URLWithString:@"https://sessions.bugsnag.com"], config.sessionEndpoint);
    
    // Setting an endpoint
    NSURL *endpoint = [NSURL URLWithString:@"http://localhost:8000"];
    config.sessionEndpoint = endpoint;
    XCTAssertEqualObjects(endpoint, config.sessionEndpoint);
}

- (void)testUser {
    BugsnagConfiguration *config = [BugsnagConfiguration new];
    XCTAssertNil(config.currentUser);
    
    [config setUser:@"123" withName:@"foo" andEmail:@"test@example.com"];
    
    XCTAssertEqualObjects(@"123", config.currentUser.userId);
    XCTAssertEqualObjects(@"foo", config.currentUser.name);
    XCTAssertEqualObjects(@"test@example.com", config.currentUser.emailAddress);
    
}

@end
