#import <XCTest/XCTest.h>

#import "BSGConfigurationBuilder.h"
#import "BugsnagConfiguration.h"
#import "BugsnagTestConstants.h"
#import "BugsnagEndpointConfiguration.h"
#import "BugsnagErrorTypes.h"
#import "BugsnagKeys.h"

@interface BSGConfigurationBuilderTests : XCTestCase
@end

@implementation BSGConfigurationBuilderTests

// MARK: - rejecting invalid plists

- (void)testDecodeEmptyApiKey {
    XCTAssertThrows([BSGConfigurationBuilder
                     configurationFromOptions:@{@"apiKey": @""}]);
}

- (void)testDecodeInvalidTypeApiKey {
    XCTAssertThrows([BSGConfigurationBuilder
                     configurationFromOptions:@{@"apiKey": @[@"one"]}]);
}

- (void)testDecodeWithoutApiKey {
    XCTAssertThrows([BSGConfigurationBuilder
                     configurationFromOptions:@{@"autoDetectErrors": @NO}]);
}

- (void)testDecodeUnknownKeys {
    BugsnagConfiguration *config = [BSGConfigurationBuilder configurationFromOptions:@{
            @"giraffes": @3,
            @"apiKey": DUMMY_APIKEY_32CHAR_1
    }];
    XCTAssertNotNil(config);
}

- (void)testDecodeEmptyOptions {
    XCTAssertThrows([BSGConfigurationBuilder
                     configurationFromOptions:@{}]);
}

// MARK: - config loading

- (void)testDecodeDefaultValues {
    BugsnagConfiguration *config = [BSGConfigurationBuilder
            configurationFromOptions:@{@"apiKey": DUMMY_APIKEY_32CHAR_1}];
    XCTAssertNotNil(config);
    XCTAssertEqualObjects(DUMMY_APIKEY_32CHAR_1, config.apiKey);
    XCTAssertNotNil(config.appType);
    XCTAssertNil(config.appVersion);
    XCTAssertTrue(config.autoDetectErrors);
    XCTAssertTrue(config.autoTrackSessions);
    XCTAssertEqual(25, config.maxBreadcrumbs);
    XCTAssertTrue(config.persistUser);
    XCTAssertEqualObjects(@[@"password"], [config.redactedKeys allObjects]);
    XCTAssertEqual(BSGThreadSendPolicyAlways, config.sendThreads);
    XCTAssertEqual(BSGEnabledBreadcrumbTypeAll, config.enabledBreadcrumbTypes);
    XCTAssertEqualObjects(@"https://notify.bugsnag.com", config.endpoints.notify);
    XCTAssertEqualObjects(@"https://sessions.bugsnag.com", config.endpoints.sessions);

#if DEBUG
    XCTAssertEqualObjects(@"development", config.releaseStage);
    XCTAssertFalse(config.enabledErrorTypes.ooms);
#else
    XCTAssertEqualObjects(@"production", config.releaseStage);
    XCTAssertTrue(config.enabledErrorTypes.ooms);
#endif

    XCTAssertNil(config.enabledReleaseStages);
    XCTAssertTrue(config.enabledErrorTypes.unhandledExceptions);
    XCTAssertTrue(config.enabledErrorTypes.signals);
    XCTAssertTrue(config.enabledErrorTypes.cppExceptions);
    XCTAssertTrue(config.enabledErrorTypes.machExceptions);
    XCTAssertTrue(config.enabledErrorTypes.unhandledRejections);
}

- (void)testDecodeFullConfig {
    BugsnagConfiguration *config =
            [BSGConfigurationBuilder configurationFromOptions:@{
                    @"apiKey": DUMMY_APIKEY_32CHAR_1,
                    @"appType": @"cocoa-custom",
                    @"appVersion": @"5.2.33",
                    @"autoDetectErrors": @NO,
                    @"autoTrackSessions": @NO,
                    @"bundleVersion": @"7.22",
                    @"endpoints": @{
                            @"notify": @"https://reports.example.co",
                            @"sessions": @"https://sessions.example.co"
                    },
                    @"enabledReleaseStages": @[@"beta2", @"prod"],
                    @"maxBreadcrumbs": @27,
                    @"persistUser": @NO,
                    @"redactedKeys": @[@"foo"],
                    @"sendThreads": @"never",
                    @"releaseStage": @"beta1",
            }];
    XCTAssertNotNil(config);
    XCTAssertEqualObjects(DUMMY_APIKEY_32CHAR_1, config.apiKey);
    XCTAssertEqualObjects(@"cocoa-custom", config.appType);
    XCTAssertEqualObjects(@"5.2.33", config.appVersion);
    XCTAssertFalse(config.autoDetectErrors);
    XCTAssertFalse(config.autoTrackSessions);
    XCTAssertEqualObjects(@"7.22", config.bundleVersion);
    XCTAssertEqual(27, config.maxBreadcrumbs);
    XCTAssertFalse(config.persistUser);
    XCTAssertEqualObjects(@[@"foo"], config.redactedKeys);
    XCTAssertEqual(BSGThreadSendPolicyNever, config.sendThreads);
    XCTAssertEqualObjects(@"beta1", config.releaseStage);
    XCTAssertEqualObjects(@"https://reports.example.co", config.endpoints.notify);
    XCTAssertEqualObjects(@"https://sessions.example.co", config.endpoints.sessions);

    NSArray *releaseStages = @[@"beta2", @"prod"];
    XCTAssertEqualObjects(releaseStages, config.enabledReleaseStages);

#if DEBUG
    XCTAssertFalse(config.enabledErrorTypes.ooms);
#else
    XCTAssertTrue(config.enabledErrorTypes.ooms);
#endif

    XCTAssertTrue(config.enabledErrorTypes.unhandledExceptions);
    XCTAssertTrue(config.enabledErrorTypes.signals);
    XCTAssertTrue(config.enabledErrorTypes.cppExceptions);
    XCTAssertTrue(config.enabledErrorTypes.machExceptions);
    XCTAssertTrue(config.enabledErrorTypes.unhandledRejections);
}

