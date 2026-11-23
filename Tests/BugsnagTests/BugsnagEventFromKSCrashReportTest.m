//
//  CreateCrashReportTests.m
//  Tests
//
//  Created by Paul Zabelin on 6/6/19.
//  Copyright © 2019 Bugsnag. All rights reserved.
//

#import "BSGTestCase.h"

#import "Bugsnag+Private.h"
#import "BugsnagEvent+Private.h"
#import "BugsnagHandledState.h"
#import "BSG_KSCrashReport.h"
#import "BSG_KSCrashSentry_Private.h"
#import "BSG_KSJSONCodec.h"

extern void bsg_kscrw_i_prepareReportWriter(BSG_KSCrashReportWriter *, BSG_KSJSONEncodeContext *);
extern void bsg_kscrw_i_writeError(const BSG_KSCrashReportWriter *, const char *, const BSG_KSCrash_SentryContext *);

@interface BugsnagEventFromKSCrashReportTest : BSGTestCase
@property BugsnagEvent *event;
@property NSDictionary *report;
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
    // required due to BugsnagEvent using global singleton
    Bugsnag.client.configuration.bundleVersion = @"3";
    self.report = dictionary;
    self.event = [[BugsnagEvent alloc] initWithKSReport:dictionary];
}

- (void)tearDown {
    [super tearDown];
    self.event = nil;
}

- (void)testReportDepth {
    XCTAssertEqual(7, self.event.depth);
}

- (void)testReadReleaseStage {
    XCTAssertEqualObjects(self.event.app.releaseStage, @"production");
}

- (void)testReadEnabledReleaseStages {
    XCTAssertEqualObjects(self.event.enabledReleaseStages,
                          (@[ @"production", @"development" ]));
}

- (void)testReadEnabledReleaseStagesSends {
    XCTAssertTrue([self.event shouldBeSent]);
}

- (void)testAddMetadataAddsNewTab {
    NSDictionary *metadata = @{@"color" : @"blue", @"beverage" : @"tea"};
    [self.event addMetadata:metadata toSection:@"user prefs"];
    NSDictionary *prefs = [self.event getMetadataFromSection:@"user prefs"];
    XCTAssertEqual(@"blue", prefs[@"color"]);
    XCTAssertEqual(@"tea", prefs[@"beverage"]);
    XCTAssert([prefs count] == 2);
}

- (void)testAddMetadataMergesExistingTab {
    NSDictionary *oldMetadata = @{@"color" : @"red", @"food" : @"carrots"};
    [self.event addMetadata:oldMetadata toSection:@"user prefs"];
    NSDictionary *metadata = @{@"color" : @"blue", @"beverage" : @"tea"};
    [self.event addMetadata:metadata toSection:@"user prefs"];
    NSDictionary *prefs = [self.event getMetadataFromSection:@"user prefs"];
    XCTAssertEqual(@"blue", prefs[@"color"]);
    XCTAssertEqual(@"tea", prefs[@"beverage"]);
    XCTAssertEqual(@"carrots", prefs[@"food"]);
    XCTAssert([prefs count] == 3);
}

- (void)testAddMetadataAddsNewSection {
    [self.event addMetadata:@"blue"
                    withKey:@"color"
                  toSection:@"prefs"];
    NSDictionary *prefs = [self.event getMetadataFromSection:@"prefs"];
    XCTAssertEqual(@"blue", prefs[@"color"]);
}

- (void)testAddMetadataOverridesExistingValue {
    [self.event addMetadata:@"red"
                    withKey:@"color"
                  toSection:@"prefs"];
    [self.event addMetadata:@"blue"
                    withKey:@"color"
                  toSection:@"prefs"];
    NSDictionary *prefs = [self.event getMetadataFromSection:@"prefs"];
    XCTAssertEqual(@"blue", prefs[@"color"]);
}

- (void)testAddMetadataRemovesValue {
    [self.event addMetadata:@"prefs"
                    withKey:@"color"
                  toSection:@"red"];
    [self.event addMetadata:nil
                    withKey:@"color"
                  toSection:@"prefs"];
    NSDictionary *prefs = [self.event getMetadataFromSection:@"prefs"];
    XCTAssertNil(prefs[@"color"]);
}

