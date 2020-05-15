//
//  BugsnagOnCrashTest.m
//  Tests
//
//  Created by Jamie Lynch on 23/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <Bugsnag/Bugsnag.h>

@interface BugsnagEvent ()
- (instancetype)initWithKSReport:(NSDictionary *)report;
@end

@interface BugsnagOnCrashTest : XCTestCase

@end

@implementation BugsnagOnCrashTest

- (void)testEmptyData {
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:@{}];
    XCTAssertNil([event getMetadataFromSection:@"onCrash"]);
}

- (void)testOnCrashData {
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:@{
            @"user": @{
                    @"name": @"Joe Bloggs"
            }
    }];
    NSMutableDictionary *data = [event getMetadataFromSection:@"onCrash"];
    XCTAssertNotNil(data);
    XCTAssertEqual(1, [data count]);
    XCTAssertEqualObjects(@"Joe Bloggs", data[@"name"]);
}

/**
 * Verifies that fields stored in same section under different keys are
 * _not_ added to the metadata
 */
- (void)testBlacklistedFields {
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:@{
            @"user": @{
                    @"name": @"Joe Bloggs",
                    @"overrides": @{
                            @"test": @"test_val"
                    },
                    @"handledState": @{
                            @"test": @"test_val"
                    },
                    @"metaData": @{
                            @"test": @{
                                    @"foo": @"test_val"
                            }
                    },
                    @"state": @{
                            @"test": @"test_val"
                    },
                    @"config": @{
                            @"test": @"test_val"
                    },
                    @"depth": @2,
                    @"id": @"E7E3A6E8-D1FE-426D-B7BB-B247C957A109",
                    @"startedAt": @"2020-04-23T09:01:04Z",
                    @"handledCount": @0,
                    @"unhandledCount": @1,
            }
    }];
    NSMutableDictionary *data = [event getMetadataFromSection:@"onCrash"];
    XCTAssertNotNil(data);
    XCTAssertEqual(1, [data count]);
    XCTAssertEqualObjects(@"Joe Bloggs", data[@"name"]);
}

/**
 * Assert that data added via onCrashHandler has higher precedence than
 * that added to metadata (as it was added more recently)
 */
- (void)testMergePrecedence {
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:@{
            @"user": @{
                    @"name": @"Joe Bloggs",
                    @"metaData": @{
                            @"onCrash": @{
                                    @"name": @"Beryl Merryweather",
                                    @"age": @76
                            }
                    }
            }
    }];
    NSMutableDictionary *data = [event getMetadataFromSection:@"onCrash"];
    XCTAssertNotNil(data);
    XCTAssertEqual(2, [data count]);
    XCTAssertEqualObjects(@"Joe Bloggs", data[@"name"]);
    XCTAssertEqualObjects(@76, data[@"age"]);
}

@end
