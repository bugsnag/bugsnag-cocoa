//
//  BugsnagBreadcrumbsTest.m
//  Bugsnag
//
//  Created by Delisa Mason on 9/16/15.
//
//

#import "BugsnagBreadcrumb.h"
#import <XCTest/XCTest.h>

@interface BugsnagBreadcrumbsTest : XCTestCase
@property(nonatomic, strong) BugsnagBreadcrumbs *crumbs;
@end

@interface BugsnagBreadcrumbs ()
@property(nonatomic, readonly, strong) dispatch_queue_t readWriteQueue;
@end

void awaitBreadcrumbSync(BugsnagBreadcrumbs *crumbs) {
    dispatch_barrier_sync(crumbs.readWriteQueue, ^{
        usleep(300000);
    });
}

BSGBreadcrumbType BSGBreadcrumbTypeFromString(NSString *value);

@implementation BugsnagBreadcrumbsTest

- (void)setUp {
    [super setUp];
    BugsnagBreadcrumbs *crumbs = [BugsnagBreadcrumbs new];
    [crumbs addBreadcrumb:@"Launch app"];
    [crumbs addBreadcrumb:@"Tap button"];
    [crumbs addBreadcrumb:@"Close tutorial"];
    self.crumbs = crumbs;
}

- (void)testDefaultCapacity {
    XCTAssertTrue([BugsnagBreadcrumbs new].capacity == 25);
}

- (void)testDefaultCount {
    XCTAssertTrue([BugsnagBreadcrumbs new].count == 0);
}

- (void)testCachePath {
    NSString *cachePath = [[NSSearchPathForDirectoriesInDomains(
                              NSCachesDirectory, NSUserDomainMask, YES)
                            firstObject]
                           stringByAppendingPathComponent:@"bugsnag_breadcrumbs.json"];
    XCTAssertEqualObjects([BugsnagBreadcrumbs new].cachePath, cachePath);
}

- (void)testMaxBreadcrumbs {
    self.crumbs.capacity = 3;
    [self.crumbs addBreadcrumb:@"Clear notifications"];
    awaitBreadcrumbSync(self.crumbs);
    XCTAssertEqual(self.crumbs.count, 3);
    XCTAssertEqualObjects(self.crumbs[0].message, @"Tap button");
    XCTAssertEqualObjects(self.crumbs[1].message,
                          @"Close tutorial");
    XCTAssertEqualObjects(self.crumbs[2].message,
                          @"Clear notifications");
    XCTAssertNil(self.crumbs[3]);
}

- (void)testMaxMaxBreadcrumbs {
    self.crumbs.capacity = 250;
    XCTAssertEqual(100, self.crumbs.capacity);
}

- (void)testClearBreadcrumbs {
    [self.crumbs clearBreadcrumbs];
    awaitBreadcrumbSync(self.crumbs);
    XCTAssertTrue(self.crumbs.count == 0);
    XCTAssertNil(self.crumbs[0]);
}

- (void)testEmptyCapacity {
    self.crumbs.capacity = 0;
    [self.crumbs addBreadcrumb:@"Clear notifications"];
    XCTAssertEqual(self.crumbs.count, 0);
    XCTAssertNil(self.crumbs[0]);
}

- (void)testResizeBreadcrumbs {
    self.crumbs.capacity = 2;
    awaitBreadcrumbSync(self.crumbs);
    XCTAssertEqual(self.crumbs.count, 2);
    XCTAssertEqualObjects(self.crumbs[0].message, @"Tap button");
    XCTAssertEqualObjects(self.crumbs[1].message,
                          @"Close tutorial");
    XCTAssertNil(self.crumbs[2]);
}

- (void)testArrayValue {
    awaitBreadcrumbSync(self.crumbs);
    NSArray *value = [self.crumbs arrayValue];
    XCTAssertNotNil(value);
    XCTAssertTrue(value.count == 3);
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ssX5";
    for (int i = 0; i < value.count; i++) {
        NSDictionary *item = value[i];
        XCTAssertTrue([item isKindOfClass:[NSDictionary class]]);
        XCTAssertEqualObjects(item[@"type"], @"manual");
        XCTAssertTrue([[formatter dateFromString:item[@"timestamp"]]
                       isKindOfClass:[NSDate class]]);
    }
    XCTAssertEqualObjects(value[0][@"message"], @"Launch app");
    XCTAssertEqualObjects(value[1][@"message"], @"Tap button");
    XCTAssertEqualObjects(value[2][@"message"], @"Close tutorial");
}

