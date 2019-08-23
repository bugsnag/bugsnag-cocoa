//
//  BugsnagCollectionsBSGDictMergeTest.m
//  Tests
//
//  Created by Paul Zabelin on 7/1/19.
//  Copyright © 2019 Bugsnag. All rights reserved.
//

@import XCTest;
#import "BugsnagCollections.h"

@interface BugsnagCollectionsBSGDictMergeTest : XCTestCase
@end

@implementation BugsnagCollectionsBSGDictMergeTest

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

- (void)testDstEmpty {
    id src = @{@"a": @"one"};
    XCTAssertEqualObjects(src, BSGDictMerge(src, @{}), @"should copy");
}

- (void)testDstNil {
    id src = @{@"a": @"one"};
    XCTAssertEqualObjects(src, BSGDictMerge(src, nil), @"should copy");
}

- (void)testSrcDict {
    id src = @{@"a": @{@"x": @"blah"}};
    XCTAssertEqualObjects(src, BSGDictMerge(src, @{@"a": @"two"}), @"should not overwrite");
}

- (void)testDstDict {
    id src = @{@"a": @"one"};
    XCTAssertEqualObjects(src, BSGDictMerge(src, @{@"a": @{@"x": @"blah"}}), @"should not overwrite");
}

- (void)testSrcDstDict {
    id src = @{@"a": @{@"x": @"blah"}};
    id dst = @{@"a": @{@"y": @"something"}};
    NSDictionary* expected = @{@"a": @{@"x": @"blah",
                                       @"y": @"something"}};
    XCTAssertEqualObjects(expected, BSGDictMerge(src, dst), @"should combine");
}

@end
