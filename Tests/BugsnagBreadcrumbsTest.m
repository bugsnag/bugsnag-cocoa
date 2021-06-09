//
//  BugsnagBreadcrumbsTest.m
//  Bugsnag
//
//  Created by Delisa Mason on 9/16/15.
//
//

#import "BSG_KSJSONCodec.h"
#import "Bugsnag.h"
#import "BugsnagClient+Private.h"
#import "BugsnagBreadcrumb+Private.h"
#import "BugsnagBreadcrumbs.h"
#import "BugsnagTestConstants.h"

#import <XCTest/XCTest.h>

// Defined in BSG_KSCrashReport.c
void bsg_kscrw_i_prepareReportWriter(BSG_KSCrashReportWriter *const writer, BSG_KSJSONEncodeContext *const context);

static int addJSONData(const char *data, size_t length, NSMutableData *userData) {
    [userData appendBytes:data length:length];
    return BSG_KSJSON_OK;
}

static id JSONObject(void (^ block)(BSG_KSCrashReportWriter *writer)) {
    NSMutableData *data = [NSMutableData data];
    BSG_KSJSONEncodeContext encodeContext;
    BSG_KSCrashReportWriter reportWriter;
    bsg_kscrw_i_prepareReportWriter(&reportWriter, &encodeContext);
    bsg_ksjsonbeginEncode(&encodeContext, false, (BSG_KSJSONAddDataFunc)addJSONData, (__bridge void *)data);
    block(&reportWriter);
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
}

@interface BugsnagBreadcrumbsTest : XCTestCase
@property(nonatomic, strong) BugsnagBreadcrumbs *crumbs;
@end

@interface BugsnagBreadcrumbs (Testing)
- (NSArray<NSDictionary *> *)arrayValue;
@end

void awaitBreadcrumbSync(BugsnagBreadcrumbs *crumbs) {
    // This used to wait for the queue to finish adding breadcrumb(s). Not
    // required in current implementation but leaving this function in case
    // it needs to be reintroduced.
}

BSGBreadcrumbType BSGBreadcrumbTypeFromString(NSString *value);

@implementation BugsnagBreadcrumbsTest

- (void)setUp {
    [super setUp];
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    BugsnagBreadcrumbs *crumbs = [[BugsnagBreadcrumbs alloc] initWithConfiguration:config];
    [crumbs removeAllBreadcrumbs];
    [crumbs addBreadcrumb:@"Launch app"];
    [crumbs addBreadcrumb:@"Tap button"];
    [crumbs addBreadcrumb:@"Close tutorial"];
    self.crumbs = crumbs;
}

- (void)testDefaultCount {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    BugsnagBreadcrumbs *crumbs = [[BugsnagBreadcrumbs alloc] initWithConfiguration:config];
    [crumbs removeAllBreadcrumbs];
    XCTAssertTrue(crumbs.breadcrumbs.count == 0);
}

- (void)testMaxBreadcrumbs {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.maxBreadcrumbs = 3;
    self.crumbs = [[BugsnagBreadcrumbs alloc] initWithConfiguration:config];
    [self.crumbs removeAllBreadcrumbs];
    [self.crumbs addBreadcrumb:@"Crumb 1"];
    [self.crumbs addBreadcrumb:@"Crumb 2"];
    [self.crumbs addBreadcrumb:@"Crumb 3"];
    [self.crumbs addBreadcrumb:@"Clear notifications"];
    awaitBreadcrumbSync(self.crumbs);
    NSArray<BugsnagBreadcrumb *> *breadcrumbs = self.crumbs.breadcrumbs;
    XCTAssertEqual(breadcrumbs.count, 3);
    XCTAssertEqualObjects(breadcrumbs[0].message, @"Crumb 2");
    XCTAssertEqualObjects(breadcrumbs[1].message, @"Crumb 3");
    XCTAssertEqualObjects(breadcrumbs[2].message, @"Clear notifications");
}

