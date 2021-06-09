#import <XCTest/XCTest.h>

#import <Bugsnag/Bugsnag.h>
#import "BSGConfigurationBuilder.h"
#import "BugsnagConfiguration+Private.h"
#import "BugsnagTestConstants.h"

@interface BSGConfigurationBuilderTests : XCTestCase
@end

@implementation BSGConfigurationBuilderTests

// MARK: - rejecting invalid plists

- (void)testDecodeEmptyApiKey {
    BugsnagConfiguration *configuration;
    XCTAssertNoThrow(configuration = [BSGConfigurationBuilder configurationFromOptions:@{@"apiKey": @""}]);
    XCTAssertEqualObjects(configuration.apiKey, @"");
    XCTAssertThrows([configuration validate]);
}

- (void)testDecodeInvalidTypeApiKey {
    XCTAssertThrows([BSGConfigurationBuilder
                     configurationFromOptions:@{@"apiKey": @[@"one"]}]);
}

- (void)testDecodeWithoutApiKey {
    BugsnagConfiguration *configuration;
    XCTAssertNoThrow(configuration = [BSGConfigurationBuilder configurationFromOptions:@{@"autoDetectErrors": @NO}]);
    XCTAssertNil(configuration.apiKey);
    XCTAssertFalse(configuration.autoDetectErrors);
    XCTAssertThrows([configuration validate]);
}

- (void)testDecodeUnknownKeys {
    BugsnagConfiguration *config = [BSGConfigurationBuilder configurationFromOptions:@{
            @"giraffes": @3,
            @"apiKey": DUMMY_APIKEY_32CHAR_1
    }];
    XCTAssertNotNil(config);
}

- (void)testDecodeEmptyOptions {
    XCTAssertNoThrow([BSGConfigurationBuilder configurationFromOptions:@{}]);
}

// MARK: - config loading

- (void)testDecodeDefaultValues {
    BugsnagConfiguration *config = [BSGConfigurationBuilder
            configurationFromOptions:@{@"apiKey": DUMMY_APIKEY_32CHAR_1}];
    XCTAssertNotNil(config);
    XCTAssertEqualObjects(DUMMY_APIKEY_32CHAR_1, config.apiKey);
    XCTAssertNotNil(config.appType);
    XCTAssertEqualObjects(config.appVersion, NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]);
    XCTAssertTrue(config.autoDetectErrors);
    XCTAssertTrue(config.autoTrackSessions);
    XCTAssertEqual(config.maxPersistedEvents, 32);
    XCTAssertEqual(config.maxPersistedSessions, 128);
    XCTAssertEqual(config.maxBreadcrumbs, 25);
    XCTAssertTrue(config.persistUser);
    XCTAssertEqualObjects(@[@"password"], [config.redactedKeys allObjects]);
    XCTAssertEqual(BSGThreadSendPolicyAlways, config.sendThreads);
    XCTAssertEqual(BSGEnabledBreadcrumbTypeAll, config.enabledBreadcrumbTypes);
    XCTAssertEqualObjects(@"https://notify.bugsnag.com", config.endpoints.notify);
    XCTAssertEqualObjects(@"https://sessions.bugsnag.com", config.endpoints.sessions);
    XCTAssertTrue(config.enabledErrorTypes.ooms);

#if DEBUG
    XCTAssertEqualObjects(@"development", config.releaseStage);
#else
    XCTAssertEqualObjects(@"production", config.releaseStage);
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
                    @"maxPersistedEvents": @29,
                    @"maxPersistedSessions": @19,
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
    XCTAssertEqual(29, config.maxPersistedEvents);
    XCTAssertEqual(19, config.maxPersistedSessions);
    XCTAssertEqual(27, config.maxBreadcrumbs);
    XCTAssertFalse(config.persistUser);
    XCTAssertEqualObjects(@[@"foo"], config.redactedKeys);
    XCTAssertEqual(BSGThreadSendPolicyNever, config.sendThreads);
    XCTAssertEqualObjects(@"beta1", config.releaseStage);
    XCTAssertEqualObjects(@"https://reports.example.co", config.endpoints.notify);
    XCTAssertEqualObjects(@"https://sessions.example.co", config.endpoints.sessions);

    NSArray *releaseStages = @[@"beta2", @"prod"];
    XCTAssertEqualObjects(releaseStages, config.enabledReleaseStages);
    XCTAssertTrue(config.enabledErrorTypes.ooms);

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
                    @"maxPersistedEvents": @29,
                    @"maxPersistedSessions": @19,
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
