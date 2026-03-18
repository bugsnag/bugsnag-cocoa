//
//  BugsnagMetricKitPluginTests.m
//  BugsnagMetricKitPluginTests
//
//  Created by Bugsnag on 2026-03-18.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <BugsnagMetricKitPlugin/BugsnagMetricKitPlugin.h>

@interface BugsnagMetricKitPluginTests : XCTestCase

@end

@implementation BugsnagMetricKitPluginTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testPluginExists {
    // Test that the plugin class exists and responds to install
    XCTAssertTrue([BugsnagMetricKitPlugin respondsToSelector:@selector(install)]);
}

@end
