//
//  NSDictionary+Merge_Tests.m
//
//  Created by Karl Stenerud on 2012-10-01.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//


#import <XCTest/XCTest.h>

#import "NSDictionary+BSG_Merge.h"


@interface NSDictionary_Merge_Tests : XCTestCase @end


@implementation NSDictionary_Merge_Tests

- (void) testBasicMerge
{
    id src = @{@"a": @"one"};
    id dst = @{@"b": @"two"};
    NSDictionary* expected = @{@"a": @"one",
            @"b": @"two"};
    NSDictionary* actual = [src bsg_mergedInto:dst];
    XCTAssertEqualObjects(expected, actual, @"");
}

- (void) testOverwrite
{
    id src = @{@"a": @"one"};
    id dst = @{@"a": @"two"};
    NSDictionary* expected = @{@"a": @"one"};
    NSDictionary* actual = [src bsg_mergedInto:dst];
    XCTAssertEqualObjects(expected, actual, @"");
}

- (void) testSrcEmpty
{
    id src = [NSDictionary dictionary];
    id dst = @{@"b": @"two"};
    NSDictionary* expected = @{@"b": @"two"};
    NSDictionary* actual = [src bsg_mergedInto:dst];
    XCTAssertEqualObjects(expected, actual, @"");
}

- (void) testDstEmpty
{
    id src = @{@"a": @"one"};
    id dst = [NSDictionary dictionary];
    NSDictionary* expected = @{@"a": @"one"};
    NSDictionary* actual = [src bsg_mergedInto:dst];
    XCTAssertEqualObjects(expected, actual, @"");
}

- (void) testDstNil
{
    id src = @{@"a": @"one"};
    id dst = nil;
    NSDictionary* expected = @{@"a": @"one"};
    NSDictionary* actual = [src bsg_mergedInto:dst];
    XCTAssertEqualObjects(expected, actual, @"");
}

- (void) testSrcDict
{
    id src = @{@"a": @{@"x": @"blah"}};
    id dst = @{@"a": @"two"};
    NSDictionary* expected = @{@"a": @{@"x": @"blah"}};
    NSDictionary* actual = [src bsg_mergedInto:dst];
    XCTAssertEqualObjects(expected, actual, @"");
}

- (void) testDstDict
{
    id src = @{@"a": @"one"};
    id dst = @{@"a": @{@"x": @"blah"}};
    NSDictionary* expected = @{@"a": @"one"};
    NSDictionary* actual = [src bsg_mergedInto:dst];
    XCTAssertEqualObjects(expected, actual, @"");
}

- (void) testSrcDstDict
{
    id src = @{@"a": @{@"x": @"blah"}};
    id dst = @{@"a": @{@"y": @"something"}};
    NSDictionary* expected = @{@"a": @{@"x": @"blah",
            @"y": @"something"}};
    NSDictionary* actual = [src bsg_mergedInto:dst];
    XCTAssertEqualObjects(expected, actual, @"");
}

@end
