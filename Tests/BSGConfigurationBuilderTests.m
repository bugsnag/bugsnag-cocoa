#import "BSGConfigurationBuilder.h"
#import "BugsnagConfiguration.h"
#import <XCTest/XCTest.h>

@interface BSGConfigurationBuilderTests : XCTestCase
@end

@implementation BSGConfigurationBuilderTests

- (void)testDecodeEmptyOptions {
    BugsnagConfiguration *config = [BSGConfigurationBuilder configurationFromOptions:@{}];
    XCTAssertNil(config);
}

- (void)testDecodeApiKey {
    BugsnagConfiguration *config = [BSGConfigurationBuilder
        configurationFromOptions:@{@"apiKey" : @"foo123"}];
    XCTAssertEqualObjects(@"foo123", config.apiKey);
}

- (void)testDecodeDefaultAutoNotify {
    BugsnagConfiguration *config = [BSGConfigurationBuilder
        configurationFromOptions:@{@"apiKey" : @"foo123"}];
    XCTAssertEqualObjects(@"foo123", config.apiKey);
    XCTAssertTrue(config.autoNotify);
}

- (void)testDecodeDefaultAutoCaptureSessions {
    BugsnagConfiguration *config = [BSGConfigurationBuilder
        configurationFromOptions:@{@"apiKey" : @"foo123"}];
    XCTAssertEqualObjects(@"foo123", config.apiKey);
    XCTAssertTrue(config.shouldAutoCaptureSessions);
}

- (void)testDecodeDefaultAutoCollectBreadcrumbs {
    BugsnagConfiguration *config = [BSGConfigurationBuilder
        configurationFromOptions:@{@"apiKey" : @"foo123"}];
    XCTAssertEqualObjects(@"foo123", config.apiKey);
    XCTAssertTrue(config.automaticallyCollectBreadcrumbs);
}

- (void)testDecodeDefaultEndpoints {
    BugsnagConfiguration *config = [BSGConfigurationBuilder
        configurationFromOptions:@{@"apiKey" : @"foo123"}];
    XCTAssertEqualObjects(@"foo123", config.apiKey);
    XCTAssertEqualObjects([NSURL URLWithString:@"https://notify.bugsnag.com/"],
                          config.notifyURL);
    XCTAssertEqualObjects([NSURL URLWithString:@"https://sessions.bugsnag.com"],
                          config.sessionURL);
}

- (void)testDecodeDefaultReleaseStage {
    BugsnagConfiguration *config = [BSGConfigurationBuilder
        configurationFromOptions:@{@"apiKey" : @"foo123"}];
    XCTAssertEqualObjects(@"foo123", config.apiKey);
#if DEBUG
    XCTAssertEqualObjects(@"development", config.releaseStage);
#else
    XCTAssertEqualObjects(@"production", config.releaseStage);
#endif
}

- (void)testDecodeDefaultNotifyReleaseStages {
    BugsnagConfiguration *config = [BSGConfigurationBuilder
        configurationFromOptions:@{@"apiKey" : @"foo123"}];
    XCTAssertEqualObjects(@"foo123", config.apiKey);
    XCTAssertNil(config.notifyReleaseStages);
}

- (void)testDecodeDefaultReportOOMs {
    BugsnagConfiguration *config = [BSGConfigurationBuilder
        configurationFromOptions:@{@"apiKey" : @"foo123"}];
    XCTAssertEqualObjects(@"foo123", config.apiKey);
    XCTAssertTrue(config.reportOOMs);
}

- (void)testDecodeDefaultReportBackgroundOOMs {
    BugsnagConfiguration *config = [BSGConfigurationBuilder
        configurationFromOptions:@{@"apiKey" : @"foo123"}];
    XCTAssertEqualObjects(@"foo123", config.apiKey);
    XCTAssertFalse(config.reportBackgroundOOMs);
}

- (void)testDecodeEmptyApiKey {
    BugsnagConfiguration *config = [BSGConfigurationBuilder
        configurationFromOptions:@{@"apiKey" : @""}];
    XCTAssertNil(config);
}

- (void)testDecodeInvalidTypeApiKey {
    BugsnagConfiguration *config = [BSGConfigurationBuilder
        configurationFromOptions:@{@"apiKey" : @[ @"one", @"two" ]}];
    XCTAssertNil(config);
}