- (void)testAppVersion {
    NSDictionary *dictionary = [self.event toJsonWithRedactedKeys:nil];
    XCTAssertEqualObjects(dictionary[@"app"][@"version"], @"1.0");
    XCTAssertEqualObjects(dictionary[@"app"][@"bundleVersion"], @"1");
}

- (void)testThreadsPopulated {
    XCTAssertEqual(9, [self.event.threads count]);
    BugsnagThread *thread = self.event.threads[0];
    XCTAssertEqualObjects(@"0", thread.id);
}

#pragma mark - Mach exceptions

static int appendMachErrorJSON(const char *data, size_t length, void *userData) {
    [(__bridge NSMutableData *)userData appendBytes:data length:length];
    return BSG_KSJSON_OK;
}

/// The "crash.error" object that the KSCrash report writer produces for a mach exception.
static NSDictionary * WriteMachError(int type, uint64_t code, uint64_t subcode) {
    BSG_KSCrash_SentryContext crash;
    memset(&crash, 0, sizeof(crash));
    crash.crashType = BSG_KSCrashTypeMachException;
    crash.mach.type = type;
    crash.mach.code = (int64_t)code;
    crash.mach.subcode = (int64_t)subcode;
    NSMutableData *data = [NSMutableData data];
    BSG_KSJSONEncodeContext json;
    bsg_ksjsonbeginEncode(&json, false, appendMachErrorJSON, (__bridge void *)data);
    BSG_KSCrashReportWriter writer;
    bsg_kscrw_i_prepareReportWriter(&writer, &json);
    writer.beginObject(&writer, NULL);
    bsg_kscrw_i_writeError(&writer, "error", &crash);
    writer.endContainer(&writer);
    bsg_ksjsonendEncode(&json);
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:nil][@"error"];
}

/// The fixture report turned into an unhandled mach exception crash report.
- (NSDictionary *)reportWithMachException:(int)type code:(uint64_t)code subcode:(uint64_t)subcode {
    NSMutableDictionary *report = [self.report mutableCopy];
    NSMutableDictionary *crash = [report[@"crash"] mutableCopy];
    crash[@"error"] = WriteMachError(type, code, subcode);
    report[@"crash"] = crash;
    NSMutableDictionary *user = [report[@"user"] mutableCopy];
    [user removeObjectForKey:@"handledState"];
    [user removeObjectForKey:@"depth"];
    report[@"user"] = user;
    return report;
}

static NSArray * FrameAddresses(NSArray<BugsnagStackframe *> *stacktrace) {
    return [stacktrace valueForKeyPath:@"frameAddress"];
}