- (void)testBreadcrumbsInvalidKey {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    BugsnagOnBreadcrumbBlock crumbBlock = ^(BugsnagBreadcrumb * _Nonnull crumb) {
        return YES;
    };
    [config addOnBreadcrumbBlock:crumbBlock];

    self.crumbs = [[BugsnagBreadcrumbs alloc] initWithConfiguration:config];
    [self.crumbs addBreadcrumbWithBlock:^(BugsnagBreadcrumb *_Nonnull crumb) {
        crumb.type = BSGBreadcrumbTypeState;
        crumb.message = @"message";
        crumb.metadata = @{@123 : @"would raise exception"};
    }];
    awaitBreadcrumbSync(self.crumbs);
}

- (void)testEmptyCapacity {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.maxBreadcrumbs = 0;
    self.crumbs = [[BugsnagBreadcrumbs alloc] initWithConfiguration:config];
    [self.crumbs removeAllBreadcrumbs];
    [self.crumbs addBreadcrumb:@"Clear notifications"];
    XCTAssertEqual(self.crumbs.breadcrumbs.count, 0);
}

- (void)testArrayValue {
    awaitBreadcrumbSync(self.crumbs);
    NSArray *value = [self.crumbs arrayValue];
    XCTAssertNotNil(value);
    XCTAssertTrue(value.count == 3);
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'SSSX5";
    for (int i = 0; i < value.count; i++) {
        NSDictionary *item = value[i];
        XCTAssertTrue([item isKindOfClass:[NSDictionary class]]);
        XCTAssertEqualObjects(item[@"type"], @"manual");
        XCTAssertTrue([[formatter dateFromString:item[@"timestamp"]]
                       isKindOfClass:[NSDate class]]);
    }
    XCTAssertEqualObjects(value[0][@"name"], @"Launch app");
    XCTAssertEqualObjects(value[1][@"name"], @"Tap button");
    XCTAssertEqualObjects(value[2][@"name"], @"Close tutorial");
}

- (void)testStateType {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    BugsnagBreadcrumbs *crumbs = [[BugsnagBreadcrumbs alloc] initWithConfiguration:config];
    [crumbs addBreadcrumbWithBlock:^(BugsnagBreadcrumb *_Nonnull crumb) {
        crumb.type = BSGBreadcrumbTypeState;
        crumb.message = @"Rotated Menu";
        crumb.metadata = @{@"direction" : @"right"};
    }];
    awaitBreadcrumbSync(self.crumbs);
    NSArray *value = [crumbs arrayValue];
    XCTAssertEqualObjects(value[0][@"metaData"][@"direction"], @"right");
    XCTAssertEqualObjects(value[0][@"name"], @"Rotated Menu");
    XCTAssertEqualObjects(value[0][@"type"], @"state");
}

- (void)testPersistentCrumbManual {
    NSArray<NSDictionary *> *value = [self.crumbs cachedBreadcrumbs];
    XCTAssertEqual(value.count, 3);
    XCTAssertEqualObjects(value[0][@"type"], @"manual");
    XCTAssertEqualObjects(value[0][@"name"], @"Launch app");
    XCTAssertNotNil(value[0][@"timestamp"]);
    XCTAssertEqualObjects(value[1][@"type"], @"manual");
    XCTAssertEqualObjects(value[1][@"name"], @"Tap button");
    XCTAssertNotNil(value[1][@"timestamp"]);
    XCTAssertEqualObjects(value[2][@"type"], @"manual");
    XCTAssertEqualObjects(value[2][@"name"], @"Close tutorial");
    XCTAssertNotNil(value[2][@"timestamp"]);
}

- (void)testPersistentCrumbCustom {
    [self.crumbs addBreadcrumbWithBlock:^(BugsnagBreadcrumb *crumb) {
        crumb.message = @"Initiate sequence";
        crumb.metadata = @{ @"captain": @"Bob"};
        crumb.type = BSGBreadcrumbTypeState;
    }];
    NSArray<NSDictionary *> *value = [self.crumbs cachedBreadcrumbs];
    XCTAssertEqual(value.count, 4);
    XCTAssertEqualObjects(value[3][@"type"], @"state");
    XCTAssertEqualObjects(value[3][@"name"], @"Initiate sequence");
    XCTAssertEqualObjects(value[3][@"metaData"][@"captain"], @"Bob");
    XCTAssertNotNil(value[3][@"timestamp"]);
}

