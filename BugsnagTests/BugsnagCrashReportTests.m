//
//  BugsnagCrashReportTests.m
//  Bugsnag
//
//  Created by Simon Maynard on 12/1/14.
//
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "BugsnagCrashReport.h"

@interface BugsnagCrashReportTests : XCTestCase
@property BugsnagCrashReport *report;
@end

@implementation BugsnagCrashReportTests

- (void)setUp {
    [super setUp];
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"report" ofType:@"json"];
    NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:[contents dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    self.report = [[BugsnagCrashReport alloc] initWithKSReport:dictionary];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testReleaseStage {
    XCTAssertEqualObjects(self.report.releaseStage, @"production");
}

- (void)testNotifyReleaseStages {
    XCTAssertEqualObjects(self.report.notifyReleaseStages, (@[ @"production", @"development" ]));
}

- (void)testContext {
    XCTAssertEqualObjects(self.report.context, @"contextString");
}

- (void)testBinaryImages {
    XCTAssert(self.report.binaryImages.count == 149);
}

- (void)testThreads {
    XCTAssert(self.report.threads.count == 9);
}

- (void)testError {
    XCTAssertEqualObjects(self.report.error, (@{
                                                @"mach": @{
                                                        @"code": @0,
                                                        @"exception_name": @"EXC_CRASH",
                                                        @"subcode": @0,
                                                        @"exception": @10
                                                        },
                                                @"user_reported": @{
                                                        @"name": @"name",
                                                        @"line_of_code": @""
                                                        },
                                                @"reason": @"reason",
                                                @"signal": @{
                                                        @"name": @"SIGABRT",
                                                        @"signal": @6,
                                                        @"code": @0
                                                        },
                                                @"type": @"user",
                                                @"address": @0
                                                }));
}

- (void)testErrorType {
    XCTAssertEqualObjects(self.report.errorType, @"user");
}

- (void)testErrorClass {
    XCTAssertEqualObjects(self.report.errorClass, @"name");
}

- (void)testErrorMessage {
    XCTAssertEqualObjects(self.report.errorMessage, @"reason");
}

- (void)testSeverity {
    XCTAssertEqualObjects(self.report.severity, @"warning");
}

- (void)testDSYMUUID {
    XCTAssertEqualObjects(self.report.dsymUUID, @"D0A41830-4FD2-3B02-A23B-0741AD4C7F52");
}

- (void)testDeviceAppHash {
    XCTAssertEqualObjects(self.report.deviceAppHash, @"f6d519a74213a57f8d052c53febfeee6f856d062");
}

- (void)testDepth {
    XCTAssert(self.report.depth == 4);
}

- (void)testMetaData {
    XCTAssertEqualObjects(self.report.metaData, (@{@"tab": @{@"key": @"value"}}));
}

- (void)testAppStats {
    XCTAssertEqualObjects(self.report.appStats, (@{@"background_time_since_last_crash": @0,
                                                   @"active_time_since_launch": @0,
                                                   @"sessions_since_last_crash": @1,
                                                   @"launches_since_last_crash": @1,
                                                   @"active_time_since_last_crash": @0,
                                                   @"sessions_since_launch": @1,
                                                   @"application_active": @NO,
                                                   @"application_in_foreground": @YES,
                                                   @"background_time_since_launch": @0}));
}
@end
