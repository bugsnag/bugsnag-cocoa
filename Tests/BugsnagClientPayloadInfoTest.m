//
//  BugsnagClientPayloadInfoTest.m
//  Tests
//
//  Created by Jamie Lynch on 30/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "Bugsnag.h"
#import "BugsnagConfiguration.h"
#import "BugsnagTestConstants.h"

@interface Bugsnag ()
+ (BugsnagClient *)client;
@end

@interface BugsnagClient ()
- (NSDictionary *)collectAppWithState;
- (NSDictionary *)collectDeviceWithState;
- (NSArray *)collectBreadcrumbs;
- (NSArray *)collectThreads;
@property NSString *codeBundleId;
@end

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

    NSArray *observedKeys = [[app allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSArray *expectedKeys = @[@"bundleVersion", @"codeBundleId", @"dsymUUIDs", @"duration", @"durationInForeground",
            @"id", @"inForeground", @"releaseStage", @"type", @"version"];
    XCTAssertEqualObjects(observedKeys, expectedKeys);
}

- (void)testDeviceInfo {
    BugsnagClient *client = [Bugsnag client];
    NSDictionary *device = [client collectDeviceWithState];
    XCTAssertNotNil(device);

    NSArray *observedKeys = [[device allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSMutableArray *expectedKeys = [@[@"freeDisk", @"freeMemory", @"id", @"jailbroken", @"locale", @"manufacturer",
            @"model", @"osName", @"osVersion", @"runtimeVersions", @"time", @"totalMemory"] mutableCopy];

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
    [expectedKeys addObject:@"modelNumber"];
#endif

    XCTAssertEqualObjects(observedKeys, [expectedKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]);
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