- (void)testDefaultDiscardByType {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    self.crumbs = [[BugsnagBreadcrumbs alloc] initWithConfiguration:config];
    [self.crumbs addBreadcrumbWithBlock:^(BugsnagBreadcrumb *_Nonnull crumb) {
        crumb.type = BSGBreadcrumbTypeState;
        crumb.message = @"state";
    }];
    [self.crumbs addBreadcrumbWithBlock:^(BugsnagBreadcrumb *_Nonnull crumb) {
        crumb.type = BSGBreadcrumbTypeUser;
        crumb.message = @"user";
    }];
    [self.crumbs addBreadcrumbWithBlock:^(BugsnagBreadcrumb *_Nonnull crumb) {
        crumb.type = BSGBreadcrumbTypeLog;
        crumb.message = @"log";
    }];
    [self.crumbs addBreadcrumbWithBlock:^(BugsnagBreadcrumb *_Nonnull crumb) {
        crumb.type = BSGBreadcrumbTypeError;
        crumb.message = @"error";
    }];
    [self.crumbs addBreadcrumbWithBlock:^(BugsnagBreadcrumb *_Nonnull crumb) {
        crumb.type = BSGBreadcrumbTypeProcess;
        crumb.message = @"process";
    }];
    [self.crumbs addBreadcrumbWithBlock:^(BugsnagBreadcrumb *_Nonnull crumb) {
        crumb.type = BSGBreadcrumbTypeRequest;
        crumb.message = @"request";
    }];
    [self.crumbs addBreadcrumbWithBlock:^(BugsnagBreadcrumb *_Nonnull crumb) {
        crumb.type = BSGBreadcrumbTypeNavigation;
        crumb.message = @"navigation";
    }];
    [self.crumbs addBreadcrumbWithBlock:^(BugsnagBreadcrumb *_Nonnull crumb) {
        crumb.message = @"manual";
    }];
    awaitBreadcrumbSync(self.crumbs);
    NSArray *value = [self.crumbs arrayValue];
    XCTAssertEqual(8, value.count);
    XCTAssertEqualObjects(value[0][@"type"], @"state");
    XCTAssertEqualObjects(value[1][@"type"], @"user");
    XCTAssertEqualObjects(value[2][@"type"], @"log");
    XCTAssertEqualObjects(value[3][@"type"], @"error");
    XCTAssertEqualObjects(value[4][@"type"], @"process");
    XCTAssertEqualObjects(value[5][@"type"], @"request");
    XCTAssertEqualObjects(value[6][@"type"], @"navigation");
    XCTAssertEqualObjects(value[7][@"type"], @"manual");
}

- (void)testAlwaysAllowManual {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    self.crumbs = [[BugsnagBreadcrumbs alloc] initWithConfiguration:config];
    [self.crumbs removeAllBreadcrumbs];
    [self.crumbs addBreadcrumb:@"this is a test"];
    awaitBreadcrumbSync(self.crumbs);
    NSArray *value = [self.crumbs arrayValue];
    XCTAssertEqual(1, value.count);
    XCTAssertEqualObjects(value[0][@"type"], @"manual");
    XCTAssertEqualObjects(value[0][@"name"], @"this is a test");
}

/**
 * enabledBreadcrumbTypes filtering only happens on the client.  The BugsnagBreadcrumbs container is
 * private and assumes filtering is already configured.
 */
