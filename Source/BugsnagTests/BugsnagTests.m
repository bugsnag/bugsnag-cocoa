//
//  BugsnagTests.m
//  BugsnagTests
//
//  Created by Conrad Irwin on 11/5/14.
//
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#import "Bugsnag.h"

@interface BugsnagTests : XCTestCase

@end

@implementation BugsnagTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testStartBugsnagWithApiKey {
    [Bugsnag startBugsnagWithApiKey:@"12345678123456781234567812345678"];
    
    XCTAssertEqualObjects(Bugsnag.configuration.apiKey, @"12345678123456781234567812345678");
    XCTAssertEqual(Bugsnag.configuration.autoNotify, true);
    XCTAssertEqualObjects(Bugsnag.configuration.notifyURL, [NSURL URLWithString:@"https://notify.bugsnag.com/"]);
}

- (void)testStartBugsnagWithConfiguration {
    BugsnagConfiguration* config = [[BugsnagConfiguration alloc] init];
    config.autoNotify = false;
    config.notifyURL = [NSURL URLWithString:@"http://localhost:8000/"];
    config.apiKey = @"12345678123456781234567812345678";
    
    [Bugsnag startBugsnagWithConfiguration:config];
    
    XCTAssertEqual(Bugsnag.configuration.autoNotify, false);
    XCTAssertEqualObjects(Bugsnag.configuration.notifyURL, [NSURL URLWithString:@"http://localhost:8000/"]);
    XCTAssertEqualObjects(Bugsnag.configuration.apiKey, @"12345678123456781234567812345678");
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
