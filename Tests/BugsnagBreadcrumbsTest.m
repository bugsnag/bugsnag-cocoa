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
    XCTAssertEqualObjects(self.crumbs[0].metadata[@"message"], @"Tap button");
    XCTAssertEqualObjects(self.crumbs[1].metadata[@"message"],
                          @"Close tutorial");
    XCTAssertEqualObjects(self.crumbs[2].metadata[@"message"],
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
    XCTAssertEqualObjects(self.crumbs[0].metadata[@"message"], @"Tap button");
    XCTAssertEqualObjects(self.crumbs[1].metadata[@"message"],
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
        XCTAssertEqualObjects(item[@"name"], @"manual");
        XCTAssertEqualObjects(item[@"type"], @"manual");
        XCTAssertTrue([[formatter dateFromString:item[@"timestamp"]]
                       isKindOfClass:[NSDate class]]);
    }
    XCTAssertEqualObjects(value[0][@"metaData"][@"message"], @"Launch app");
    XCTAssertEqualObjects(value[1][@"metaData"][@"message"], @"Tap button");
    XCTAssertEqualObjects(value[2][@"metaData"][@"message"], @"Close tutorial");
}

- (void)testStateType {
    BugsnagBreadcrumbs *crumbs = [BugsnagBreadcrumbs new];
    [crumbs addBreadcrumbWithBlock:^(BugsnagBreadcrumb *_Nonnull crumb) {
        crumb.type = BSGBreadcrumbTypeState;
        crumb.name = @"Rotated Menu";
        crumb.metadata = @{@"direction" : @"right"};
    }];
    awaitBreadcrumbSync(self.crumbs);
    NSArray *value = [crumbs arrayValue];
    XCTAssertEqualObjects(value[0][@"metaData"][@"direction"], @"right");
    XCTAssertEqualObjects(value[0][@"name"], @"Rotated Menu");
    XCTAssertEqualObjects(value[0][@"type"], @"state");
}

- (void)testPersistentCrumbManual {
    NSData *crumbs = [NSData dataWithContentsOfFile:self.crumbs.cachePath];
    NSArray *value = [NSJSONSerialization JSONObjectWithData:crumbs options:0 error:nil];
    XCTAssertEqual(value.count, 3);
    XCTAssertEqualObjects(value[0][@"type"], @"manual");
    XCTAssertEqualObjects(value[0][@"name"], @"manual");
    XCTAssertEqualObjects(value[0][@"metaData"][@"message"], @"Launch app");
    XCTAssertNotNil(value[0][@"timestamp"]);
    XCTAssertEqualObjects(value[1][@"type"], @"manual");
    XCTAssertEqualObjects(value[1][@"name"], @"manual");
    XCTAssertEqualObjects(value[1][@"metaData"][@"message"], @"Tap button");
    XCTAssertNotNil(value[1][@"timestamp"]);
    XCTAssertEqualObjects(value[2][@"type"], @"manual");
    XCTAssertEqualObjects(value[2][@"name"], @"manual");
    XCTAssertEqualObjects(value[2][@"metaData"][@"message"], @"Close tutorial");
    XCTAssertNotNil(value[2][@"timestamp"]);
}

- (void)testPersistentCrumbCustom {
    [self.crumbs addBreadcrumbWithBlock:^(BugsnagBreadcrumb *crumb) {
        crumb.name = @"Initiate sequence";
        crumb.metadata = @{ @"captain": @"Bob"};
        crumb.type = BSGBreadcrumbTypeState;
    }];
    NSData *crumbs = [NSData dataWithContentsOfFile:self.crumbs.cachePath];
    NSArray *value = [NSJSONSerialization JSONObjectWithData:crumbs options:0 error:nil];
    XCTAssertEqual(value.count, 4);
    XCTAssertEqualObjects(value[3][@"type"], @"state");
    XCTAssertEqualObjects(value[3][@"name"], @"Initiate sequence");
    XCTAssertEqualObjects(value[3][@"metaData"][@"captain"], @"Bob");
    XCTAssertNotNil(value[3][@"timestamp"]);
}

- (void)testByteSizeLimit {
    BugsnagBreadcrumbs *crumbs = [BugsnagBreadcrumbs new];
    [crumbs addBreadcrumbWithBlock:^(BugsnagBreadcrumb *_Nonnull crumb) {
        crumb.type = BSGBreadcrumbTypeState;
        crumb.name = @"Rotated Menu";
        NSMutableDictionary *metadata = @{}.mutableCopy;
        for (int i = 0; i < 400; i++) {
            metadata[[NSString stringWithFormat:@"%d", i]] = @"!!";
        }
        crumb.metadata = metadata;
    }];
    NSArray *value = [crumbs arrayValue];
    XCTAssertTrue(value.count == 0);
}

@end
