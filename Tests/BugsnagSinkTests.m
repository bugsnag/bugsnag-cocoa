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
#import "BugsnagKeys.h"

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
    NSArray *expectedKeys = @[ BSGKeyApiKey, BSGKeyEvents, BSGKeyNotifier ];
    NSArray *topKeys = [self.processedData allKeys];
    XCTAssertEqualObjects(
        [topKeys sortedArrayUsingSelector:@selector(compare:)], expectedKeys);
}

- (void)testGetAPIKey {
    NSString *APIKey = self.processedData[BSGKeyApiKey];
    XCTAssertEqualObjects(APIKey, @"apiKeyHere");
}

- (void)testCorrectNotifierKeys {
    NSArray *expectedKeys = @[ BSGKeyName, BSGKeyUrl, BSGKeyVersion ];
    NSArray *notifierKeys = [self.processedData[BSGKeyNotifier] allKeys];
    XCTAssertEqualObjects(
        [notifierKeys sortedArrayUsingSelector:@selector(compare:)],
        expectedKeys);
}

- (void)testNotifierName {
    NSString *name = self.processedData[BSGKeyNotifier][BSGKeyName];
#if TARGET_OS_TV
    XCTAssertEqualObjects(name, @"tvOS Bugsnag Notifier");
#elif TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
    XCTAssertEqualObjects(name, @"iOS Bugsnag Notifier");
#else
    XCTAssertEqualObjects(name, @"OSX Bugsnag Notifier");
#endif
}

- (void)testNotifierDefaultURL {
    NSString *URLPath = self.processedData[BSGKeyNotifier][BSGKeyUrl];
    XCTAssertEqualObjects(URLPath, @"https://github.com/bugsnag/bugsnag-cocoa");
}

- (void)testNotifierVersion {
    NSString *version = self.processedData[BSGKeyNotifier][BSGKeyVersion];
    XCTAssert([version isKindOfClass:[NSString class]]);
}

- (void)testEventCount {
    NSArray *events = self.processedData[BSGKeyEvents];
    XCTAssert(events.count == 1);
}

- (void)testCorrectEventKeys {
    NSArray *actualKeys = [[[self.processedData[BSGKeyEvents] firstObject] allKeys]
        sortedArrayUsingSelector:@selector(compare:)];
    NSArray *eventKeys = @[
        BSGKeyApp,
        BSGKeyAppState,
        BSGKeyBreadcrumbs,
        BSGKeyContext,
        BSGKeyDevice,
        BSGKeyDeviceState,
        @"dsymUUID",
        BSGKeyExceptions,
        BSGKeyMetaData,
        BSGKeyPayloadVersion,
        BSGKeySeverity,
        BSGKeySeverityReason,
        BSGKeyThreads,
        BSGKeyUnhandled,
    ];
    XCTAssertEqualObjects(actualKeys, eventKeys);
}

- (void)testEventReleaseStage {
    NSString *releaseStage =
        [self.processedData[BSGKeyEvents] firstObject][BSGKeyApp][BSGKeyReleaseStage];
    XCTAssertEqualObjects(releaseStage, @"MagicalTestingTime");
}

- (void)testEventPayloadVersion {
    NSString *payloadVersion =
        [self.processedData[BSGKeyEvents] firstObject][BSGKeyPayloadVersion];
    XCTAssertEqualObjects(payloadVersion, @"3");
}

- (void)testEventSeverity {
    NSDictionary *event = [self.processedData[BSGKeyEvents] firstObject];
    XCTAssertNotNil(event);

    NSString *severity = event[BSGKeySeverity];
    XCTAssertTrue([event[BSGKeyUnhandled] boolValue]);
    XCTAssertEqualObjects(severity, BSGKeyError);
}

- (void)testEventBreadcrumbs {
    NSArray *expected =
        [self.rawReportData valueForKeyPath:@"user.state.crash.breadcrumbs"];
    NSArray *breadcrumbs =
        [self.processedData[BSGKeyEvents] firstObject][BSGKeyBreadcrumbs];
    XCTAssertEqualObjects(breadcrumbs, expected);
}