- (void)testDiscardByTypeDoesNotApply {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    self.crumbs = [[BugsnagBreadcrumbs alloc] initWithConfiguration:config];
    [self.crumbs removeAllBreadcrumbs];
    // Don't discard this
    [self.crumbs addBreadcrumbWithBlock:^(BugsnagBreadcrumb *_Nonnull crumb) {
        crumb.type = BSGBreadcrumbTypeState;
        crumb.message = @"state";
    }];
    awaitBreadcrumbSync(self.crumbs);
    NSArray *value = [self.crumbs arrayValue];
    XCTAssertEqual(1, value.count);
}

- (void)testConvertBreadcrumbTypeFromString {
    XCTAssertEqual(BSGBreadcrumbTypeState, BSGBreadcrumbTypeFromString(@"state"));
    XCTAssertEqual(BSGBreadcrumbTypeUser, BSGBreadcrumbTypeFromString(@"user"));
    XCTAssertEqual(BSGBreadcrumbTypeManual, BSGBreadcrumbTypeFromString(@"manual"));
    XCTAssertEqual(BSGBreadcrumbTypeNavigation, BSGBreadcrumbTypeFromString(@"navigation"));
    XCTAssertEqual(BSGBreadcrumbTypeProcess, BSGBreadcrumbTypeFromString(@"process"));
    XCTAssertEqual(BSGBreadcrumbTypeLog, BSGBreadcrumbTypeFromString(@"log"));
    XCTAssertEqual(BSGBreadcrumbTypeRequest, BSGBreadcrumbTypeFromString(@"request"));
    XCTAssertEqual(BSGBreadcrumbTypeError, BSGBreadcrumbTypeFromString(@"error"));

    XCTAssertEqual(BSGBreadcrumbTypeManual, BSGBreadcrumbTypeFromString(@"random"));
    XCTAssertEqual(BSGBreadcrumbTypeManual, BSGBreadcrumbTypeFromString(@"4"));
}

- (void)testBreadcrumbsBeforeDate {
    [self.crumbs removeAllBreadcrumbs];
    [self.crumbs addBreadcrumb:@"Crumb 1"];
    [self.crumbs addBreadcrumb:@"Crumb 2"];
    [self.crumbs addBreadcrumb:@"Crumb 3"];
    XCTAssertEqual([self.crumbs breadcrumbsBeforeDate:[NSDate date]].count, 3);
    XCTAssertEqual([self.crumbs breadcrumbsBeforeDate:[NSDate distantPast]].count, 0);
}

- (void)testBreadcrumbFromDict {
    XCTAssertNil([BugsnagBreadcrumb breadcrumbFromDict:@{}]);
    XCTAssertNil([BugsnagBreadcrumb breadcrumbFromDict:@{@"metadata": @{}}]);
    XCTAssertNil([BugsnagBreadcrumb breadcrumbFromDict:@{@"timestamp": @""}]);
    BugsnagBreadcrumb *crumb = [BugsnagBreadcrumb breadcrumbFromDict:@{
        @"timestamp": @"0",
        @"metaData": @{},
        @"message":@"cache break",
        @"type":@"process"}];
    XCTAssertNil(crumb);

    crumb = [BugsnagBreadcrumb breadcrumbFromDict:@{
        @"timestamp": @"2020-02-14T16:12:22+001",
        @"metaData": @{},
        @"message":@"",
        @"type":@"process"}];
    XCTAssertNil(crumb);

    crumb = [BugsnagBreadcrumb breadcrumbFromDict:@{
        @"timestamp": @"2020-02-14T16:12:23+001",
        @"metaData": @{},
        @"message":@"cache break",
        @"type":@"process"}];
    XCTAssertNotNil(crumb);
    XCTAssertEqualObjects(@{}, crumb.metadata);
    XCTAssertEqualObjects(@"cache break", crumb.message);
    XCTAssertEqual(BSGBreadcrumbTypeProcess, crumb.type);

    crumb = [BugsnagBreadcrumb breadcrumbFromDict:@{
        @"timestamp": @"2020-02-14T16:14:23+001",
        @"metaData": @{@"foo": @"bar"},
        @"message":@"cache break",
        @"type":@"log"}];
    XCTAssertNotNil(crumb);
    XCTAssertEqualObjects(@"cache break", crumb.message);
    XCTAssertEqualObjects(@{@"foo": @"bar"}, crumb.metadata);
    XCTAssertEqual(BSGBreadcrumbTypeLog, crumb.type);
}

