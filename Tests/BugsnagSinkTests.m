//
//  BugsnagSinkTests.m
//  Bugsnag
//
//  Created by Simon Maynard on 12/1/14.
//
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "Bugsnag.h"
#import "BugsnagCrashReport.h"
#import "BugsnagHandledState.h"
#import "BugsnagSink.h"

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
    self.rawReportData = [NSJSONSerialization JSONObjectWithData:contentData
                                                         options:0
                                                           error:nil];
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
    NSArray *expectedKeys = @[@"events", @"notifier"];
    NSArray *topKeys = [self.processedData allKeys];
    XCTAssertEqualObjects(
                          [topKeys sortedArrayUsingSelector:@selector(compare:)], expectedKeys);
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
                           @"severityReason",
                           @"threads",
                           @"unhandled",
                           ];
    XCTAssertEqualObjects(actualKeys, eventKeys);
}

- (void)testEventReleaseStage {
    NSString *releaseStage =
    [self.processedData[@"events"] firstObject][@"app"][@"releaseStage"];
    XCTAssertEqualObjects(releaseStage, @"MagicalTestingTime");
}

- (void)testEventPayloadVersion {
    NSString *payloadVersion =
    [self.processedData[@"events"] firstObject][@"payloadVersion"];
    XCTAssertEqualObjects(payloadVersion, @"4");
}

- (void)testEventSeverity {
    NSDictionary *event = [self.processedData[@"events"] firstObject];
    XCTAssertNotNil(event);
    
    NSString *severity = event[@"severity"];
    XCTAssertTrue([event[@"unhandled"] boolValue]);
    XCTAssertEqualObjects(severity, @"error");
}

- (void)testEventBreadcrumbs {
    NSArray *expected =
    [self.rawReportData valueForKeyPath:@"user.state.crash.breadcrumbs"];
    NSArray *breadcrumbs =
    [self.processedData[@"events"] firstObject][@"breadcrumbs"];
    XCTAssertEqualObjects(breadcrumbs, expected);
}

- (void)testEventContext {
    NSArray *expected =
    [self.rawReportData valueForKeyPath:@"user.config.context"];
    NSArray *context = [self.processedData[@"events"] firstObject][@"context"];
    XCTAssertEqualObjects(context, expected);
}

- (void)testEventMetadataUser {
    NSDictionary *user =
    [self.processedData[@"events"] firstObject][@"metaData"][@"user"];
    NSDictionary *expected =
    @{@"id" : self.rawReportData[@"system"][@"device_app_hash"]};
    XCTAssertEqualObjects(user, expected);
}

- (void)testEventMetadataCustomTab {
    NSDictionary *customTab =
    [self.processedData[@"events"] firstObject][@"metaData"][@"tab"];
    NSDictionary *expected = @{@"key" : @"value"};
    XCTAssertEqualObjects(customTab, expected);
}

- (void)testEventMetadataErrorAddress {
    id address = [[self.processedData[@"events"] firstObject]
                  valueForKeyPath:@"metaData.error.address"];
    XCTAssertEqualObjects(address, @0);
}

- (void)testTimestamp {
    id timestamp = [[self.processedData[@"events"] firstObject]
                    valueForKeyPath:@"deviceState.time"];
    XCTAssertEqualObjects(timestamp, @"2014-12-02T01:56:13Z");
}

- (void)testEventMetadataErrorType {
    id errorType = [[self.processedData[@"events"] firstObject]
                    valueForKeyPath:@"metaData.error.type"];
    XCTAssertEqualObjects(errorType, @"user");
}

- (void)testEventMetadataErrorReason {
    id reason = [[self.processedData[@"events"] firstObject]
                 valueForKeyPath:@"metaData.error.reason"];
    XCTAssertEqualObjects(reason, @"You should've written more tests!");
}

- (void)testEventMetadataErrorSignal {
    NSDictionary *signal = [[self.processedData[@"events"] firstObject]
                            valueForKeyPath:@"metaData.error.signal"];
    XCTAssert([signal[@"name"] isEqual:@"SIGABRT"]);
    XCTAssert([signal[@"signal"] isEqual:@6]);
    XCTAssert([signal[@"code"] isEqual:@0]);
}

