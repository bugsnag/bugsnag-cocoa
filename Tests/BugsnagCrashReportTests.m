//
//  BugsnagCrashReportTests.m
//  Bugsnag
//
//  Created by Simon Maynard on 12/1/14.
//
//

#import "BugsnagCrashReport.h"
#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

@interface BugsnagCrashReportTests : XCTestCase
@property BugsnagCrashReport *report;
@end

@implementation BugsnagCrashReportTests

- (void)setUp {
  [super setUp];
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  NSString *path = [bundle pathForResource:@"report" ofType:@"json"];
  NSString *contents = [NSString stringWithContentsOfFile:path
                                                 encoding:NSUTF8StringEncoding
                                                    error:nil];
  NSDictionary *dictionary = [NSJSONSerialization
      JSONObjectWithData:[contents dataUsingEncoding:NSUTF8StringEncoding]
                 options:0
                   error:nil];
  self.report = [[BugsnagCrashReport alloc] initWithKSReport:dictionary];
}

- (void)tearDown {
  [super tearDown];
  self.report = nil;
}

- (void)testReleaseStage {
  XCTAssertEqualObjects(self.report.releaseStage, @"production");
}

- (void)testNotifyReleaseStages {
  XCTAssertEqualObjects(self.report.notifyReleaseStages,
                        (@[ @"production", @"development" ]));
}

@end
