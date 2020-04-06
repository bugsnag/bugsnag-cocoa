//
//  CreateCrashReportTests.m
//  Tests
//
//  Created by Paul Zabelin on 6/6/19.
//  Copyright © 2019 Bugsnag. All rights reserved.
//

@import XCTest;
@import Bugsnag;

@interface BugsnagEventFromKSCrashReportTest : XCTestCase
@property BugsnagEvent *report;
@end

@interface BugsnagEvent ()
- (NSDictionary *_Nonnull)toJson;
- (BOOL)shouldBeSent;
@property(readwrite, copy, nullable) NSArray *enabledReleaseStages;
@property(readwrite) NSUInteger depth;
@end

@implementation BugsnagEventFromKSCrashReportTest

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
    self.report = [[BugsnagEvent alloc] initWithKSReport:dictionary];
}

- (void)tearDown {
    [super tearDown];
    self.report = nil;
}

- (void)testReportDepth {
    XCTAssertEqual(7, self.report.depth);
}

- (void)testReadReleaseStage {
    XCTAssertEqualObjects(self.report.app.releaseStage, @"production");
}

- (void)testReadEnabledReleaseStages {
    XCTAssertEqualObjects(self.report.enabledReleaseStages,
                          (@[ @"production", @"development" ]));
}

- (void)testReadEnabledReleaseStagesSends {
    XCTAssertTrue([self.report shouldBeSent]);
}

- (void)testAddMetadataAddsNewTab {
    NSDictionary *metadata = @{@"color" : @"blue", @"beverage" : @"tea"};
    [self.report addMetadata:metadata toSection:@"user prefs"];
    NSDictionary *prefs = [self.report getMetadataFromSection:@"user prefs"];
    XCTAssertEqual(@"blue", prefs[@"color"]);
    XCTAssertEqual(@"tea", prefs[@"beverage"]);
    XCTAssert([prefs count] == 2);
}

- (void)testAddMetadataMergesExistingTab {
    NSDictionary *oldMetadata = @{@"color" : @"red", @"food" : @"carrots"};
    [self.report addMetadata:oldMetadata toSection:@"user prefs"];
    NSDictionary *metadata = @{@"color" : @"blue", @"beverage" : @"tea"};
    [self.report addMetadata:metadata toSection:@"user prefs"];
    NSDictionary *prefs = [self.report getMetadataFromSection:@"user prefs"];
    XCTAssertEqual(@"blue", prefs[@"color"]);
    XCTAssertEqual(@"tea", prefs[@"beverage"]);
    XCTAssertEqual(@"carrots", prefs[@"food"]);
    XCTAssert([prefs count] == 3);
}

- (void)testAddMetadataAddsNewSection {
    [self.report addMetadata:@"blue"
                     withKey:@"color"
                   toSection:@"prefs"];
    NSDictionary *prefs = [self.report getMetadataFromSection:@"prefs"];
    XCTAssertEqual(@"blue", prefs[@"color"]);
}

- (void)testAddMetadataOverridesExistingValue {
    [self.report addMetadata:@"red"
                     withKey:@"color"
                   toSection:@"prefs"];
    [self.report addMetadata:@"blue"
                     withKey:@"color"
                   toSection:@"prefs"];
    NSDictionary *prefs = [self.report getMetadataFromSection:@"prefs"];
    XCTAssertEqual(@"blue", prefs[@"color"]);
}

- (void)testAddMetadataRemovesValue {
    [self.report addMetadata:@"prefs"
                     withKey:@"color"
                   toSection:@"red"];
    [self.report addMetadata:nil
                     withKey:@"color"
                   toSection:@"prefs"];
    NSDictionary *prefs = [self.report getMetadataFromSection:@"prefs"];
    XCTAssertNil(prefs[@"color"]);
}

- (void)testAppVersion {
    NSDictionary *dictionary = [self.report toJson];
    XCTAssertEqualObjects(@"1.0", dictionary[@"app"][@"version"]);
    XCTAssertEqualObjects(@"1", dictionary[@"app"][@"bundleVersion"]);
}

@end