- (void)testEventMetadataErrorMach {
    NSDictionary *mach = [[self.processedData[@"events"] firstObject]
                          valueForKeyPath:@"metaData.error.mach"];
    XCTAssert([mach[@"exception_name"] isEqual:@"EXC_CRASH"]);
    XCTAssert([mach[@"subcode"] isEqual:@0]);
    XCTAssert([mach[@"code"] isEqual:@0]);
    XCTAssert([mach[@"exception"] isEqual:@10]);
}

- (void)testEventMetadataErrorUserReported {
    NSDictionary *reported = [[self.processedData[@"events"] firstObject]
                              valueForKeyPath:@"metaData.error.user_reported"];
    XCTAssertEqualObjects(reported[@"name"], @"name");
    XCTAssertEqualObjects(reported[@"line_of_code"], @"");
}

- (void)testBinaryThreadStacktraces {
    NSArray *events = self.processedData[@"events"];
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
    NSArray *exceptions =
    [self.processedData[@"events"] firstObject][@"exceptions"];
    XCTAssert(exceptions.count == 1);
}

- (void)testEventExceptionData {
    NSArray *exceptions =
    [self.processedData[@"events"] firstObject][@"exceptions"];
    NSDictionary *exception = [exceptions firstObject];
    XCTAssertEqualObjects(exception[@"message"],
                          @"You should've written more tests!");
    XCTAssertEqualObjects(exception[@"errorClass"], @"name");
}

