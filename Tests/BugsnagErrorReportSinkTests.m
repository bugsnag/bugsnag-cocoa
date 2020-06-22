//
//  BugsnagErrorReportSinkTests.m
//  Bugsnag
//
//  Created by Simon Maynard on 12/1/14.
//
//

#import "BugsnagPlatformConditional.h"

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "Bugsnag.h"
#import "BugsnagHandledState.h"
#import "BugsnagErrorReportSink.h"
#import "BugsnagTestConstants.h"

@interface BugsnagErrorReportSinkTests : XCTestCase
@property NSDictionary *rawReportData;
@property NSDictionary *processedData;
@end

@interface BugsnagClient ()
- (void)start;
@end

@interface BugsnagEvent ()
- (instancetype)initWithKSReport:(NSDictionary *)report;

- (instancetype)initWithApp:(BugsnagAppWithState *)app
                     device:(BugsnagDeviceWithState *)device
               handledState:(BugsnagHandledState *)handledState
                       user:(BugsnagUser *)user
                   metadata:(BugsnagMetadata *)metadata
                breadcrumbs:(NSArray<BugsnagBreadcrumb *> *)breadcrumbs
                     errors:(NSArray<BugsnagError *> *)errors
                    threads:(NSArray<BugsnagThread *> *)threads
                    session:(BugsnagSession *)session;
@end

@interface BugsnagErrorReportSink ()
- (NSDictionary *)prepareEventPayload:(BugsnagEvent *)event;
@end

@implementation BugsnagErrorReportSinkTests

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
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.autoDetectErrors = NO;
    // This value should not appear in the assertions, as it is not equal to
    // the release stage in the serialized report
    config.releaseStage = @"MagicalTestingTime";

    // set a dummy endpoint, avoid hitting production
    config.endpoints = [[BugsnagEndpointConfiguration alloc] initWithNotify:@"http://localhost:1234"
                                                                   sessions:@"http://localhost:1234"];
    BugsnagClient *client = [[BugsnagClient alloc] initWithConfiguration:config];
    [client start];
    BugsnagEvent *report =
            [[BugsnagEvent alloc] initWithKSReport:self.rawReportData];
    self.processedData = [[BugsnagErrorReportSink new] prepareEventPayload:report];
}

- (void)tearDown {
    self.rawReportData = nil;
    self.processedData = nil;
    [super tearDown];
}

- (void)testCorrectTopLevelKeys {
    NSArray *expectedKeys = @[@"apiKey", @"events", @"notifier", @"payloadVersion",];
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
#if BSG_PLATFORM_TVOS
    XCTAssertEqualObjects(name, @"tvOS Bugsnag Notifier");
#elif BSG_PLATFORM_IOS
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
                           @"breadcrumbs",
                           @"context",
                           @"device",
                           @"exceptions",
                           @"metaData",
                           @"severity",
                           @"severityReason",
                           @"threads",
                           @"unhandled",
                           @"user",
                           ];
    XCTAssertEqualObjects(actualKeys, eventKeys);
}

- (void)testEventPayloadVersion {
    NSString *payloadVersion =
    [self.processedData[@"events"] firstObject][@"payloadVersion"];
    XCTAssertNil(payloadVersion);
}

- (void)testEventSeverity {
    NSDictionary *event = [self.processedData[@"events"] firstObject];
    XCTAssertNotNil(event);
    
    NSString *severity = event[@"severity"];
    XCTAssertFalse([event[@"unhandled"] boolValue]);
    XCTAssertEqualObjects(severity, @"info");
}

- (void)testEventBreadcrumbs {
    NSArray *expected =
    [self.rawReportData valueForKeyPath:@"user.state.crash.breadcrumbs"];
    NSArray *breadcrumbs =
    [self.processedData[@"events"] firstObject][@"breadcrumbs"];
    XCTAssertEqual(2, breadcrumbs.count);
    for (int i = 0; i < breadcrumbs.count; i++) {
        XCTAssertEqualObjects(expected[i][@"name"], breadcrumbs[i][@"message"]);
        XCTAssertEqualObjects(expected[i][@"type"], breadcrumbs[i][@"type"]);
        XCTAssertEqualObjects(expected[i][@"timestamp"], breadcrumbs[i][@"timestamp"]);
        XCTAssertEqualObjects(expected[i][@"metadata"], breadcrumbs[i][@"metadata"]);
    }
}