/**
 * Test that breadcrumb operations with no callback block work as expected.  1 of 2
 */
- (void)testCallbackFreeConstructors2 {
    // Prevent sending events
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    [configuration addOnSendErrorBlock:^BOOL(BugsnagEvent *_Nonnull event) {
        return false;
    }];
    BugsnagClient *client = [[BugsnagClient alloc] initWithConfiguration:configuration];
    [client start];

    NSDictionary *md1 = @{ @"x" : @"y"};
    NSDictionary *md2 = @{ @"a" : @"b",
                           @"c" : @42};

    [client leaveBreadcrumbWithMessage:@"manual message" metadata:md1 andType:BSGBreadcrumbTypeManual];
    [client leaveBreadcrumbWithMessage:@"log message" metadata:md2 andType:BSGBreadcrumbTypeLog];
    [client leaveBreadcrumbWithMessage:@"navigation message" metadata:md1 andType:BSGBreadcrumbTypeNavigation];
    [client leaveBreadcrumbWithMessage:@"process message" metadata:md2 andType:BSGBreadcrumbTypeProcess];
    [client leaveBreadcrumbWithMessage:@"request message" metadata:md1 andType:BSGBreadcrumbTypeRequest];
    [client leaveBreadcrumbWithMessage:@"state message" metadata:md2 andType:BSGBreadcrumbTypeState];
    [client leaveBreadcrumbWithMessage:@"user message" metadata:md1 andType:BSGBreadcrumbTypeUser];

    NSDictionary *bc0 = [client.breadcrumbs arrayValue][0];
    NSDictionary *bc1 = [client.breadcrumbs arrayValue][1];
    NSDictionary *bc2 = [client.breadcrumbs arrayValue][2];
    NSDictionary *bc3 = [client.breadcrumbs arrayValue][3];
    NSDictionary *bc4 = [client.breadcrumbs arrayValue][4];
    NSDictionary *bc5 = [client.breadcrumbs arrayValue][5];
    NSDictionary *bc6 = [client.breadcrumbs arrayValue][6];
    NSDictionary *bc7 = [client.breadcrumbs arrayValue][7];

    XCTAssertEqual(client.breadcrumbs.breadcrumbs.count, 8);

    XCTAssertEqualObjects(bc0[@"type"], @"state");
    XCTAssertEqualObjects(bc0[@"name"], @"Bugsnag loaded");
    XCTAssertEqual([bc0[@"metaData"] count], 0);

    XCTAssertEqual([bc1[@"metaData"] count], 1);
    XCTAssertEqual([bc3[@"metaData"] count], 1);
    XCTAssertEqual([bc5[@"metaData"] count], 1);
    XCTAssertEqual([bc7[@"metaData"] count], 1);

    XCTAssertEqual([bc2[@"metaData"] count], 2);
    XCTAssertEqual([bc4[@"metaData"] count], 2);
    XCTAssertEqual([bc6[@"metaData"] count], 2);
    
    XCTAssertEqualObjects(bc1[@"name"], @"manual message");
    XCTAssertEqualObjects(bc1[@"type"], @"manual");

    XCTAssertEqualObjects(bc2[@"name"], @"log message");
    XCTAssertEqualObjects(bc2[@"type"], @"log");

    XCTAssertEqualObjects(bc3[@"name"], @"navigation message");
    XCTAssertEqualObjects(bc3[@"type"], @"navigation");

    XCTAssertEqualObjects(bc4[@"name"], @"process message");
    XCTAssertEqualObjects(bc4[@"type"], @"process");

    XCTAssertEqualObjects(bc5[@"name"], @"request message");
    XCTAssertEqualObjects(bc5[@"type"], @"request");

    XCTAssertEqualObjects(bc6[@"name"], @"state message");
    XCTAssertEqualObjects(bc6[@"type"], @"state");

    XCTAssertEqualObjects(bc7[@"name"], @"user message");
    XCTAssertEqualObjects(bc7[@"type"], @"user");
}

