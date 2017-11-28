//
//  BugsnagSessionTrackingPayloadTest.m
//  Tests
//
//  Created by Jamie Lynch on 27/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "BugsnagSessionTrackingPayload.h"

@interface BugsnagSessionTrackingPayloadTest : XCTestCase
@property NSDictionary *payload;
@end

@implementation BugsnagSessionTrackingPayloadTest

- (void)setUp {
    [super setUp];
    BugsnagSessionTrackingPayload *data = [BugsnagSessionTrackingPayload new];
    BugsnagSession *session = [BugsnagSession new];
    session.sessionId = @"test";
    data.sessions = @[session];
    self.payload = [data toJson];
}

- (void)testPayloadSerialisation {
    XCTAssertNotNil(self.payload);

    NSArray *sessions = self.payload[@"sessions"];
    NSDictionary *sessionNode = sessions[0];
    XCTAssertNotNil(sessionNode);
    XCTAssertEqualObjects(@"test", sessionNode[@"id"]);
    
    XCTAssertNotNil(self.payload[@"notifier"]);
}

- (void)testDeviceSerialisation {
    NSDictionary *device = self.payload[@"device"];
    XCTAssertNotNil(device);
    XCTAssertEqual(6, device.count);
    
    XCTAssertEqualObjects(device[@"manufacturer"], @"Apple");
    XCTAssertNotNil(device[@"model"]);
    XCTAssertNotNil(device[@"modelNumber"]);
    XCTAssertNotNil(device[@"osName"]);
    XCTAssertNotNil(device[@"osVersion"]);
    XCTAssertNotNil(device[@"jailbroken"]);
}

- (void)testAppSerialisation {
    NSDictionary *app = self.payload[@"app"];
    XCTAssertNotNil(app);
    XCTAssertEqual(4, app.count);
    
    XCTAssertNotNil(app[@"type"]);
    XCTAssertEqualObjects(app[@"version"], @"1.0");
    XCTAssertEqualObjects(app[@"bundleVersion"], @"1");
    XCTAssertEqualObjects(app[@"releaseStage"], @"MagicalTestingTime");
}

@end