- (void)testEventContext {
    NSArray *expected =
        [self.rawReportData valueForKeyPath:@"user.config.context"];
    NSArray *context = [self.processedData[BSGKeyEvents] firstObject][BSGKeyContext];
    XCTAssertEqualObjects(context, expected);
}

- (void)testEventMetadataUser {
    NSDictionary *user =
        [self.processedData[BSGKeyEvents] firstObject][BSGKeyMetaData][BSGKeyUser];
    NSDictionary *expected =
        @{BSGKeyId : self.rawReportData[BSGKeySystem][@"device_app_hash"]};
    XCTAssertEqualObjects(user, expected);
}

- (void)testEventMetadataCustomTab {
    NSDictionary *customTab =
        [self.processedData[BSGKeyEvents] firstObject][BSGKeyMetaData][@"tab"];
    NSDictionary *expected = @{@"key" : @"value"};
    XCTAssertEqualObjects(customTab, expected);
}

- (void)testEventMetadataErrorAddress {
    id address = [[self.processedData[BSGKeyEvents] firstObject]
        valueForKeyPath:@"metaData.error.address"];
    XCTAssertEqualObjects(address, @0);
}

- (void)testTimestamp {
    id timestamp = [[self.processedData[BSGKeyEvents] firstObject]
        valueForKeyPath:@"deviceState.time"];
    XCTAssertEqualObjects(timestamp, @"2014-12-02T01:56:13Z");
}

- (void)testEventMetadataErrorType {
    id errorType = [[self.processedData[BSGKeyEvents] firstObject]
        valueForKeyPath:@"metaData.error.type"];
    XCTAssertEqualObjects(errorType, BSGKeyUser);
}

- (void)testEventMetadataErrorReason {
    id reason = [[self.processedData[BSGKeyEvents] firstObject]
        valueForKeyPath:@"metaData.error.reason"];
    XCTAssertEqualObjects(reason, @"You should've written more tests!");
}

- (void)testEventMetadataErrorSignal {
    NSDictionary *signal = [[self.processedData[BSGKeyEvents] firstObject]
        valueForKeyPath:@"metaData.error.signal"];
    XCTAssert([signal[BSGKeyName] isEqual:@"SIGABRT"]);
    XCTAssert([signal[BSGKeySignal] isEqual:@6]);
    XCTAssert([signal[@"code"] isEqual:@0]);
}

- (void)testEventMetadataErrorMach {
    NSDictionary *mach = [[self.processedData[BSGKeyEvents] firstObject]
        valueForKeyPath:@"metaData.error.mach"];
    XCTAssert([mach[BSGKeyExceptionName] isEqual:@"EXC_CRASH"]);
    XCTAssert([mach[@"subcode"] isEqual:@0]);
    XCTAssert([mach[@"code"] isEqual:@0]);
    XCTAssert([mach[@"exception"] isEqual:@10]);
}

- (void)testEventMetadataErrorUserReported {
    NSDictionary *reported = [[self.processedData[BSGKeyEvents] firstObject]
        valueForKeyPath:@"metaData.error.user_reported"];
    XCTAssertEqualObjects(reported[BSGKeyName], BSGKeyName);
    XCTAssertEqualObjects(reported[@"line_of_code"], @"");
}

- (void)testBinaryThreadStacktraces {
    NSArray *events = self.processedData[BSGKeyEvents];
    for (NSDictionary *thread in [events firstObject][BSGKeyThreads]) {
        NSArray *stacktrace = thread[BSGKeyStacktrace];

        XCTAssertNotNil(stacktrace);
        for (NSDictionary *frame in stacktrace) {
            XCTAssertNotNil([frame valueForKey:BSGKeyMachoUUID]);
            XCTAssertNotNil([frame valueForKey:BSGKeyMachoFile]);
            XCTAssertNotNil([frame valueForKey:@"frameAddress"]);
            XCTAssertNotNil([frame valueForKey:BSGKeySymbolAddr]);
            XCTAssertNotNil([frame valueForKey:BSGKeyMachoLoadAddr]);
            XCTAssertNotNil([frame valueForKey:BSGKeyMachoVMAddress]);
        }
    }
}

