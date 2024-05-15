//
//  BugsnagPerformanceBridgeTests.m
//  Bugsnag
//
//  Created by Karl Stenerud on 14.05.24.
//  Copyright © 2024 Bugsnag Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "BugsnagCocoaPerformanceFromBugsnagCocoa.h"

@interface BugsnagPerformanceBridgeTests : XCTestCase

@end

@implementation BugsnagPerformanceBridgeTests

- (void)testBridgeStability {
    BugsnagCocoaPerformanceFromBugsnagCocoa *api = BugsnagCocoaPerformanceFromBugsnagCocoa.sharedInstance;
    // With BugsnagPerformance not present, we should get nil calling this.
    // And most importantly it should not crash!
    XCTAssertNil([api getCurrentTraceAndSpanId]);
}

@end
