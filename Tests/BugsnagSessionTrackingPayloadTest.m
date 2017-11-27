//
//  BugsnagSessionTrackingPayloadTest.m
//  Tests
//
//  Created by Jamie Lynch on 27/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface BugsnagSessionTrackingPayloadTest : XCTestCase
@end

@implementation BugsnagSessionTrackingPayloadTest

- (void)testPayloadSerialisation {
    NSDictionary *rootNode = [NSDictionary new]; // TODO serialise session as JSON
    XCTAssertNotNil(rootNode);

    NSArray *sessions = rootNode[@"sessions"];
    NSDictionary *sessionNode = sessions[0];
    XCTAssertNotNil(sessionNode);
    XCTAssertEqualObjects(@"test", sessionNode[@"id"]);

    NSString *expected = nil;
    XCTAssertEqualObjects(expected, sessionNode[@"startedAt"]);
    XCTAssertNotNil(sessionNode[@"user"]);

    XCTAssertNotNil(rootNode[@"notifier"]);
    XCTAssertNotNil(rootNode[@"device"]);
    XCTAssertNotNil(rootNode[@"app"]);
}

@end