- (void)testEventExceptionCount {
    NSArray *exceptions =
        [self.processedData[BSGKeyEvents] firstObject][BSGKeyExceptions];
    XCTAssert(exceptions.count == 1);
}

- (void)testEventExceptionData {
    NSArray *exceptions =
        [self.processedData[BSGKeyEvents] firstObject][BSGKeyExceptions];
    NSDictionary *exception = [exceptions firstObject];
    XCTAssertEqualObjects(exception[BSGKeyMessage],
                          @"You should've written more tests!");
    XCTAssertEqualObjects(exception[BSGKeyErrorClass], BSGKeyName);
}

- (void)testExceptionStacktrace {
    NSArray *exceptions =
        [self.processedData[BSGKeyEvents] firstObject][BSGKeyExceptions];
    NSArray *stacktrace = [exceptions firstObject][BSGKeyStacktrace];
    XCTAssert([stacktrace count] != 0);
    XCTAssertNotNil(stacktrace);
    for (NSDictionary *frame in stacktrace) {
        XCTAssertNotNil([frame valueForKey:BSGKeyMachoUUID]);
        XCTAssertNotNil([frame valueForKey:BSGKeyMachoFile]);
        XCTAssertNotNil([frame valueForKey:@"frameAddress"]);
        XCTAssertNotNil([frame valueForKey:BSGKeySymbolAddr]);
        XCTAssertNotNil([frame valueForKey:BSGKeyMachoLoadAddr]);
        XCTAssertNotNil([frame valueForKey:BSGKeyMachoVMAddress]);
    }
}

- (void)testEventThreadCount {
    NSArray *threads = [self.processedData[BSGKeyEvents] firstObject][BSGKeyThreads];
    XCTAssert(threads.count == 8);
}

- (void)testEventAppState {
    NSDictionary *event = [self.processedData[BSGKeyEvents] firstObject];
    NSDictionary *appState = event[BSGKeyAppState];
    XCTAssertEqualObjects([appState valueForKey:@"durationInForeground"], @0);
    XCTAssertEqualObjects([appState valueForKey:@"inForeground"], @YES);
    XCTAssertEqualObjects([appState valueForKey:@"duration"], @0);
}

- (void)testEventAppStats {
    NSDictionary *stats =
        [self.processedData[BSGKeyEvents] firstObject][BSGKeyAppState][@"stats"];
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
    return [data[BSGKeyEvents] firstObject];
}

- (void)testHandledSerialization {
    BugsnagHandledState *state =
        [BugsnagHandledState handledStateWithSeverityReason:HandledException];
    NSDictionary *payload = [self reportFromHandledState:state];

    XCTAssertEqualObjects(BSGKeyWarning, payload[BSGKeySeverity]);
    XCTAssertFalse([payload[BSGKeyUnhandled] boolValue]);

    NSDictionary *severityReason = payload[BSGKeySeverityReason];
    XCTAssertNotNil(severityReason);

    NSString *expected =
        [BugsnagHandledState stringFromSeverityReason:HandledException];
    XCTAssertEqualObjects(expected, severityReason[BSGKeyType]);
    XCTAssertNil(severityReason[BSGKeyAttributes]);
}

- (void)testUnhandledSerialization {
    BugsnagHandledState *state =
        [BugsnagHandledState handledStateWithSeverityReason:UnhandledException];
    NSDictionary *payload = [self reportFromHandledState:state];

    XCTAssertEqualObjects(BSGKeyError, payload[BSGKeySeverity]);
    XCTAssertTrue([payload[BSGKeyUnhandled] boolValue]);

    NSDictionary *severityReason = payload[BSGKeySeverityReason];
    XCTAssertNotNil(severityReason);

    NSString *expected =
        [BugsnagHandledState stringFromSeverityReason:UnhandledException];
    XCTAssertEqualObjects(expected, severityReason[BSGKeyType]);
    XCTAssertNil(severityReason[BSGKeyAttributes]);
}

