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
    XCTAssertTrue([BugsnagBreadcrumbs new].capacity == 20);
}

- (void)testDefaultCount {
    XCTAssertTrue([BugsnagBreadcrumbs new].count == 0);
}

- (void)testMaxBreadcrumbs {
    self.crumbs.capacity = 3;
    [self.crumbs addBreadcrumb:@"Clear notifications"];
    awaitBreadcrumbSync(self.crumbs);
    XCTAssertEqual(self.crumbs.count, 3);
    XCTAssertEqualObjects(self.crumbs[0].metadata[BSGKeyMessage], @"Tap button");
    XCTAssertEqualObjects(self.crumbs[1].metadata[BSGKeyMessage],
                          @"Close tutorial");
    XCTAssertEqualObjects(self.crumbs[2].metadata[BSGKeyMessage],
                          @"Clear notifications");
    XCTAssertNil(self.crumbs[3]);
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
    XCTAssertEqualObjects(self.crumbs[0].metadata[BSGKeyMessage], @"Tap button");
    XCTAssertEqualObjects(self.crumbs[1].metadata[BSGKeyMessage],
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
        XCTAssertEqualObjects(item[BSGKeyName], @"manual");
        XCTAssertEqualObjects(item[BSGKeyType], @"manual");
        XCTAssertTrue([[formatter dateFromString:item[BSGKeyTimestamp]]
            isKindOfClass:[NSDate class]]);
    }
    XCTAssertEqualObjects(value[0][BSGKeyMetaData][BSGKeyMessage], @"Launch app");
    XCTAssertEqualObjects(value[1][BSGKeyMetaData][BSGKeyMessage], @"Tap button");
    XCTAssertEqualObjects(value[2][BSGKeyMetaData][BSGKeyMessage], @"Close tutorial");
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
    XCTAssertEqualObjects(value[0][BSGKeyMetaData][@"direction"], @"right");
    XCTAssertEqualObjects(value[0][BSGKeyName], @"Rotated Menu");
    XCTAssertEqualObjects(value[0][BSGKeyType], @"state");
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
