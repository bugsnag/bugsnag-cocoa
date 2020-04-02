//
//  BugsnagSessionTrackingPayloadTest.m
//  Tests
//
//  Created by Jamie Lynch on 27/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "BugsnagSessionTrackingPayload.h"
#import "BugsnagConfiguration.h"
#import "BugsnagTestConstants.h"

@interface BugsnagSessionTrackingPayloadTest : XCTestCase
@property NSDictionary *payload;
@end

@implementation BugsnagSessionTrackingPayloadTest

- (void)setUp {
    [super setUp];
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.releaseStage = @"beta";
    BugsnagSessionTrackingPayload *data = [[BugsnagSessionTrackingPayload alloc] initWithSessions:@[] config:config];
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
    XCTAssertEqualObjects(device[@"manufacturer"], @"Apple");
    XCTAssertNotNil(device[@"model"]);
    XCTAssertNotNil(device[@"osName"]);
    XCTAssertNotNil(device[@"osVersion"]);
    XCTAssertFalse([device[@"jailbroken"] boolValue]);
    XCTAssertNotNil(device[@"id"]);
    XCTAssertNotNil(device[@"locale"]);
    XCTAssertNotNil(device[@"runtimeVersions"]);
}

- (void)testAppSerialisation {
    NSDictionary *app = self.payload[@"app"];
    XCTAssertNotNil(app);
    XCTAssertEqual(6, app.count);
    
    XCTAssertNotNil(app[@"type"]);
    XCTAssertNotNil(app[@"version"]);
    XCTAssertNotNil(app[@"bundleVersion"]);
    XCTAssertNotNil(app[@"releaseStage"]);
}

@end
