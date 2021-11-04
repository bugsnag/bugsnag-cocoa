//
//  BugsnagClientPayloadInfoTest.m
//  Tests
//
//  Created by Jamie Lynch on 30/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "Bugsnag+Private.h"
#import "BugsnagClient+Private.h"
#import "BugsnagConfiguration.h"
#import "BugsnagTestConstants.h"

@interface BugsnagClientPayloadInfoTest : XCTestCase

@end

@implementation BugsnagClientPayloadInfoTest

- (void)setUp {
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    [Bugsnag startWithConfiguration:configuration];
}

- (void)testAppInfo {
    BugsnagClient *client = [Bugsnag client];
    client.codeBundleId = @"f00123";
    NSDictionary *app = [client collectAppWithState];
    XCTAssertNotNil(app);
    
    XCTAssertEqualObjects(app[@"codeBundleId"], @"f00123");
    XCTAssertNotNil(app[@"dsymUUIDs"]);
    XCTAssertNotNil(app[@"duration"]);
    XCTAssertNotNil(app[@"durationInForeground"]);
    XCTAssertNotNil(app[@"inForeground"]);
    XCTAssertNotNil(app[@"releaseStage"]);
    XCTAssertNotNil(app[@"type"]);
    
    // Depending on the Info.plist of the unit test runner, these values may not always be present.
    XCTAssertEqualObjects(app[@"bundleVersion"], NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]);
    XCTAssertEqualObjects(app[@"id"], NSBundle.mainBundle.bundleIdentifier);
    XCTAssertEqualObjects(app[@"version"], NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]);
}

- (void)testDeviceInfo {
    BugsnagClient *client = [Bugsnag client];
    NSDictionary *device = [client collectDeviceWithState];
    XCTAssertNotNil(device[@"freeDisk"]);
    XCTAssertNotNil(device[@"freeMemory"]);
    XCTAssertNotNil(device[@"id"]);
    XCTAssertNotNil(device[@"jailbroken"]);
    XCTAssertNotNil(device[@"locale"]);
    XCTAssertNotNil(device[@"manufacturer"]);
    XCTAssertNotNil(device[@"model"]);
    XCTAssertNotNil(device[@"osName"]);
    XCTAssertNotNil(device[@"osVersion"]);
    XCTAssertNotNil(device[@"runtimeVersions"]);
    XCTAssertNotNil(device[@"time"]);
    XCTAssertNotNil(device[@"totalMemory"]);
    
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
    NSProcessInfo *processInfo = NSProcessInfo.processInfo;
    BOOL isOnMac = [processInfo respondsToSelector:NSSelectorFromString(@"isMacCatalystApp")] &&
                    [[processInfo valueForKey:@"isMacCatalystApp"] boolValue];
    if (!isOnMac) {
        XCTAssertNotNil(device[@"modelNumber"]);
    }
#endif
}

- (void)testBreadcrumbInfo {
    BugsnagClient *client = [Bugsnag client];
    [client leaveBreadcrumbWithMessage:@"Hello World"];
    NSArray *breadcrumbs = [client collectBreadcrumbs];
    XCTAssertNotNil(breadcrumbs);
    XCTAssertTrue([breadcrumbs count] > 0);

    for (NSDictionary *crumb in breadcrumbs) {
        XCTAssertNotNil(crumb[@"message"]);
        XCTAssertNotNil(crumb[@"type"]);
        XCTAssertNotNil(crumb[@"timestamp"]);
    }
}

@end