- (void)testExceptionStacktrace {
    NSArray *exceptions =
    [self.processedData[@"events"] firstObject][@"exceptions"];
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
    NSDictionary *stats =
    [self.processedData[@"events"] firstObject][@"appState"][@"stats"];
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

#pragma mark - handled/unhandled serialisation

- (NSDictionary *)reportFromHandledState:(BugsnagHandledState *)state {
    BugsnagCrashReport *report =
    [[BugsnagCrashReport alloc] initWithErrorName:@"TestError"
                                     errorMessage:@"Error for testing"
                                    configuration:[BugsnagConfiguration new]
                                         metaData:[NSDictionary new]
                                     handledState:state];
    
    NSDictionary *data = [[BugsnagSink new] getBodyFromReports:@[ report ]];
    return [data[@"events"] firstObject];
}

- (void)testHandledSerialization {
    BugsnagHandledState *state =
    [BugsnagHandledState handledStateWithSeverityReason:HandledException];
    NSDictionary *payload = [self reportFromHandledState:state];
    
    XCTAssertEqualObjects(@"warning", payload[@"severity"]);
    XCTAssertFalse([payload[@"unhandled"] boolValue]);
    
    NSDictionary *severityReason = payload[@"severityReason"];
    XCTAssertNotNil(severityReason);
    
    NSString *expected =
    [BugsnagHandledState stringFromSeverityReason:HandledException];
    XCTAssertEqualObjects(expected, severityReason[@"type"]);
    XCTAssertNil(severityReason[@"attributes"]);
}

- (void)testUnhandledSerialization {
    BugsnagHandledState *state =
    [BugsnagHandledState handledStateWithSeverityReason:UnhandledException];
    NSDictionary *payload = [self reportFromHandledState:state];
    
    XCTAssertEqualObjects(@"error", payload[@"severity"]);
    XCTAssertTrue([payload[@"unhandled"] boolValue]);
    
    NSDictionary *severityReason = payload[@"severityReason"];
    XCTAssertNotNil(severityReason);
    
    NSString *expected =
    [BugsnagHandledState stringFromSeverityReason:UnhandledException];
    XCTAssertEqualObjects(expected, severityReason[@"type"]);
    XCTAssertNil(severityReason[@"attributes"]);
}

- (void)testPromiseRejectionSerialization {
    BugsnagHandledState *state =
    [BugsnagHandledState handledStateWithSeverityReason:PromiseRejection];
    NSDictionary *payload = [self reportFromHandledState:state];
    
    XCTAssertEqualObjects(@"error", payload[@"severity"]);
    XCTAssertTrue([payload[@"unhandled"] boolValue]);
    
    NSDictionary *severityReason = payload[@"severityReason"];
    XCTAssertNotNil(severityReason);
    
    NSString *expected =
    [BugsnagHandledState stringFromSeverityReason:PromiseRejection];
    XCTAssertEqualObjects(expected, severityReason[@"type"]);
    XCTAssertNil(severityReason[@"attributes"]);
}

- (void)testUserSpecifiedSerialisation {
    BugsnagHandledState *state = [BugsnagHandledState
                                  handledStateWithSeverityReason:UserSpecifiedSeverity];
    NSDictionary *payload = [self reportFromHandledState:state];
    
    XCTAssertEqualObjects(@"warning", payload[@"severity"]);
    XCTAssertFalse([payload[@"unhandled"] boolValue]);
    
    NSDictionary *severityReason = payload[@"severityReason"];
    XCTAssertNotNil(severityReason);
    
    NSString *expected =
    [BugsnagHandledState stringFromSeverityReason:UserSpecifiedSeverity];
    XCTAssertEqualObjects(expected, severityReason[@"type"]);
    XCTAssertNil(severityReason[@"attributes"]);
}

- (void)testCallbackSpecified {
    BugsnagHandledState *state =
    [BugsnagHandledState handledStateWithSeverityReason:HandledException];
    BugsnagCrashReport *report =
    [[BugsnagCrashReport alloc] initWithErrorName:@"TestError"
                                     errorMessage:@"Error for testing"
                                    configuration:[BugsnagConfiguration new]
                                         metaData:[NSDictionary new]
                                     handledState:state];
    report.severity = BSGSeverityInfo;
    
    NSDictionary *data = [[BugsnagSink new] getBodyFromReports:@[ report ]];
    NSDictionary *payload = [data[@"events"] firstObject];
    
    XCTAssertEqualObjects(@"info", payload[@"severity"]);
    XCTAssertFalse([payload[@"unhandled"] boolValue]);
    
    NSDictionary *severityReason = payload[@"severityReason"];
    XCTAssertNotNil(severityReason);
    
    NSString *expected =
    [BugsnagHandledState stringFromSeverityReason:UserCallbackSetSeverity];
    XCTAssertEqualObjects(expected, severityReason[@"type"]);
    XCTAssertNil(severityReason[@"attributes"]);
}

- (void)testHandledErrorSerialization {
    BugsnagHandledState *state =
    [BugsnagHandledState handledStateWithSeverityReason:HandledError
                                               severity:BSGSeverityWarning
                                              attrValue:@"test"];
    NSDictionary *payload = [self reportFromHandledState:state];
    
    XCTAssertEqualObjects(@"warning", payload[@"severity"]);
    XCTAssertFalse([payload[@"unhandled"] boolValue]);
    
    NSDictionary *severityReason = payload[@"severityReason"];
    XCTAssertNotNil(severityReason);
    
    NSString *expected =
    [BugsnagHandledState stringFromSeverityReason:HandledError];
    XCTAssertEqualObjects(expected, severityReason[@"type"]);
    
    NSDictionary *attrs = severityReason[@"attributes"];
    XCTAssertNil(attrs);
}

- (void)testSignalSerialization {
    BugsnagHandledState *state =
    [BugsnagHandledState handledStateWithSeverityReason:Signal
                                               severity:BSGSeverityError
                                              attrValue:@"test"];
    NSDictionary *payload = [self reportFromHandledState:state];
    
    XCTAssertEqualObjects(@"error", payload[@"severity"]);
    XCTAssertTrue([payload[@"unhandled"] boolValue]);
    
    NSDictionary *severityReason = payload[@"severityReason"];
    XCTAssertNotNil(severityReason);
    
    NSString *expected = [BugsnagHandledState stringFromSeverityReason:Signal];
    XCTAssertEqualObjects(expected, severityReason[@"type"]);
    
    NSDictionary *attrs = severityReason[@"attributes"];
    XCTAssertNotNil(attrs);
    XCTAssertEqual(1, [attrs count]);
    XCTAssertEqualObjects(@"test", attrs[@"signalType"]);
}

@end
