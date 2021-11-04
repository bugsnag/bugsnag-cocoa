//
//  BugsnagSessionTrackingPayloadTest.m
//  Tests
//
//  Created by Jamie Lynch on 27/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "BugsnagApp+Private.h"
#import "BugsnagConfiguration+Private.h"
#import "BugsnagDevice+Private.h"
#import "BugsnagNotifier.h"
#import "BugsnagSession+Private.h"
#import "BugsnagSessionTrackingPayload.h"
#import "BugsnagTestConstants.h"

@interface BugsnagSessionTrackingPayloadTest : XCTestCase
@property NSDictionary *payload;
@property BugsnagApp *app;
@property BugsnagDevice *device;
@end

@implementation BugsnagSessionTrackingPayloadTest

- (void)setUp {
    self.app = [self generateApp];
    self.device = [self generateDevice];

    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.releaseStage = @"beta";
    
    BugsnagSessionTrackingPayload *payload = [[BugsnagSessionTrackingPayload alloc] initWithSessions:@[]
                                                                                              config:config
                                                                                        codeBundleId:nil
                                                                                            notifier:[[BugsnagNotifier alloc] init]];
    BugsnagSession *session = [[BugsnagSession alloc] initWithId:@"test"
                                                       startDate:[NSDate date]
                                                            user:nil
                                                    autoCaptured:NO
                                                             app:self.app
                                                          device:self.device];
    payload.sessions = @[session];
    self.payload = [payload toJson];
}

- (BugsnagApp *)generateApp {
    NSDictionary *appData = @{
            @"system": @{
                    @"application_stats": @{
                            @"active_time_since_launch": @2,
                            @"background_time_since_launch": @5,
                            @"application_in_foreground": @YES,
                    },
                    @"CFBundleExecutable": @"MyIosApp",
                    @"CFBundleIdentifier": @"com.example.foo.MyIosApp",
                    @"CFBundleShortVersionString": @"5.6.3",
                    @"CFBundleVersion": @"1",
                    @"app_uuid": @"dsym-uuid-123"
            },
            @"user": @{
                    @"config": @{
                            @"releaseStage": @"beta"
                    }
            }
    };

    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithDictionaryRepresentation:appData[@"user"][@"config"]];
    config.appType = @"iOS";
    config.bundleVersion = nil;
    return [BugsnagApp appWithDictionary:appData config:config codeBundleId:@"bundle-123"];
}

- (BugsnagDevice *)generateDevice {
    NSDictionary *deviceData = @{
            @"system": @{
                    @"model": @"iPhone 6",
                    @"machine": @"x86_64",
                    @"system_name": @"iPhone OS",
                    @"system_version": @"8.1",
                    @"os_version": @"14B25",
                    @"clang_version": @"10.0.0 (clang-1000.11.45.5)",
                    @"jailbroken": @YES,
                    @"memory": @{
                            @"usable": @15065522176,
                            @"free": @742920192
                    },
                    @"device_app_hash": @"123"
            },
            @"report": @{
                    @"timestamp": @"2014-12-02T01:56:13Z"
            },
            @"user": @{
                    @"state": @{
                            @"deviceState": @{
                                    @"orientation": @"portrait"
                            }
                    }
            }
    };
    BugsnagDevice *device = [BugsnagDevice deviceWithKSCrashReport:deviceData];
    device.locale = @"en-US";
    return device;
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
    XCTAssertTrue(device[@"jailbroken"]);
    XCTAssertEqualObjects(@"123", device[@"id"]);
    XCTAssertEqualObjects(@"en-US", device[@"locale"]);
    XCTAssertEqualObjects(@"Apple", device[@"manufacturer"]);
    XCTAssertEqualObjects(@"x86_64", device[@"model"]);
    XCTAssertEqualObjects(@"iPhone 6", device[@"modelNumber"]);
    XCTAssertEqualObjects(@"iPhone OS", device[@"osName"]);
    XCTAssertEqualObjects(@"8.1", device[@"osVersion"]);
    XCTAssertEqualObjects(@15065522176, device[@"totalMemory"]);

    NSDictionary *runtimeVersions = @{
            @"osBuild": @"14B25",
            @"clangVersion": @"10.0.0 (clang-1000.11.45.5)"
    };
    XCTAssertEqualObjects(runtimeVersions, device[@"runtimeVersions"]);
}

- (void)testAppSerialisation {
    NSDictionary *app = self.payload[@"app"];
    XCTAssertNotNil(app);
    XCTAssertEqualObjects(@"1", app[@"bundleVersion"]);
    XCTAssertEqualObjects(@"bundle-123", app[@"codeBundleId"]);
    XCTAssertEqualObjects(@[@"dsym-uuid-123"], app[@"dsymUUIDs"]);
    XCTAssertEqualObjects(@"com.example.foo.MyIosApp", app[@"id"]);
    XCTAssertEqualObjects(@"beta", app[@"releaseStage"]);
    XCTAssertEqualObjects(@"iOS", app[@"type"]);
    XCTAssertEqualObjects(@"5.6.3", app[@"version"]);
}

@end