- (void)testGuardFileDescriptorEvent {
    NSDictionary *report = [self reportWithMachException:EXC_GUARD code:0x4000000100000003ULL subcode:0xfeedfacecafef00dULL];
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:report];
    XCTAssertNotNil(event);

    // Classification
    XCTAssertEqual(event.errors.count, 1);
    XCTAssertEqualObjects(event.errors[0].errorClass, @"EXC_GUARD");
    XCTAssertEqualObjects(event.errors[0].errorMessage, @"GUARD_TYPE_FD violation: kGUARD_EXC_CLOSE");
    XCTAssertEqual(event.errors[0].type, BSGErrorTypeCocoa);
    XCTAssertTrue(event.unhandled);
    XCTAssertEqual(event.severity, BSGSeverityError);
    XCTAssertEqual(event.handledState.severityReasonType, UnhandledException);

    // Raw values preserved in the error metadata
    NSDictionary *mach = [event getMetadataFromSection:@"error" withKey:@"mach"];
    XCTAssertEqualObjects(mach[@"exception"], @(EXC_GUARD));
    XCTAssertEqualObjects(mach[@"code"], @"0x4000000100000003");
    XCTAssertEqualObjects(mach[@"subcode"], @"0xfeedfacecafef00d");
    XCTAssertNil(mach[@"code_name"]);
    XCTAssertEqualObjects(mach[@"guard"][@"type_name"], @"GUARD_TYPE_FD");
    XCTAssertEqualObjects(mach[@"guard"][@"flavor_name"], @"kGUARD_EXC_CLOSE");
    XCTAssertEqualObjects(mach[@"guard"][@"target"], @3);

    // Same crashing-thread frames, in the same order, as any other mach exception
    BugsnagEvent *baseline = [[BugsnagEvent alloc] initWithKSReport:
                              [self reportWithMachException:EXC_BAD_ACCESS code:KERN_INVALID_ADDRESS subcode:0]];
    XCTAssertGreaterThan(event.errors[0].stacktrace.count, 0);
    XCTAssertEqualObjects(FrameAddresses(event.errors[0].stacktrace), FrameAddresses(baseline.errors[0].stacktrace));

    // Serialized payload
    NSDictionary *payload = [event toJsonWithRedactedKeys:nil];
    NSDictionary *exception = payload[@"exceptions"][0];
    XCTAssertEqualObjects(exception[@"errorClass"], @"EXC_GUARD");
    XCTAssertEqualObjects(exception[@"message"], @"GUARD_TYPE_FD violation: kGUARD_EXC_CLOSE");
    XCTAssertEqualObjects(payload[@"unhandled"], @YES);
    XCTAssertEqualObjects(payload[@"severity"], @"error");
    XCTAssertEqualObjects(payload[@"severityReason"][@"type"], @"unhandledException");
    XCTAssertEqualObjects(payload[@"metaData"][@"error"][@"mach"][@"code"], @"0x4000000100000003");
    XCTAssertEqualObjects(payload[@"metaData"][@"error"][@"mach"][@"subcode"], @"0xfeedfacecafef00d");
    XCTAssertEqualObjects(payload[@"metaData"][@"error"][@"mach"][@"guard"][@"flavor"], @1);
    NSArray *payloadFrames = exception[@"stacktrace"];
    XCTAssertEqual(payloadFrames.count, event.errors[0].stacktrace.count);

    // Persisted event JSON round trip (what is stored when delivery fails)
    BugsnagEvent *restored = [[BugsnagEvent alloc] initWithJson:payload];
    NSDictionary *restoredPayload = [restored toJsonWithRedactedKeys:nil];
    XCTAssertEqualObjects(restoredPayload[@"exceptions"], payload[@"exceptions"]);
    XCTAssertEqualObjects(restoredPayload[@"metaData"][@"error"], payload[@"metaData"][@"error"]);
    XCTAssertEqualObjects(restoredPayload[@"severityReason"], payload[@"severityReason"]);
    XCTAssertEqualObjects(restoredPayload[@"unhandled"], @YES);
}

- (void)testGuardMachPortEvent {
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:
                           [self reportWithMachException:EXC_GUARD code:0x2000000100000b03ULL subcode:0x1234]];
    XCTAssertEqualObjects(event.errors[0].errorClass, @"EXC_GUARD");
    XCTAssertEqualObjects(event.errors[0].errorMessage, @"GUARD_TYPE_MACH_PORT violation: kGUARD_EXC_DESTROY");
    NSDictionary *mach = [event getMetadataFromSection:@"error" withKey:@"mach"];
    XCTAssertEqualObjects(mach[@"code"], @"0x2000000100000b03");
    XCTAssertEqualObjects(mach[@"subcode"], @"0x1234");
}

- (void)testGuardVirtualMemoryEvent {
    // Delivered by macOS 26.x for a deallocation spanning an unmapped gap (kGUARD_EXC_DEALLOC_GAP).
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:
                           [self reportWithMachException:EXC_GUARD code:0xa000000100000000ULL subcode:0x1021dc000]];
    XCTAssertEqualObjects(event.errors[0].errorClass, @"EXC_GUARD");
    XCTAssertEqualObjects(event.errors[0].errorMessage, @"GUARD_TYPE_VIRT_MEMORY violation: kGUARD_EXC_DEALLOC_GAP");
}