// MARK: - invalid config options

- (void)testInvalidConfigOptions {
    BugsnagConfiguration *config =
            [BSGConfigurationBuilder configurationFromOptions:@{
                    @"apiKey": DUMMY_APIKEY_32CHAR_1,
                    @"appType": @[],
                    @"appVersion": @99,
                    @"autoDetectErrors": @67,
                    @"autoTrackSessions": @"NO",
                    @"bundleVersion": @{},
                    @"endpoints": [NSNull null],
                    @"enabledReleaseStages": @[@"beta2", @"prod"],
                    @"enabledErrorTypes": @[@"ooms", @"signals"],
                    @"maxBreadcrumbs": @27,
                    @"persistUser": @"pomelo",
                    @"redactedKeys": @[@77],
                    @"sendThreads": @"nev",
                    @"releaseStage": @YES,
            }];
    XCTAssertNotNil(config); // no exception should be thrown when loading
}

- (void)testDecodeEnabledReleaseStagesInvalidTypes {
    BugsnagConfiguration *config = [BSGConfigurationBuilder configurationFromOptions:@{
            @"enabledReleaseStages": @[@"beta", @"prod", @300],
            @"apiKey": DUMMY_APIKEY_32CHAR_1
    }];
    XCTAssertNotNil(config);
    XCTAssertNil(config.enabledReleaseStages);

    config = [BSGConfigurationBuilder configurationFromOptions:@{
            @"enabledReleaseStages": @{@"name": @"foo"},
            @"apiKey": DUMMY_APIKEY_32CHAR_1
    }];
    XCTAssertNotNil(config);
    XCTAssertNil(config.enabledReleaseStages);

    config = [BSGConfigurationBuilder configurationFromOptions:@{
            @"enabledReleaseStages": @"fooo",
            @"apiKey": DUMMY_APIKEY_32CHAR_1
    }];
    XCTAssertNotNil(config);
    XCTAssertNil(config.enabledReleaseStages);
}

- (void)testDecodeEndpointsInvalidTypes {
    BugsnagConfiguration *config = [BSGConfigurationBuilder configurationFromOptions:@{
            @"endpoints": @"foo",
            @"apiKey": DUMMY_APIKEY_32CHAR_1
    }];
    XCTAssertNotNil(config);
    XCTAssertEqualObjects(@"https://notify.bugsnag.com", config.endpoints.notify);
    XCTAssertEqualObjects(@"https://sessions.bugsnag.com", config.endpoints.sessions);

    config = [BSGConfigurationBuilder configurationFromOptions:@{
            @"endpoints": @[@"http://example.com", @"http://foo.example.com"],
            @"apiKey": DUMMY_APIKEY_32CHAR_1
    }];
    XCTAssertNotNil(config);
    XCTAssertEqualObjects(@"https://notify.bugsnag.com", config.endpoints.notify);
    XCTAssertEqualObjects(@"https://sessions.bugsnag.com", config.endpoints.sessions);

    config = [BSGConfigurationBuilder configurationFromOptions:@{
            @"endpoints": @{},
            @"apiKey": DUMMY_APIKEY_32CHAR_1
    }];
    XCTAssertNotNil(config);
    XCTAssertEqualObjects(@"https://notify.bugsnag.com", config.endpoints.notify);
    XCTAssertEqualObjects(@"https://sessions.bugsnag.com", config.endpoints.sessions);
}

- (void)testDecodeEndpointsOnlyNotifySet {
    BugsnagConfiguration *config = [BSGConfigurationBuilder configurationFromOptions:@{
            @"apiKey": DUMMY_APIKEY_32CHAR_1,
            @"endpoints": @{
                    @"notify": @"https://notify.example.com",
            },
    }];
    XCTAssertNotNil(config);
    XCTAssertEqualObjects(@"https://notify.example.com", config.endpoints.notify);
    XCTAssertEqualObjects(@"https://sessions.bugsnag.com", config.endpoints.sessions);
}

- (void)testDecodeEndpointsOnlySessionsSet {
    BugsnagConfiguration *config = [BSGConfigurationBuilder configurationFromOptions:@{
            @"apiKey": DUMMY_APIKEY_32CHAR_1,
            @"endpoints": @{@"sessions": @"https://sessions.example.com"},
    }];
    XCTAssertNotNil(config);
    XCTAssertEqualObjects(@"https://notify.bugsnag.com", config.endpoints.notify);
    XCTAssertEqualObjects(@"https://sessions.example.com", config.endpoints.sessions);
}

- (void)testDecodeReleaseStageInvalidType {
    BugsnagConfiguration *config = [BSGConfigurationBuilder configurationFromOptions:@{
            @"releaseStage": @NO,
            @"apiKey": DUMMY_APIKEY_32CHAR_1
    }];
    XCTAssertNotNil(config);

#if DEBUG
    XCTAssertEqualObjects(@"development", config.releaseStage);
#else
    XCTAssertEqualObjects(@"production", config.releaseStage);
#endif
}

@end
