//
//  BugsnagSessionTest.m
//  Tests
//
//  Created by Jamie Lynch on 27/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "BugsnagSession.h"
#import "BSG_RFC3339DateTool.h"

@interface BugsnagSessionTest : XCTestCase
@end

@implementation BugsnagSessionTest

- (void)testPayloadSerialisation {
    BugsnagSession *payload = [BugsnagSession new];
    NSDate *now = [NSDate date];
    payload.sessionId = @"test";
    payload.startedAt = now;
    
    payload.unhandledCount = 1;
    payload.handledCount = 2;
    payload.autoCaptured = YES;
    payload.user = [BugsnagUser new];
    
    NSDictionary *rootNode = [payload toJson];
    XCTAssertNotNil(rootNode);
    XCTAssertEqual(6, [rootNode count]);
    
    XCTAssertEqualObjects(@"test", rootNode[@"id"]);
    XCTAssertEqualObjects([BSG_RFC3339DateTool stringFromDate:now], rootNode[@"startedAt"]);
    XCTAssertEqual(@1, rootNode[@"unhandledCount"]);
    XCTAssertEqual(@2, rootNode[@"handledCount"]);
    XCTAssertTrue(rootNode[@"autoCaptured"]);
    XCTAssertNotNil(rootNode[@"user"]);
}

@end
