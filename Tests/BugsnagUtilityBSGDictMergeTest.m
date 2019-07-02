//
//  BugsnagUtilityBSGDictMergeTest.m
//  Tests
//
//  Created by Paul Zabelin on 7/1/19.
//  Copyright © 2019 Bugsnag. All rights reserved.
//

@import XCTest;
#import "BugsnagUtility.h"

@interface BugsnagUtilityBSGDictMergeTest : XCTestCase
@end

@implementation BugsnagUtilityBSGDictMergeTest

- (void)testBasicMerge {
    NSDictionary *combined = @{@"a": @"one",
                               @"b": @"two"};
    XCTAssertEqualObjects(combined, BSGDictMerge(@{@"a": @"one"}, @{@"b": @"two"}), @"should combine");
}

- (void)testOverwrite {
    id src = @{@"a": @"one"};
    XCTAssertEqualObjects(src, BSGDictMerge(src, @{@"a": @"two"}), @"should overwrite");
}

- (void)testSrcEmpty {
    id dst = @{@"b": @"two"};
    XCTAssertEqualObjects(dst, BSGDictMerge(@{}, dst), @"should copy");
}

- (void) testDstEmpty {
    id src = @{@"a": @"one"};
    XCTAssertEqualObjects(src, BSGDictMerge(src, @{}), @"should copy");
}


@end