- (void)testStateType {
    BugsnagBreadcrumbs *crumbs = [BugsnagBreadcrumbs new];
    [crumbs addBreadcrumbWithBlock:^(BugsnagBreadcrumb *_Nonnull crumb) {
        crumb.type = BSGBreadcrumbTypeState;
        crumb.message = @"Rotated Menu";
        crumb.metadata = @{@"direction" : @"right"};
    }];
    awaitBreadcrumbSync(self.crumbs);
    NSArray *value = [crumbs arrayValue];
    XCTAssertEqualObjects(value[0][@"metaData"][@"direction"], @"right");
    XCTAssertEqualObjects(value[0][@"message"], @"Rotated Menu");
    XCTAssertEqualObjects(value[0][@"type"], @"state");
}

- (void)testPersistentCrumbManual {
    NSData *crumbs = [NSData dataWithContentsOfFile:self.crumbs.cachePath];
    NSArray *value = [NSJSONSerialization JSONObjectWithData:crumbs options:0 error:nil];
    XCTAssertEqual(value.count, 3);
    XCTAssertEqualObjects(value[0][@"type"], @"manual");
    XCTAssertEqualObjects(value[0][@"message"], @"Launch app");
    XCTAssertNotNil(value[0][@"timestamp"]);
    XCTAssertEqualObjects(value[1][@"type"], @"manual");
    XCTAssertEqualObjects(value[1][@"message"], @"Tap button");
    XCTAssertNotNil(value[1][@"timestamp"]);
    XCTAssertEqualObjects(value[2][@"type"], @"manual");
    XCTAssertEqualObjects(value[2][@"message"], @"Close tutorial");
    XCTAssertNotNil(value[2][@"timestamp"]);
}

- (void)testPersistentCrumbCustom {
    [self.crumbs addBreadcrumbWithBlock:^(BugsnagBreadcrumb *crumb) {
        crumb.message = @"Initiate sequence";
        crumb.metadata = @{ @"captain": @"Bob"};
        crumb.type = BSGBreadcrumbTypeState;
    }];
    NSData *crumbs = [NSData dataWithContentsOfFile:self.crumbs.cachePath];
    NSArray *value = [NSJSONSerialization JSONObjectWithData:crumbs options:0 error:nil];
    XCTAssertEqual(value.count, 4);
    XCTAssertEqualObjects(value[3][@"type"], @"state");
    XCTAssertEqualObjects(value[3][@"message"], @"Initiate sequence");
    XCTAssertEqualObjects(value[3][@"metaData"][@"captain"], @"Bob");
    XCTAssertNotNil(value[3][@"timestamp"]);
}

- (void)testDefaultDiscardByType {
    [self.crumbs clearBreadcrumbs];
    awaitBreadcrumbSync(self.crumbs);
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
    [self.crumbs clearBreadcrumbs];
    awaitBreadcrumbSync(self.crumbs);
    self.crumbs.enabledBreadcrumbTypes = 0;
    [self.crumbs addBreadcrumb:@"this is a test"];
    awaitBreadcrumbSync(self.crumbs);
    NSArray *value = [self.crumbs arrayValue];
    XCTAssertEqual(1, value.count);
    XCTAssertEqualObjects(value[0][@"type"], @"manual");
    XCTAssertEqualObjects(value[0][@"message"], @"this is a test");
}

- (void)testDiscardByType {
    [self.crumbs clearBreadcrumbs];
    awaitBreadcrumbSync(self.crumbs);
    self.crumbs.enabledBreadcrumbTypes = BSGEnabledBreadcrumbTypeProcess;
    [self.crumbs addBreadcrumbWithBlock:^(BugsnagBreadcrumb *_Nonnull crumb) {
        crumb.type = BSGBreadcrumbTypeState;
        crumb.message = @"state";
    }];
    awaitBreadcrumbSync(self.crumbs);
    NSArray *value = [self.crumbs arrayValue];
    XCTAssertEqual(0, value.count);
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

@end