- (void)testDecodeAutoNotifyWithoutApiKey {
    BugsnagConfiguration *config = [BSGConfigurationBuilder
        configurationFromOptions:@{@"autoNotify" : @NO}];
    XCTAssertNil(config);
    config = [BSGConfigurationBuilder
        configurationFromOptions:@{@"autoNotify" : @YES}];
    XCTAssertNil(config);
}

- (void)testDecodeAutoNotifyInvalidType {
    BugsnagConfiguration *config = [BSGConfigurationBuilder configurationFromOptions:@{
                                                                                          @"autoNotify" : @(67),
                                                                                          @"apiKey" : @"accfe1383",
                                                                                          }];
    XCTAssertNil(config);
}

- (void)testDecodeAutoNotify {
    BugsnagConfiguration *config =
        [BSGConfigurationBuilder configurationFromOptions:@{
            @"autoNotify" : @NO,
            @"apiKey" : @"34234136bff"
        }];
    XCTAssertNotNil(config);
    XCTAssertFalse(config.autoNotify);
    XCTAssertEqualObjects(@"34234136bff", config.apiKey);
    config = [BSGConfigurationBuilder configurationFromOptions:@{
        @"autoNotify" : @YES,
        @"apiKey" : @"83434136bff"
    }];
    XCTAssertNotNil(config);
    XCTAssertTrue(config.autoNotify);
    XCTAssertEqualObjects(@"83434136bff", config.apiKey);
}

- (void)testDecodeAutoCaptureSessionsWithoutApiKey {
    BugsnagConfiguration *config = [BSGConfigurationBuilder
        configurationFromOptions:@{@"autoSessions" : @NO}];
    XCTAssertNil(config);
    config = [BSGConfigurationBuilder
        configurationFromOptions:@{@"autoSessions" : @YES}];
    XCTAssertNil(config);
}

- (void)testDecodeAutoCaptureSessionsInvalidType {
    BugsnagConfiguration *config = [BSGConfigurationBuilder configurationFromOptions:@{
                                                                                          @"autoSessions" : @"NO",
                                                                                          @"apiKey" : @"ac928faeec"
                                                                                          }];
    XCTAssertNil(config);
}

- (void)testDecodeAutoCaptureSessions {
    BugsnagConfiguration *config =
        [BSGConfigurationBuilder configurationFromOptions:@{
            @"autoSessions" : @NO,
            @"apiKey" : @"2343a136bff"
        }];
    XCTAssertNotNil(config);
    XCTAssertFalse(config.shouldAutoCaptureSessions);
    XCTAssertEqualObjects(@"2343a136bff", config.apiKey);
    config = [BSGConfigurationBuilder configurationFromOptions:@{
        @"autoSessions" : @YES,
        @"apiKey" : @"2343a136bff"
    }];
    XCTAssertNotNil(config);
    XCTAssertTrue(config.shouldAutoCaptureSessions);
    XCTAssertEqualObjects(@"2343a136bff", config.apiKey);
}

- (void)testDecodeAutoCollectBreadcrumbs {
    BugsnagConfiguration *config =
        [BSGConfigurationBuilder configurationFromOptions:@{
            @"autoBreadcrumbs" : @NO,
            @"apiKey" : @"1343a136bff"
        }];
    XCTAssertNotNil(config);
    XCTAssertFalse(config.automaticallyCollectBreadcrumbs);
    XCTAssertEqualObjects(@"1343a136bff", config.apiKey);
    config = [BSGConfigurationBuilder configurationFromOptions:@{
        @"autoBreadcrumbs" : @YES,
        @"apiKey" : @"1343a136bff"
    }];
    XCTAssertNotNil(config);
    XCTAssertTrue(config.automaticallyCollectBreadcrumbs);
    XCTAssertEqualObjects(@"1343a136bff", config.apiKey);
}

- (void)testDecodeAutoCollectBreadcrumbsInvalidType {
    BugsnagConfiguration *config =
        [BSGConfigurationBuilder configurationFromOptions:@{
            @"autoBreadcrumbs" : @"foo",
            @"apiKey" : @"5628acc"
        }];
    XCTAssertNil(config);
}

