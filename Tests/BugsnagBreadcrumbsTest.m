//
//  BugsnagBreadcrumbsTest.m
//  Bugsnag
//
//  Created by Delisa Mason on 9/16/15.
//
//

#import <XCTest/XCTest.h>
#import "BugsnagBreadcrumb.h"

@interface BugsnagBreadcrumbsTest : XCTestCase
@property (nonatomic,strong) BugsnagBreadcrumbs* crumbs;
@end

@implementation BugsnagBreadcrumbsTest

- (void)setUp {
    [super setUp];
    BugsnagBreadcrumbs* crumbs = [BugsnagBreadcrumbs new];
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
    XCTAssertTrue(self.crumbs.count == 3);
    XCTAssertEqualObjects(self.crumbs[0].metadata[@"message"], @"Tap button");
    XCTAssertEqualObjects(self.crumbs[1].metadata[@"message"], @"Close tutorial");
    XCTAssertEqualObjects(self.crumbs[2].metadata[@"message"], @"Clear notifications");
    XCTAssertNil(self.crumbs[3]);
}

- (void)testClearBreadcrumbs {
    [self.crumbs clearBreadcrumbs];
    XCTAssertTrue(self.crumbs.count == 0);
    XCTAssertNil(self.crumbs[0]);
}

- (void)testEmptyCapacity {
    self.crumbs.capacity = 0;
    [self.crumbs addBreadcrumb:@"Clear notifications"];
    XCTAssertTrue(self.crumbs.count == 0);
    XCTAssertNil(self.crumbs[0]);
}

- (void)testResizeBreadcrumbs {
    self.crumbs.capacity = 2;
    XCTAssertTrue(self.crumbs.count == 2);
    XCTAssertEqualObjects(self.crumbs[0].metadata[@"message"], @"Tap button");
    XCTAssertEqualObjects(self.crumbs[1].metadata[@"message"], @"Close tutorial");
    XCTAssertNil(self.crumbs[2]);
}

- (void)testArrayValue {
    NSArray* value = [self.crumbs arrayValue];
    XCTAssertNotNil(value);
    XCTAssertTrue(value.count == 3);
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ssX5";
    for (int i = 0; i < value.count; i++) {
        NSDictionary *item = value[i];
        XCTAssertTrue([item isKindOfClass:[NSDictionary class]]);
        XCTAssertEqualObjects(item[@"name"], @"manual");
        XCTAssertEqualObjects(item[@"type"], @"manual");
        XCTAssertTrue([[formatter dateFromString:item[@"timestamp"]] isKindOfClass:[NSDate class]]);
    }
    XCTAssertEqualObjects(value[0][@"metaData"][@"message"], @"Launch app");
    XCTAssertEqualObjects(value[1][@"metaData"][@"message"], @"Tap button");
    XCTAssertEqualObjects(value[2][@"metaData"][@"message"], @"Close tutorial");
}

@end