/**
 * Test that breadcrumb operations with no callback block work as expected.  2 of 2
 */
- (void)testCallbackFreeConstructors3 {
    // Prevent sending events
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    [configuration addOnSendErrorBlock:^BOOL(BugsnagEvent *_Nonnull event) {
        return false;
    }];
    BugsnagClient *client = [[BugsnagClient alloc] initWithConfiguration:configuration];
    [client start];
    
    [client leaveBreadcrumbWithMessage:@"message1"];
    [client leaveBreadcrumbWithMessage:@"message2" metadata:nil andType:BSGBreadcrumbTypeUser];
    
    NSDictionary *bc1 = [client.breadcrumbs arrayValue][1];
    NSDictionary *bc2 = [client.breadcrumbs arrayValue][2];

    XCTAssertEqualObjects(bc1[@"name"], @"message1");
    XCTAssertEqualObjects(bc2[@"name"], @"message2");
    
    XCTAssertEqual([bc1[@"metaData"] count], 0);
    XCTAssertEqual([bc2[@"metaData"] count], 0);
}

- (void)testCrashReportWriter {
    NSDictionary<NSString *, id> *object = JSONObject(^(BSG_KSCrashReportWriter *writer) {
        writer->beginObject(writer, "");
        BugsnagBreadcrumbsWriteCrashReport(writer);
        writer->endContainer(writer);
    });
    
    XCTAssertEqualObjects(object.allKeys, @[@"breadcrumbs"]);
    NSArray<NSDictionary *> *breadcrumbs = object[@"breadcrumbs"];
    XCTAssertEqual(breadcrumbs.count, 3);
    
    XCTAssertEqualObjects(breadcrumbs[0][@"type"], @"manual");
    XCTAssertEqualObjects(breadcrumbs[0][@"name"], @"Launch app");
    XCTAssertEqualObjects(breadcrumbs[0][@"metaData"], @{});
    
    XCTAssertEqualObjects(breadcrumbs[1][@"type"], @"manual");
    XCTAssertEqualObjects(breadcrumbs[1][@"name"], @"Tap button");
    XCTAssertEqualObjects(breadcrumbs[1][@"metaData"], @{});
    
    XCTAssertEqualObjects(breadcrumbs[2][@"type"], @"manual");
    XCTAssertEqualObjects(breadcrumbs[2][@"name"], @"Close tutorial");
    XCTAssertEqualObjects(breadcrumbs[2][@"metaData"], @{});
}

- (void)testPerformance {
    NSInteger maxBreadcrumbs = 100;
    
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    configuration.maxBreadcrumbs = maxBreadcrumbs;
    [configuration addOnSendErrorBlock:^BOOL(BugsnagEvent *event) { return NO; }];
    BugsnagClient *client = [[BugsnagClient alloc] initWithConfiguration:configuration];
    [client start];
    
    dispatch_block_t leaveBreadcrumbs = ^{
        for (int i=0; i<maxBreadcrumbs; i++) {
            [client leaveBreadcrumbWithMessage:[NSString stringWithFormat:@"%s %@", __PRETTY_FUNCTION__, [NSDate date]]
                                      metadata:[[NSBundle mainBundle] infoDictionary]
                                       andType:BSGBreadcrumbTypeLog];
        }
    };
    
    // The first run is always faster (while the number of breadcrumbs builds up)
    // which upsets the performance measurements, so run in without measuring.
    leaveBreadcrumbs();
    
    [self measureBlock:leaveBreadcrumbs];
}

@end

#pragma mark -

@implementation BugsnagBreadcrumbs (Testing)

- (NSArray<NSDictionary *> *)arrayValue {
    return [self.breadcrumbs valueForKey:@"objectValue"];
}

@end
