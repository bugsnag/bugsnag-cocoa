//
//  BugsnagCrashReportTests.m
//  Bugsnag
//
//  Created by Simon Maynard on 12/1/14.
//
//

#import "Bugsnag.h"
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

- (void)testReadReleaseStage {
  XCTAssertEqualObjects(self.report.releaseStage, @"production");
}

- (void)testReadNotifyReleaseStages {
  XCTAssertEqualObjects(self.report.notifyReleaseStages,
                        (@[ @"production", @"development" ]));
}

- (void)testReadNotifyReleaseStagesSends {
    XCTAssertTrue([self.report shouldBeSent]);
}

- (void)testAddMetadataAddsNewTab {
    NSDictionary *metadata = @{ @"color": @"blue", @"beverage": @"tea" };
    [self.report addMetadata:metadata toTabWithName:@"user prefs"];
    NSDictionary *prefs = self.report.metaData[@"user prefs"];
    XCTAssertEqual(@"blue", prefs[@"color"]);
    XCTAssertEqual(@"tea", prefs[@"beverage"]);
    XCTAssert([prefs count] == 2);
}

- (void)testAddMetadataMergesExistingTab {
    NSDictionary *oldMetadata = @{ @"color": @"red", @"food": @"carrots" };
    [self.report addMetadata:oldMetadata toTabWithName:@"user prefs"];
    NSDictionary *metadata = @{ @"color": @"blue", @"beverage": @"tea" };
    [self.report addMetadata:metadata toTabWithName:@"user prefs"];
    NSDictionary *prefs = self.report.metaData[@"user prefs"];
    XCTAssertEqual(@"blue", prefs[@"color"]);
    XCTAssertEqual(@"tea", prefs[@"beverage"]);
    XCTAssertEqual(@"carrots", prefs[@"food"]);
    XCTAssert([prefs count] == 3);
}

- (void)testAddAttributeAddsNewTab {
    [self.report addAttribute:@"color" withValue:@"blue" toTabWithName:@"prefs"];
    NSDictionary *prefs = self.report.metaData[@"prefs"];
    XCTAssertEqual(@"blue", prefs[@"color"]);
}

- (void)testAddAttributeOverridesExistingValue {
    [self.report addAttribute:@"color" withValue:@"red" toTabWithName:@"prefs"];
    [self.report addAttribute:@"color" withValue:@"blue" toTabWithName:@"prefs"];
    NSDictionary *prefs = self.report.metaData[@"prefs"];
    XCTAssertEqual(@"blue", prefs[@"color"]);
}

- (void)testAddAttributeRemovesValue {
    [self.report addAttribute:@"color" withValue:@"red" toTabWithName:@"prefs"];
    [self.report addAttribute:@"color" withValue:nil toTabWithName:@"prefs"];
    NSDictionary *prefs = self.report.metaData[@"prefs"];
    XCTAssertNil(prefs[@"color"]);
}

- (void)testNotifyReleaseStagesSendsFromConfig {
    BugsnagConfiguration *config = [BugsnagConfiguration new];
    config.notifyReleaseStages = @[@"foo"];
    config.releaseStage = @"foo";
    BugsnagCrashReport *report = [[BugsnagCrashReport alloc] initWithErrorName:@"Bad error"
                                                                  errorMessage:@"it was so bad"
                                                                 configuration:config
                                                                      metaData:@{}
                                                                      severity:BSGSeverityWarning];
    XCTAssertTrue([report shouldBeSent]);
}

- (void)testNotifyReleaseStagesSkipsSendFromConfig {
    BugsnagConfiguration *config = [BugsnagConfiguration new];
    config.notifyReleaseStages = @[@"foo", @"bar"];
    config.releaseStage = @"not foo or bar";
    BugsnagCrashReport *report = [[BugsnagCrashReport alloc] initWithErrorName:@"Bad error"
                                                                  errorMessage:@"it was so bad"
                                                                 configuration:config
                                                                      metaData:@{}
                                                                      severity:BSGSeverityWarning];
    XCTAssertFalse([report shouldBeSent]);
}

@end
