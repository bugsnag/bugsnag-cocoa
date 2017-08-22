//
//  BugsnagSinkTests.m
//  Bugsnag
//
//  Created by Simon Maynard on 12/1/14.
//
//

#import "Bugsnag.h"
#import "BugsnagCrashReport.h"
#import "BugsnagSink.h"
#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

@interface BugsnagSinkTests : XCTestCase
@property NSDictionary *rawReportData;
@property NSDictionary *processedData;
@end

@interface BugsnagSink ()
- (NSDictionary *)getBodyFromReports:(NSArray *)reports;
@end

@implementation BugsnagSinkTests

- (void)setUp {
  [super setUp];
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  NSString *path = [bundle pathForResource:@"report" ofType:@"json"];
  NSString *contents = [NSString stringWithContentsOfFile:path
                                                 encoding:NSUTF8StringEncoding
                                                    error:nil];
  NSData *contentData = [contents dataUsingEncoding:NSUTF8StringEncoding];
  self.rawReportData =
      [NSJSONSerialization JSONObjectWithData:contentData options:0 error:nil];
  BugsnagConfiguration *config = [BugsnagConfiguration new];
  config.autoNotify = NO;
  config.apiKey = @"apiKeyHere";
  config.releaseStage = @"MagicalTestingTime";
  config.notifyURL = nil;
  [Bugsnag startBugsnagWithConfiguration:config];
  BugsnagCrashReport *report =
      [[BugsnagCrashReport alloc] initWithKSReport:self.rawReportData];
  self.processedData = [[BugsnagSink new] getBodyFromReports:@[ report ]];
}

- (void)tearDown {
  self.rawReportData = nil;
  self.processedData = nil;
  [super tearDown];
}

- (void)testCorrectTopLevelKeys {
  NSArray *expectedKeys = @[ @"apiKey", @"events", @"notifier" ];
  NSArray *topKeys = [self.processedData allKeys];
  XCTAssertEqualObjects([topKeys sortedArrayUsingSelector:@selector(compare:)],
                        expectedKeys);
}

- (void)testGetAPIKey {
  NSString *APIKey = self.processedData[@"apiKey"];
  XCTAssertEqualObjects(APIKey, @"apiKeyHere");
}

- (void)testCorrectNotifierKeys {
  NSArray *expectedKeys = @[ @"name", @"url", @"version" ];
  NSArray *notifierKeys = [self.processedData[@"notifier"] allKeys];
  XCTAssertEqualObjects(
      [notifierKeys sortedArrayUsingSelector:@selector(compare:)],
      expectedKeys);
}

- (void)testNotifierName {
  NSString *name = self.processedData[@"notifier"][@"name"];
#if TARGET_OS_TV
  XCTAssertEqualObjects(name, @"tvOS Bugsnag Notifier");
#elif TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
  XCTAssertEqualObjects(name, @"iOS Bugsnag Notifier");
#else
  XCTAssertEqualObjects(name, @"OSX Bugsnag Notifier");
#endif
}

- (void)testNotifierDefaultURL {
  NSString *URLPath = self.processedData[@"notifier"][@"url"];
  XCTAssertEqualObjects(URLPath, @"https://github.com/bugsnag/bugsnag-cocoa");
}

- (void)testNotifierVersion {
  NSString *version = self.processedData[@"notifier"][@"version"];
  XCTAssert([version isKindOfClass:[NSString class]]);
}

- (void)testEventCount {
  NSArray *events = self.processedData[@"events"];
  XCTAssert(events.count == 1);
}

- (void)testCorrectEventKeys {
  NSArray *actualKeys = [[[self.processedData[@"events"] firstObject] allKeys]
      sortedArrayUsingSelector:@selector(compare:)];
  NSArray *eventKeys = @[
    @"app",
    @"appState",
    @"breadcrumbs",
    @"context",
    @"device",
    @"deviceState",
    @"dsymUUID",
    @"exceptions",
    @"metaData",
    @"payloadVersion",
    @"severity",
    @"threads"
  ];
  XCTAssertEqualObjects(actualKeys, eventKeys);
}

- (void)testEventReleaseStage {
  NSString *releaseStage = [self.processedData[@"events"] firstObject][@"app"][@"releaseStage"];
  XCTAssertEqualObjects(releaseStage, @"MagicalTestingTime");
}

- (void)testEventPayloadVersion {
  NSString *payloadVersion = [self.processedData[@"events"] firstObject][@"payloadVersion"];
  XCTAssertEqualObjects(payloadVersion, @"3");
}

- (void)testEventSeverity {
  NSString *expected =
      [self.rawReportData valueForKeyPath:@"user.state.crash.severity"];
  NSString *severity = [self.processedData[@"events"] firstObject][@"severity"];
  XCTAssertEqualObjects(severity, expected);
}

- (void)testEventBreadcrumbs {
  NSArray *expected =
      [self.rawReportData valueForKeyPath:@"user.state.crash.breadcrumbs"];
  NSArray *breadcrumbs = [self.processedData[@"events"] firstObject][@"breadcrumbs"];
  XCTAssertEqualObjects(breadcrumbs, expected);
}

- (void)testEventContext {
  NSArray *expected =
      [self.rawReportData valueForKeyPath:@"user.config.context"];
  NSArray *context = [self.processedData[@"events"] firstObject][@"context"];
  XCTAssertEqualObjects(context, expected);
}

- (void)testEventMetadataUser {
  NSDictionary *user = [self.processedData[@"events"] firstObject][@"metaData"][@"user"];
  NSDictionary *expected = @{
    @"id" : self.rawReportData[@"system"][@"device_app_hash"]
  };
  XCTAssertEqualObjects(user, expected);
}

