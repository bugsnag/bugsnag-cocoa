//
//  BugsnagDeviceTest.m
//  Tests
//
//  Created by Jamie Lynch on 01/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "BugsnagAppWithState.h"
#import "BugsnagConfiguration.h"
#import "BugsnagTestConstants.h"

@interface BugsnagApp ()
+ (BugsnagApp *)appWithDictionary:(NSDictionary *)event
                           config:(BugsnagConfiguration *)config
                     codeBundleId:(NSString *)codeBundleId;
- (NSDictionary *)toDict;
@end

@interface BugsnagAppWithState ()
+ (BugsnagAppWithState *)appWithDictionary:(NSDictionary *)event
                                    config:(BugsnagConfiguration *)config
                              codeBundleId:(NSString *)codeBundleId;
+ (BugsnagAppWithState *)appWithOomData:(NSDictionary *)event;
+ (BugsnagAppWithState *)appFromJson:(NSDictionary *)json;
- (NSDictionary *)toDict;
@end

@interface BugsnagAppTest : XCTestCase
@property NSDictionary *data;
@property BugsnagConfiguration *config;
@property NSString *codeBundleId;
@end

@implementation BugsnagAppTest

- (void)setUp {
    [super setUp];
    // this mocks the structure of a KSCrashReport which is persisted to disk
    // and used to populate the contents of BugsnagApp/BugsnagAppWithState
    self.data = @{
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

    self.config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    self.config.appType = @"iOS";
    self.config.appVersion = @"3.14.159";
    self.codeBundleId = @"bundle-123";
}

- (void)testApp {
    BugsnagApp *app = [BugsnagApp appWithDictionary:self.data config:self.config codeBundleId:self.codeBundleId];

    // verify stateless fields
    XCTAssertEqualObjects(@"1", app.bundleVersion);
    XCTAssertEqualObjects(@"bundle-123", app.codeBundleId);
    XCTAssertEqualObjects(@"dsym-uuid-123", app.dsymUuid);
    XCTAssertEqualObjects(@"com.example.foo.MyIosApp", app.id);
    XCTAssertEqualObjects(@"beta", app.releaseStage);
    XCTAssertEqualObjects(@"iOS", app.type);
    XCTAssertEqualObjects(@"3.14.159", app.version);
}

- (void)testAppWithState {
    BugsnagAppWithState *app = [BugsnagAppWithState appWithDictionary:self.data config:self.config codeBundleId:self.codeBundleId];

    // verify stateful fields
    XCTAssertEqualObjects(@7000, app.duration);
    XCTAssertEqualObjects(@2000, app.durationInForeground);
    XCTAssertTrue(app.inForeground);

    // verify stateless fields
    XCTAssertEqualObjects(@"1", app.bundleVersion);
    XCTAssertEqualObjects(@"bundle-123", app.codeBundleId);
    XCTAssertEqualObjects(@"dsym-uuid-123", app.dsymUuid);
    XCTAssertEqualObjects(@"com.example.foo.MyIosApp", app.id);
    XCTAssertEqualObjects(@"beta", app.releaseStage);
    XCTAssertEqualObjects(@"iOS", app.type);
    XCTAssertEqualObjects(@"3.14.159", app.version);
}

- (void)testAppToDict {
    self.config.appVersion = nil; // Check that the system value is picked up
    BugsnagApp *app = [BugsnagApp appWithDictionary:self.data config:self.config codeBundleId:self.codeBundleId];
    NSDictionary *dict = [app toDict];

    // verify stateless fields
    XCTAssertEqualObjects(@"1", dict[@"bundleVersion"]);
    XCTAssertEqualObjects(@"bundle-123", dict[@"codeBundleId"]);
    XCTAssertEqualObjects(@[@"dsym-uuid-123"], dict[@"dsymUUIDs"]);
    XCTAssertEqualObjects(@"com.example.foo.MyIosApp", dict[@"id"]);
    XCTAssertEqualObjects(@"beta", dict[@"releaseStage"]);
    XCTAssertEqualObjects(@"iOS", dict[@"type"]);
    XCTAssertEqualObjects(@"5.6.3", dict[@"version"]);
}

- (void)testAppWithStateToDict {
    self.config.appVersion = nil; // Check that the system value is picked up
    BugsnagAppWithState *app = [BugsnagAppWithState appWithDictionary:self.data config:self.config codeBundleId:self.codeBundleId];
    NSDictionary *dict = [app toDict];

    // verify stateful fields
    XCTAssertEqualObjects(@7000, dict[@"duration"]);
    XCTAssertEqualObjects(@2000, dict[@"durationInForeground"]);
    XCTAssertTrue([dict[@"inForeground"] boolValue]);

    // verify stateless fields
    XCTAssertEqualObjects(@"1", dict[@"bundleVersion"]);
    XCTAssertEqualObjects(@"bundle-123", dict[@"codeBundleId"]);
    XCTAssertEqualObjects(@[@"dsym-uuid-123"], dict[@"dsymUUIDs"]);
    XCTAssertEqualObjects(@"com.example.foo.MyIosApp", dict[@"id"]);
    XCTAssertEqualObjects(@"beta", dict[@"releaseStage"]);
    XCTAssertEqualObjects(@"iOS", dict[@"type"]);
    XCTAssertEqualObjects(@"5.6.3", dict[@"version"]);
}

- (void)testAppFromOOM {
    NSDictionary *oomData = @{
            @"id": @"com.example.foo.MyIosApp",
            @"releaseStage": @"beta",
            @"version": @"5.6.3",
            @"bundleVersion": @"1",
            @"codeBundleId": @"bundle-123",
            @"inForeground": @YES,
            @"type": @"iOS"
    };

    BugsnagAppWithState *app = [BugsnagAppWithState appWithOomData:oomData];

    // verify stateful fields
    XCTAssertNil(app.duration);
    XCTAssertNil(app.durationInForeground);
    XCTAssertTrue(app.inForeground);

    // verify stateless fields
    XCTAssertEqualObjects(@"1", app.bundleVersion);
    XCTAssertEqualObjects(@"bundle-123", app.codeBundleId);
    XCTAssertNil(app.dsymUuid);
    XCTAssertEqualObjects(@"com.example.foo.MyIosApp", app.id);
    XCTAssertEqualObjects(@"beta", app.releaseStage);
    XCTAssertEqualObjects(@"iOS", app.type);
    XCTAssertEqualObjects(@"5.6.3", app.version);
}

- (void)testAppFromJson {
    NSDictionary *json = @{
            @"duration": @7000,
            @"durationInForeground": @2000,
            @"inForeground": @YES,
            @"bundleVersion": @"1",
            @"codeBundleId": @"bundle-123",
            @"dsymUUIDs": @[@"dsym-uuid-123"],
            @"id": @"com.example.foo.MyIosApp",
            @"releaseStage": @"beta",
            @"type": @"iOS",
            @"version": @"5.6.3",
    };
    BugsnagAppWithState *app = [BugsnagAppWithState appFromJson:json];
    XCTAssertNotNil(app);

    // verify stateful fields
    XCTAssertEqualObjects(@7000, app.duration);
    XCTAssertEqualObjects(@2000, app.durationInForeground);
    XCTAssertTrue(app.inForeground);

    // verify stateless fields
    XCTAssertEqualObjects(@"1", app.bundleVersion);
    XCTAssertEqualObjects(@"bundle-123", app.codeBundleId);
    XCTAssertEqualObjects(@"dsym-uuid-123", app.dsymUuid);
    XCTAssertEqualObjects(@"com.example.foo.MyIosApp", app.id);
    XCTAssertEqualObjects(@"beta", app.releaseStage);
    XCTAssertEqualObjects(@"iOS", app.type);
    XCTAssertEqualObjects(@"5.6.3", app.version);
}

- (void)testAppVersionPrecedence {
    // default to system.CFBundleShortVersionString
    self.config.appVersion = nil;
    BugsnagAppWithState *app = [BugsnagAppWithState appWithDictionary:self.data config:self.config codeBundleId:self.codeBundleId];
    XCTAssertEqualObjects(@"5.6.3", app.version);

    // 2nd precedence is config.appVersion
    self.config.appVersion = @"4.2.6";
    app = [BugsnagAppWithState appWithDictionary:self.data config:self.config codeBundleId:self.codeBundleId];
    XCTAssertEqualObjects(@"4.2.6", app.version);

    // 1st precedence is user.config.appVersion
    NSMutableDictionary *data = [self.data mutableCopy];
    data[@"user"] = @{
            @"config": @{
                    @"appVersion": @"1.2.3"
            }
    };
    app = [BugsnagAppWithState appWithDictionary:data config:self.config codeBundleId:self.codeBundleId];
    XCTAssertEqualObjects(@"1.2.3", app.version);
}

@end
