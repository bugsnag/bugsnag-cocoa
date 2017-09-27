//
//  StackFrameDepthTest.m
//  Tests
//
//  Created by Jamie Lynch on 27/09/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "Bugsnag.h"

@interface StackFrameDepthTest : XCTestCase

@end

@implementation StackFrameDepthTest

- (void)setUp {
    [super setUp];
    BugsnagConfiguration *config = [BugsnagConfiguration new];
    config.session = [
    [Bugsnag startBugsnagWithConfiguration:config];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