- (void)testGuardOptionalMachPortEvent {
    // An "optional" port guard (kGUARD_EXC_INVALID_RIGHT) made fatal by TASK_EXC_GUARD_MP_FATAL.
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:
                           [self reportWithMachException:EXC_GUARD code:0x2000010000003103ULL subcode:0]];
    XCTAssertEqualObjects(event.errors[0].errorClass, @"EXC_GUARD");
    XCTAssertEqualObjects(event.errors[0].errorMessage, @"GUARD_TYPE_MACH_PORT violation: kGUARD_EXC_INVALID_RIGHT");
}

- (void)testGuardUnknownSubtypeEvent {
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:
                           [self reportWithMachException:EXC_GUARD code:0x4000008000000007ULL subcode:0]];
    XCTAssertEqualObjects(event.errors[0].errorClass, @"EXC_GUARD");
    XCTAssertEqualObjects(event.errors[0].errorMessage, @"GUARD_TYPE_FD violation: flavor 0x80");

    event = [[BugsnagEvent alloc] initWithKSReport:
             [self reportWithMachException:EXC_GUARD code:0xe0000005ffffffffULL subcode:0x8000000000000000ULL]];
    XCTAssertEqualObjects(event.errors[0].errorClass, @"EXC_GUARD");
    XCTAssertEqualObjects(event.errors[0].errorMessage, @"Guard type 7 violation: flavor 0x5");
    NSDictionary *mach = [event getMetadataFromSection:@"error" withKey:@"mach"];
    XCTAssertEqualObjects(mach[@"code"], @"0xe0000005ffffffff");
    XCTAssertEqualObjects(mach[@"subcode"], @"0x8000000000000000");
}

- (void)testGuardWithoutDecodedFieldsEvent {
    // A report with no "guard" object still classifies correctly.
    NSMutableDictionary *report = [[self reportWithMachException:EXC_GUARD code:0x4000000100000003ULL subcode:0] mutableCopy];
    NSMutableDictionary *crash = [report[@"crash"] mutableCopy];
    NSMutableDictionary *error = [crash[@"error"] mutableCopy];
    NSMutableDictionary *mach = [error[@"mach"] mutableCopy];
    [mach removeObjectForKey:@"guard"];
    error[@"mach"] = mach;
    crash[@"error"] = error;
    report[@"crash"] = crash;
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:report];
    XCTAssertEqualObjects(event.errors[0].errorClass, @"EXC_GUARD");
    XCTAssertEqualObjects(event.errors[0].errorMessage, @"Violated guarded resource protections.");
}

- (void)testGuardMessageIgnoresIncidentalIdentifiers {
    // Different fds and guard identifiers must not change the class or message.
    BugsnagEvent *a = [[BugsnagEvent alloc] initWithKSReport:
                       [self reportWithMachException:EXC_GUARD code:0x4000000100000003ULL subcode:0x1111]];
    BugsnagEvent *b = [[BugsnagEvent alloc] initWithKSReport:
                       [self reportWithMachException:EXC_GUARD code:0x4000000100000009ULL subcode:0x2222]];
    XCTAssertEqualObjects(a.errors[0].errorClass, b.errors[0].errorClass);
    XCTAssertEqualObjects(a.errors[0].errorMessage, b.errors[0].errorMessage);
}

- (void)testBadAccessEventUnchanged {
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:
                           [self reportWithMachException:EXC_BAD_ACCESS code:KERN_INVALID_ADDRESS subcode:0]];
    XCTAssertEqualObjects(event.errors[0].errorClass, @"EXC_BAD_ACCESS");
    XCTAssertEqualObjects(event.errors[0].errorMessage, @"Attempted to dereference null pointer.");
    XCTAssertTrue(event.unhandled);
    NSDictionary *mach = [event getMetadataFromSection:@"error" withKey:@"mach"];
    XCTAssertEqualObjects(mach[@"code_name"], @"KERN_INVALID_ADDRESS");
    XCTAssertNil(mach[@"guard"]);
}

@end