- (void)testEventContext {
    NSArray *expected =
    [self.rawReportData valueForKeyPath:@"user.config.context"];
    NSArray *context = [self.processedData[@"events"] firstObject][@"context"];
    XCTAssertEqualObjects(context, expected);
}

- (void)testEventMetadataApp {
    NSDictionary *app = [[self.processedData valueForKeyPath:@"events.metaData.app"] firstObject];
    NSDictionary *expected = @{@"name" : self.rawReportData[@"system"][@"CFBundleExecutable"]};
    XCTAssertEqualObjects(app, expected);
}

- (void)testEventMetadataUser {
    NSDictionary *user =
    [self.processedData[@"events"] firstObject][@"user"];
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
    XCTAssertNotEqual(0, [stacktrace count]);
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
    XCTAssertTrue(threads.count == 9);
}

- (void)testEventDevice {
    NSDictionary *event = [self.processedData[@"events"] firstObject];
    NSDictionary *device = event[@"device"];
    XCTAssertNotNil(device);
    XCTAssertEqual(14, device.count);

    XCTAssertEqualObjects(device[@"id"], @"f6d519a74213a57f8d052c53febfeee6f856d062");
    XCTAssertEqualObjects(device[@"manufacturer"], @"Apple");
    XCTAssertEqualObjects(device[@"model"], @"x86_64");
    XCTAssertEqualObjects(device[@"modelNumber"], @"MacBookPro11,3");
    XCTAssertEqualObjects(device[@"osName"], @"iPhone OS");
    XCTAssertEqualObjects(device[@"osVersion"], @"8.1");
    XCTAssertEqualObjects(device[@"runtimeVersions"][@"osBuild"], @"14B25");
    XCTAssertEqualObjects(device[@"runtimeVersions"][@"clangVersion"], @"10.0.0 (clang-1000.11.45.5)");
    XCTAssertEqualObjects(device[@"totalMemory"], @15065522176);
    XCTAssertNotNil(device[@"freeDisk"]);
    XCTAssertEqualObjects(device[@"jailbroken"], @YES);
    XCTAssertEqualObjects(device[@"freeMemory"], @742920192);
    XCTAssertEqualObjects(device[@"orientation"], @"unknown");
    XCTAssertEqualObjects(device[@"time"], @"2014-12-02T01:56:13+0000");
}

- (void)testEventApp {
    NSDictionary *event = [self.processedData[@"events"] firstObject];
    NSDictionary *app = event[@"app"];
    XCTAssertNotNil(app);
    XCTAssertEqual(9, app.count);
    XCTAssertEqualObjects(app[@"id"], @"net.hockeyapp.CrashProbeiOS");
    XCTAssertNotNil(app[@"type"]);
    XCTAssertEqualObjects(app[@"version"], @"1.0");
    XCTAssertEqualObjects(app[@"bundleVersion"], @"1");
    XCTAssertEqualObjects(app[@"releaseStage"], @"production");
    XCTAssertEqualObjects(app[@"dsymUUIDs"], @[@"D0A41830-4FD2-3B02-A23B-0741AD4C7F52"]);
    XCTAssertEqualObjects(app[@"duration"], @4000);
    XCTAssertEqualObjects(app[@"durationInForeground"], @2000);
    XCTAssertEqualObjects(app[@"inForeground"], @YES);
}

#pragma mark - handled/unhandled serialisation

- (NSDictionary *)reportFromHandledState:(BugsnagHandledState *)state {
    BugsnagEvent *report = [self generateEvent:state];
    NSDictionary *data = [[BugsnagErrorReportSink new] prepareEventPayload:report];
    return [data[@"events"] firstObject];
}

- (BugsnagEvent *)generateEvent:(BugsnagHandledState *)state {
    BugsnagEvent *report = [[BugsnagEvent alloc] initWithApp:nil
                                                      device:nil
                                                handledState:state
                                                        user:nil
                                                    metadata:nil
                                                 breadcrumbs:@[]
                                                      errors:@[]
                                                     threads:@[]
                                                     session:nil];
    return report;
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
    BugsnagEvent *report = [self generateEvent:state];
    report.severity = BSGSeverityInfo;
    
    NSDictionary *data = [[BugsnagErrorReportSink new] prepareEventPayload:report];
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