- (void)testPromiseRejectionSerialization {
    BugsnagHandledState *state =
        [BugsnagHandledState handledStateWithSeverityReason:PromiseRejection];
    NSDictionary *payload = [self reportFromHandledState:state];

    XCTAssertEqualObjects(BSGKeyError, payload[BSGKeySeverity]);
    XCTAssertTrue([payload[BSGKeyUnhandled] boolValue]);

    NSDictionary *severityReason = payload[BSGKeySeverityReason];
    XCTAssertNotNil(severityReason);

    NSString *expected =
        [BugsnagHandledState stringFromSeverityReason:PromiseRejection];
    XCTAssertEqualObjects(expected, severityReason[BSGKeyType]);
    XCTAssertNil(severityReason[BSGKeyAttributes]);
}

- (void)testUserSpecifiedSerialisation {
    BugsnagHandledState *state = [BugsnagHandledState
        handledStateWithSeverityReason:UserSpecifiedSeverity];
    NSDictionary *payload = [self reportFromHandledState:state];

    XCTAssertEqualObjects(BSGKeyWarning, payload[BSGKeySeverity]);
    XCTAssertFalse([payload[BSGKeyUnhandled] boolValue]);

    NSDictionary *severityReason = payload[BSGKeySeverityReason];
    XCTAssertNotNil(severityReason);

    NSString *expected =
        [BugsnagHandledState stringFromSeverityReason:UserSpecifiedSeverity];
    XCTAssertEqualObjects(expected, severityReason[BSGKeyType]);
    XCTAssertNil(severityReason[BSGKeyAttributes]);
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
    NSDictionary *payload = [data[BSGKeyEvents] firstObject];

    XCTAssertEqualObjects(BSGKeyInfo, payload[BSGKeySeverity]);
    XCTAssertFalse([payload[BSGKeyUnhandled] boolValue]);

    NSDictionary *severityReason = payload[BSGKeySeverityReason];
    XCTAssertNotNil(severityReason);

    NSString *expected =
        [BugsnagHandledState stringFromSeverityReason:UserCallbackSetSeverity];
    XCTAssertEqualObjects(expected, severityReason[BSGKeyType]);
    XCTAssertNil(severityReason[BSGKeyAttributes]);
}

- (void)testHandledErrorSerialization {
    BugsnagHandledState *state =
        [BugsnagHandledState handledStateWithSeverityReason:HandledError
                                                   severity:BSGSeverityWarning
                                                  attrValue:@"test"];
    NSDictionary *payload = [self reportFromHandledState:state];

    XCTAssertEqualObjects(BSGKeyWarning, payload[BSGKeySeverity]);
    XCTAssertFalse([payload[BSGKeyUnhandled] boolValue]);

    NSDictionary *severityReason = payload[BSGKeySeverityReason];
    XCTAssertNotNil(severityReason);

    NSString *expected =
        [BugsnagHandledState stringFromSeverityReason:HandledError];
    XCTAssertEqualObjects(expected, severityReason[BSGKeyType]);

    NSDictionary *attrs = severityReason[BSGKeyAttributes];
    XCTAssertNil(attrs);
}

- (void)testSignalSerialization {
    BugsnagHandledState *state =
        [BugsnagHandledState handledStateWithSeverityReason:Signal
                                                   severity:BSGSeverityError
                                                  attrValue:@"test"];
    NSDictionary *payload = [self reportFromHandledState:state];

    XCTAssertEqualObjects(BSGKeyError, payload[BSGKeySeverity]);
    XCTAssertTrue([payload[BSGKeyUnhandled] boolValue]);

    NSDictionary *severityReason = payload[BSGKeySeverityReason];
    XCTAssertNotNil(severityReason);

    NSString *expected = [BugsnagHandledState stringFromSeverityReason:Signal];
    XCTAssertEqualObjects(expected, severityReason[BSGKeyType]);

    NSDictionary *attrs = severityReason[BSGKeyAttributes];
    XCTAssertNotNil(attrs);
    XCTAssertEqual(1, [attrs count]);
    XCTAssertEqualObjects(@"test", attrs[@"signalType"]);
}

@end
