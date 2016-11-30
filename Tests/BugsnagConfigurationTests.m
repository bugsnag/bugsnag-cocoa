#import <XCTest/XCTest.h>
#import "BugsnagConfiguration.h"
#import "Bugsnag.h"


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
    config.notifyReleaseStages = @[@"beta"];
    XCTAssertTrue([config shouldSendReports]);
}

- (void)testNotifyReleaseStagesIncludedInManySends {
    BugsnagConfiguration *config = [BugsnagConfiguration new];
    config.releaseStage = @"beta";
    config.notifyReleaseStages = @[@"beta", @"production"];
    XCTAssertTrue([config shouldSendReports]);
}

- (void)testNotifyReleaseStagesExcludedSkipsSending {
    BugsnagConfiguration *config = [BugsnagConfiguration new];
    config.releaseStage = @"beta";
    config.notifyReleaseStages = @[@"production"];
    XCTAssertFalse([config shouldSendReports]);
}

@end