- (void)testDecodeAutoCollectBreadcrumbsWithoutApiKey {
    BugsnagConfiguration *config = [BSGConfigurationBuilder
        configurationFromOptions:@{@"autoBreadcrumbs" : @NO}];
    XCTAssertNil(config);
    config = [BSGConfigurationBuilder
        configurationFromOptions:@{@"autoBreadcrumbs" : @YES}];
    XCTAssertNil(config);
}

- (void)testDecodeEndpointsInvalidTypes {
    BugsnagConfiguration *config = [BSGConfigurationBuilder configurationFromOptions:@{
        @"endpoints" : @"foo",
        @"apiKey" : @"5628acc"
    }];
    XCTAssertNil(config);
    config = [BSGConfigurationBuilder configurationFromOptions:@{
        @"endpoints" : @[ @"http://example.com", @"http://foo.example.com" ],
        @"apiKey" : @"5628acc"
    }];
    XCTAssertNil(config);
    config = [BSGConfigurationBuilder configurationFromOptions:@{
        @"endpoints" : @{},
        @"apiKey" : @"5628acc"
    }];
    XCTAssertNil(config);
}

- (void)testDecodeEndpointsUnknownKeys {
    BugsnagConfiguration *config = [BSGConfigurationBuilder configurationFromOptions:@{
        @"endpoints" : @{
            @"notify" : @"https://notify.example.com",
            @"sessions" : @"https://sessions.example.com",
            @"florps" : @"https://florps.example.com",
        },
        @"apiKey" : @"b128acce"
    }];
    XCTAssertNil(config);
}

- (void)testDecodeEndpointsWithoutApiKey {
    BugsnagConfiguration *config = [BSGConfigurationBuilder configurationFromOptions:@{
        @"endpoints" : @{
            @"notify" : @"https://notify.example.com",
            @"sessions" : @"https://sessions.example.com"
        },
    }];
    XCTAssertNil(config);
}

- (void)testDecodeEndpointsOnlyNotifySet {
    BugsnagConfiguration *config = [BSGConfigurationBuilder configurationFromOptions:@{
        @"endpoints" : @{
            @"notify" : @"https://notify.example.com",
        },
    }];
    XCTAssertNil(config);
}

- (void)testDecodeEndpointsOnlySessionsSet {
    BugsnagConfiguration *config = [BSGConfigurationBuilder configurationFromOptions:@{
        @"endpoints" : @{@"sessions" : @"https://sessions.example.com"},
    }];
    XCTAssertNil(config);
}

- (void)testDecodeEndpointsBothSet {
    BugsnagConfiguration *config =
        [BSGConfigurationBuilder configurationFromOptions:@{
            @"endpoints" : @{
                @"notify" : @"https://notify.example.com",
                @"sessions" : @"https://sessions.example.com"
            },
            @"apiKey" : @"b128acce"
        }];
    XCTAssertNotNil(config);
    XCTAssertEqualObjects(@"b128acce", config.apiKey);
    XCTAssertEqualObjects([NSURL URLWithString:@"https://notify.example.com"],
                          config.notifyURL);
    XCTAssertEqualObjects([NSURL URLWithString:@"https://sessions.example.com"],
                          config.sessionURL);
}

- (void)testDecodeReleaseStageWithoutApiKey {
    BugsnagConfiguration *config = [BSGConfigurationBuilder configurationFromOptions:@{
        @"releaseStage" : @[ @"three" ],
    }];
    XCTAssertNil(config);
}

- (void)testDecodeReleaseStageInvalidType {
    BugsnagConfiguration *config = [BSGConfigurationBuilder configurationFromOptions:@{
        @"releaseStage" : @NO,
        @"apiKey" : @"ac928faeec"
    }];
    XCTAssertNil(config);
}

- (void)testDecodeReleaseStage {
    BugsnagConfiguration *config =
        [BSGConfigurationBuilder configurationFromOptions:@{
            @"releaseStage" : @"debug",
            @"apiKey" : @"b128acce"
        }];
    XCTAssertNotNil(config);
    XCTAssertEqualObjects(@"b128acce", config.apiKey);
    XCTAssertEqualObjects(@"debug", config.releaseStage);
}