- (void)testEventMetadataCustomTab {
  NSDictionary *customTab = [self.processedData[@"events"] firstObject][@"metaData"][@"tab"];
  NSDictionary *expected = @{ @"key" : @"value" };
  XCTAssertEqualObjects(customTab, expected);
}

- (void)testEventMetadataErrorAddress {
  id address =
      [[self.processedData[@"events"] firstObject] valueForKeyPath:@"metaData.error.address"];
  XCTAssertEqualObjects(address, @0);
}

- (void)testTimestamp {
    id timestamp = [[self.processedData[@"events"] firstObject] valueForKeyPath:@"deviceState.time"];
    XCTAssertEqualObjects(timestamp, @"2014-12-02T01:56:13Z");
}

- (void)testEventMetadataErrorType {
  id errorType = [[self.processedData[@"events"] firstObject] valueForKeyPath:@"metaData.error.type"];
  XCTAssertEqualObjects(errorType, @"user");
}

- (void)testEventMetadataErrorReason {
  id reason = [[self.processedData[@"events"] firstObject] valueForKeyPath:@"metaData.error.reason"];
  XCTAssertEqualObjects(reason, @"You should've written more tests!");
}

- (void)testEventMetadataErrorSignal {
  NSDictionary *signal =
      [[self.processedData[@"events"] firstObject] valueForKeyPath:@"metaData.error.signal"];
  XCTAssert([signal[@"name"] isEqual:@"SIGABRT"]);
  XCTAssert([signal[@"signal"] isEqual:@6]);
  XCTAssert([signal[@"code"] isEqual:@0]);
}

- (void)testEventMetadataErrorMach {
  NSDictionary *mach =
      [[self.processedData[@"events"] firstObject] valueForKeyPath:@"metaData.error.mach"];
  XCTAssert([mach[@"exception_name"] isEqual:@"EXC_CRASH"]);
  XCTAssert([mach[@"subcode"] isEqual:@0]);
  XCTAssert([mach[@"code"] isEqual:@0]);
  XCTAssert([mach[@"exception"] isEqual:@10]);
}

- (void)testEventMetadataErrorUserReported {
  NSDictionary *reported =
      [[self.processedData[@"events"] firstObject] valueForKeyPath:@"metaData.error.user_reported"];
  XCTAssertEqualObjects(reported[@"name"], @"name");
  XCTAssertEqualObjects(reported[@"line_of_code"], @"");
}

- (void)testBinaryThreadStacktraces {
    NSArray *events =  self.processedData[@"events"];
    for (NSDictionary *thread in [events firstObject][@"threads"]) {
        NSArray *stacktrace = thread[@"stacktrace"];
        
        XCTAssertNotNil(stacktrace);
        for (NSDictionary *frame in stacktrace) {
            XCTAssertNotNil([frame valueForKey:@"machoUUID"]);
            XCTAssertNotNil([frame valueForKey:@"machoFile"]);
            XCTAssertNotNil([frame valueForKey:@"frameAddress"]);
            XCTAssertNotNil([frame valueForKey:@"symbolAddress"]);
            XCTAssertNotNil([frame valueForKey:@"machoLoadAddress"]);
            XCTAssertNotNil([frame valueForKey:@"machoVMAddress"]);
        }
    }
}

- (void)testEventExceptionCount {
  NSArray *exceptions = [self.processedData[@"events"] firstObject][@"exceptions"];
  XCTAssert(exceptions.count == 1);
}

- (void)testEventExceptionData {
  NSArray *exceptions = [self.processedData[@"events"] firstObject][@"exceptions"];
  NSDictionary *exception = [exceptions firstObject];
  XCTAssertEqualObjects(exception[@"message"],
                        @"You should've written more tests!");
  XCTAssertEqualObjects(exception[@"errorClass"], @"name");
}

- (void)testExceptionStacktrace {
  NSArray *exceptions = [self.processedData[@"events"] firstObject][@"exceptions"];
  NSArray *stacktrace = [exceptions firstObject][@"stacktrace"];
  XCTAssert([stacktrace count] != 0);
  XCTAssertNotNil(stacktrace);
  for (NSDictionary *frame in stacktrace) {
    XCTAssertNotNil([frame valueForKey:@"machoUUID"]);
    XCTAssertNotNil([frame valueForKey:@"machoFile"]);
    XCTAssertNotNil([frame valueForKey:@"frameAddress"]);
    XCTAssertNotNil([frame valueForKey:@"symbolAddress"]);
    XCTAssertNotNil([frame valueForKey:@"machoLoadAddress"]);
    XCTAssertNotNil([frame valueForKey:@"machoVMAddress"]);
  }
}

- (void)testEventThreadCount {
  NSArray *threads = [self.processedData[@"events"] firstObject][@"threads"];
  XCTAssert(threads.count == 8);
}

- (void)testEventAppState {
  NSDictionary *event = [self.processedData[@"events"] firstObject];
  NSDictionary *appState = event[@"appState"];
  XCTAssertEqualObjects([appState valueForKey:@"durationInForeground"], @0);
  XCTAssertEqualObjects([appState valueForKey:@"inForeground"], @YES);
  XCTAssertEqualObjects([appState valueForKey:@"duration"], @0);
}

- (void)testEventAppStats {
  NSDictionary *stats = [self.processedData[@"events"] firstObject][@"appState"][@"stats"];
  XCTAssertEqualObjects(stats, (@{
                          @"background_time_since_last_crash" : @0,
                          @"active_time_since_launch" : @0,
                          @"sessions_since_last_crash" : @1,
                          @"launches_since_last_crash" : @1,
                          @"active_time_since_last_crash" : @0,
                          @"sessions_since_launch" : @1,
                          @"application_active" : @NO,
                          @"application_in_foreground" : @YES,
                          @"background_time_since_launch" : @0
                        }));
}

@end
