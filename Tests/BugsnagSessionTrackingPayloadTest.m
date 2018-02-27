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
    BugsnagSession *session = [[BugsnagSession alloc] initWithId:@"test"
                                                       startDate:[NSDate date]
                                                            user:nil
                                                    autoCaptured:NO];
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
    XCTAssertEqual(7, device.count);
    
    XCTAssertEqualObjects(device[@"manufacturer"], @"Apple");
    XCTAssertNotNil(device[@"model"]);
    XCTAssertNotNil(device[@"modelNumber"]);
    XCTAssertNotNil(device[@"osName"]);
    XCTAssertNotNil(device[@"osVersion"]);
    XCTAssertEqualObjects(device[@"jailbroken"], @NO);
#if defined(__LP64__)
    XCTAssertEqualObjects(device[@"wordSize"], @64);
#else
    XCTAssertEqualObjects(device[@"wordSize"], @32);
#endif
}

- (void)testAppSerialisation {
    NSDictionary *app = self.payload[@"app"];
    XCTAssertNotNil(app);
    XCTAssertEqual(5, app.count);
    
    XCTAssertNotNil(app[@"type"]);
    XCTAssertNotNil(app[@"version"]);
    XCTAssertNotNil(app[@"bundleVersion"]);
    XCTAssertNotNil(app[@"releaseStage"]);
}

@end