- (void)testDecodeNotifyReleaseStagesInvalidTypes {
    BugsnagConfiguration *config = [BSGConfigurationBuilder configurationFromOptions:@{
        @"notifyReleaseStages" : @[ @"beta", @"prod", @300 ],
        @"apiKey" : @"5628acc"
    }];
    XCTAssertNil(config);
    config = [BSGConfigurationBuilder configurationFromOptions:@{
        @"notifyReleaseStages" : @{@"name" : @"foo"},
        @"apiKey" : @"5628acc"
    }];
    XCTAssertNil(config);
    config = [BSGConfigurationBuilder configurationFromOptions:@{
        @"notifyReleaseStages" : @"fooo",
        @"apiKey" : @"5628acc"
    }];
    XCTAssertNil(config);
}

- (void)testDecodeNotifyReleaseStagesWithoutApiKey {
    BugsnagConfiguration *config = [BSGConfigurationBuilder configurationFromOptions:@{
        @"notifyReleaseStages" : @[ @"beta", @"prod" ],
    }];
    XCTAssertNil(config);
}

- (void)testDecodeNotifyReleaseStages {
    BugsnagConfiguration *config =
        [BSGConfigurationBuilder configurationFromOptions:@{
            @"notifyReleaseStages" : @[ @"beta", @"prod" ],
            @"apiKey" : @"b128acce"
        }];
    XCTAssertNotNil(config);
    XCTAssertEqualObjects(@"b128acce", config.apiKey);
    XCTAssertEqual(2, config.notifyReleaseStages.count);
    XCTAssertTrue([config.notifyReleaseStages containsObject:@"beta"]);
    XCTAssertTrue([config.notifyReleaseStages containsObject:@"prod"]);
}

- (void)testDecodeReportOOMsWithoutApiKey {
    BugsnagConfiguration *config = [BSGConfigurationBuilder configurationFromOptions:@{
        @"reportOOMs" : @NO,
    }];
    XCTAssertNil(config);
}

- (void)testDecodeReportOOMsInvalidType {
    BugsnagConfiguration *config = [BSGConfigurationBuilder configurationFromOptions:@{
        @"reportOOMs" : @[ @300 ],
        @"apiKey" : @"5628acc"
    }];
    XCTAssertNil(config);
    config = [BSGConfigurationBuilder configurationFromOptions:@{
        @"reportOOMs" : @{@"type" : @"dessert"},
        @"apiKey" : @"5628acc"
    }];
    XCTAssertNil(config);
    config = [BSGConfigurationBuilder configurationFromOptions:@{
        @"reportOOMs" : @"fooooo",
        @"apiKey" : @"5628acc"
    }];
    XCTAssertNil(config);
}

- (void)testDecodeReportOOMs {
    BugsnagConfiguration *config =
        [BSGConfigurationBuilder configurationFromOptions:@{
            @"reportOOMs" : @YES,
            @"apiKey" : @"5763651be"
        }];
    XCTAssertNotNil(config);
    XCTAssertEqualObjects(@"5763651be", config.apiKey);
    XCTAssertTrue(config.reportOOMs);
    config = [BSGConfigurationBuilder configurationFromOptions:@{
        @"reportOOMs" : @NO,
        @"apiKey" : @"a763651be"
    }];
    XCTAssertNotNil(config);
    XCTAssertEqualObjects(@"a763651be", config.apiKey);
    XCTAssertFalse(config.reportOOMs);
}

- (void)testDecodeReportBackgroundOOMs {
    BugsnagConfiguration *config =
        [BSGConfigurationBuilder configurationFromOptions:@{
            @"reportBackgroundOOMs" : @YES,
            @"apiKey" : @"5763651be"
        }];
    XCTAssertNotNil(config);
    XCTAssertEqualObjects(@"5763651be", config.apiKey);
    XCTAssertTrue(config.reportBackgroundOOMs);
    config = [BSGConfigurationBuilder configurationFromOptions:@{
        @"reportBackgroundOOMs" : @NO,
        @"apiKey" : @"a763651be"
    }];
    XCTAssertNotNil(config);
    XCTAssertEqualObjects(@"a763651be", config.apiKey);
    XCTAssertFalse(config.reportBackgroundOOMs);
}

- (void)testDecodeReportBackgroundOOMsWithoutApiKey {
    BugsnagConfiguration *config = [BSGConfigurationBuilder configurationFromOptions:@{
        @"reportBackgroundOOMs" : @NO,
    }];
    XCTAssertNil(config);
}

- (void)testDecodeReportBackgroundOOMsInvalidType {
    BugsnagConfiguration *config = [BSGConfigurationBuilder configurationFromOptions:@{
        @"reportBackgroundOOMs" : @[ @300 ],
        @"apiKey" : @"5628acc"
    }];
    XCTAssertNil(config);
    config = [BSGConfigurationBuilder configurationFromOptions:@{
        @"reportBackgroundOOMs" : @{@"type" : @"dessert"},
        @"apiKey" : @"5628acc"
    }];
    XCTAssertNil(config);
    config = [BSGConfigurationBuilder configurationFromOptions:@{
        @"reportBackgroundOOMs" : @"fooooo",
        @"apiKey" : @"5628acc"
    }];
    XCTAssertNil(config);
}

- (void)testDecodeFullConfig {
    BugsnagConfiguration *config =
        [BSGConfigurationBuilder configurationFromOptions:@{
            @"autoNotify" : @NO,
            @"autoSessions" : @YES,
            @"autoBreadcrumbs" : @NO,
            @"endpoints" : @{
                @"notify" : @"https://reports.example.co",
                @"sessions" : @"https://sessions.example.co"
            },
            @"reportBackgroundOOMs" : @YES,
            @"reportOOMs" : @YES,
            @"releaseStage" : @"beta1",
            @"notifyReleaseStages" : @[ @"beta2", @"prod" ],
            @"apiKey" : @"5625251ceff"
        }];
    XCTAssertNotNil(config);
    XCTAssertEqualObjects(@"5625251ceff", config.apiKey);
    XCTAssertEqualObjects(@"beta1", config.releaseStage);
    XCTAssertTrue(config.shouldAutoCaptureSessions);
    XCTAssertTrue(config.reportOOMs);
    XCTAssertTrue(config.reportBackgroundOOMs);
    XCTAssertFalse(config.automaticallyCollectBreadcrumbs);
    XCTAssertFalse(config.autoNotify);
    XCTAssertEqual(2, config.notifyReleaseStages.count);
    XCTAssertTrue([config.notifyReleaseStages containsObject:@"beta2"]);
    XCTAssertTrue([config.notifyReleaseStages containsObject:@"prod"]);
    XCTAssertEqualObjects([NSURL URLWithString:@"https://reports.example.co"],
                          config.notifyURL);
    XCTAssertEqualObjects([NSURL URLWithString:@"https://sessions.example.co"],
                          config.sessionURL);
}

- (void)testDecodeFullConfigMinusApiKey {
    BugsnagConfiguration *config = [BSGConfigurationBuilder configurationFromOptions:@{
        @"autoNotify" : @NO,
        @"autoSessions" : @YES,
        @"autoBreadcrumbs" : @NO,
        @"endpoints" : @{
            @"notify" : @"https://reports.example.co",
            @"sessions" : @"https://sessions.example.co"
        },
        @"reportBackgroundOOMs" : @YES,
        @"reportOOMs" : @YES,
        @"releaseStage" : @"beta1",
        @"notifyReleaseStages" : @[ @"beta2", @"prod" ],
    }];
    XCTAssertNil(config);
}

- (void)testDecodeUnknownKeys {
    BugsnagConfiguration *config = [BSGConfigurationBuilder configurationFromOptions:@{
        @"giraffes" : @3,
        @"autoNotify" : @NO,
        @"autoSessions" : @YES,
        @"autoBreadcrumbs" : @NO,
        @"endpoints" : @{
            @"notify" : @"https://reports.example.co",
            @"sessions" : @"https://sessions.example.co"
        },
        @"reportBackgroundOOMs" : @YES,
        @"reportOOMs" : @YES,
        @"releaseStage" : @"beta1",
        @"notifyReleaseStages" : @[ @"beta2", @"prod" ],
        @"apiKey" : @"5625251ceff"
    }];
    XCTAssertNil(config);
}

@end
