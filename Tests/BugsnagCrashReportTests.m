//
//  BugsnagCrashReportTests.m
//  Bugsnag
//
//  Created by Simon Maynard on 12/1/14.
//
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "BSG_RFC3339DateTool.h"
#import "Bugsnag.h"
#import "BugsnagHandledState.h"
#import "BugsnagSession.h"


@interface BugsnagCrashReportTests : XCTestCase
@end

@implementation BugsnagCrashReportTests

- (void)testNotifyReleaseStagesSendsFromConfig {
    BugsnagConfiguration *config = [BugsnagConfiguration new];
    config.notifyReleaseStages = @[ @"foo" ];
    config.releaseStage = @"foo";
    BugsnagHandledState *state =
        [BugsnagHandledState handledStateWithSeverityReason:HandledException];
    BugsnagCrashReport *report =
        [[BugsnagCrashReport alloc] initWithErrorName:@"Bad error"
                                         errorMessage:@"it was so bad"
                                        configuration:config
                                             metaData:@{}
                                         handledState:state
                                              session:nil];
    XCTAssertTrue([report shouldBeSent]);
}

- (void)testNotifyReleaseStagesSkipsSendFromConfig {
    BugsnagConfiguration *config = [BugsnagConfiguration new];
    config.notifyReleaseStages = @[ @"foo", @"bar" ];
    config.releaseStage = @"not foo or bar";

    BugsnagHandledState *state =
        [BugsnagHandledState handledStateWithSeverityReason:HandledException];
    BugsnagCrashReport *report =
        [[BugsnagCrashReport alloc] initWithErrorName:@"Bad error"
                                         errorMessage:@"it was so bad"
                                        configuration:config
                                             metaData:@{}
                                         handledState:state
                                              session:nil];
    XCTAssertFalse([report shouldBeSent]);
}

- (void)testSessionJson {
    BugsnagConfiguration *config = [BugsnagConfiguration new];

    BugsnagHandledState *state =
        [BugsnagHandledState handledStateWithSeverityReason:HandledException];
    NSDate *now = [NSDate date];
    BugsnagSession *bugsnagSession = [[BugsnagSession alloc] initWithId:@"123"
                                                              startDate:now
                                                                   user:nil
                                                           autoCaptured:NO];
    bugsnagSession.handledCount = 2;
    bugsnagSession.unhandledCount = 1;

    BugsnagCrashReport *report =
        [[BugsnagCrashReport alloc] initWithErrorName:@"Bad error"
                                         errorMessage:@"it was so bad"
                                        configuration:config
                                             metaData:@{}
                                         handledState:state
                                              session:bugsnagSession];
    NSDictionary *json = [report toJson];
    XCTAssertNotNil(json);

    NSDictionary *session = json[@"session"];
    XCTAssertNotNil(session);
    XCTAssertEqualObjects(@"123", session[@"id"]);
    XCTAssertEqualObjects([BSG_RFC3339DateTool stringFromDate:now],
                          session[@"startedAt"]);

    NSDictionary *events = session[@"events"];
    XCTAssertNotNil(events);
    XCTAssertEqualObjects(@2, events[@"handled"]);
    XCTAssertEqualObjects(@1, events[@"unhandled"]);
}

- (void)testDefaultErrorMessageNilForEmptyThreads {
    BugsnagCrashReport *report = [[BugsnagCrashReport alloc] initWithKSReport:@{
        @"threads" : @[]
    }];
    NSDictionary *payload = [report toJson];
    XCTAssertEqualObjects(@"Exception",
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(@"", payload[@"exceptions"][0][@"message"]);
    XCTAssertEqualObjects(report.errorClass,
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(report.errorMessage,
                          payload[@"exceptions"][0][@"message"]);
}

- (void)testEnhancedErrorMessageNilForEmptyNotableAddresses {
    BugsnagCrashReport *report = [[BugsnagCrashReport alloc] initWithKSReport:@{
        @"threads" : @[ @{@"crashed" : @YES, @"notable_addresses" : @{}} ]
    }];
    NSDictionary *payload = [report toJson];
    XCTAssertEqualObjects(@"Exception",
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(@"", payload[@"exceptions"][0][@"message"]);
    XCTAssertEqualObjects(report.errorClass,
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(report.errorMessage,
                          payload[@"exceptions"][0][@"message"]);
}

- (void)testEnhancedErrorMessageForFatalErrorWithoutAdditionalMessage {
    BugsnagCrashReport *report = [[BugsnagCrashReport alloc] initWithKSReport:@{
        @"crash" : @{
            @"threads" : @[ @{
                @"crashed" : @YES,
                @"notable_addresses" : @{
                    @"r14" : @{
                        @"address" : @4511089532,
                        @"type" : @"string",
                        @"value" : @"fatal error"
                    }
                }
            } ]
        }
    }];
    NSDictionary *payload = [report toJson];
    XCTAssertEqualObjects(@"fatal error",
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(@"", payload[@"exceptions"][0][@"message"]);
    XCTAssertEqualObjects(report.errorClass,
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(report.errorMessage,
                          payload[@"exceptions"][0][@"message"]);
}

- (void)testEnhancedErrorMessageForAssertionWithoutAdditionalMessage {
    BugsnagCrashReport *report = [[BugsnagCrashReport alloc] initWithKSReport:@{
        @"crash" : @{
            @"threads" : @[ @{
                @"crashed" : @YES,
                @"notable_addresses" : @{
                    @"r14" : @{
                        @"address" : @4511089532,
                        @"type" : @"string",
                        @"value" : @"assertion failed"
                    }
                }
            } ]
        }
    }];
    NSDictionary *payload = [report toJson];
    XCTAssertEqualObjects(@"assertion failed",
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(@"", payload[@"exceptions"][0][@"message"]);
    XCTAssertEqualObjects(report.errorClass,
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(report.errorMessage,
                          payload[@"exceptions"][0][@"message"]);
}

- (void)testEnhancedErrorMessageForAssertionError {
    for (NSString *assertionName in @[
             @"assertion failed", @"Assertion failed", @"fatal error",
             @"Fatal error"
         ]) {
        BugsnagCrashReport *report =
            [[BugsnagCrashReport alloc] initWithKSReport:@{
                @"crash" : @{
                    @"threads" : @[ @{
                        @"crashed" : @YES,
                        @"notable_addresses" : @{
                            @"x9" : @{
                                @"address" : @4511086448,
                                @"type" : @"string",
                                @"value" : @"Something went wrong"
                            },
                            @"r16" : @{
                                @"address" : @4511089532,
                                @"type" : @"string",
                                @"value" : assertionName
                            }
                        }
                    } ]
                }
            }];
        NSDictionary *payload = [report toJson];
        XCTAssertEqualObjects(assertionName,
                              payload[@"exceptions"][0][@"errorClass"]);
        XCTAssertEqualObjects(@"Something went wrong",
                              payload[@"exceptions"][0][@"message"]);
        XCTAssertEqualObjects(report.errorClass,
                              payload[@"exceptions"][0][@"errorClass"]);
        XCTAssertEqualObjects(report.errorMessage,
                              payload[@"exceptions"][0][@"message"]);
    }
}

- (void)testEnhancedErrorMessageIgnoresFilePaths {
    BugsnagCrashReport *report = [[BugsnagCrashReport alloc] initWithKSReport:@{
        @"crash" : @{
            @"threads" : @[ @{
                @"crashed" : @YES,
                @"notable_addresses" : @{
                    @"x9" : @{
                        @"address" : @4511086448,
                        @"type" : @"string",
                        @"value" : @"/usr/include/lib/something.swift"
                    },
                    @"r16" : @{
                        @"address" : @4511089532,
                        @"type" : @"string",
                        @"value" : @"fatal error"
                    }
                }
            } ]
        }
    }];
    NSDictionary *payload = [report toJson];
    XCTAssertEqualObjects(@"fatal error",
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(@"", payload[@"exceptions"][0][@"message"]);
    XCTAssertEqualObjects(report.errorClass,
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(report.errorMessage,
                          payload[@"exceptions"][0][@"message"]);
}

- (void)testEnhancedErrorMessageIgnoresNonStrings {
    BugsnagCrashReport *report = [[BugsnagCrashReport alloc] initWithKSReport:@{
        @"crash" : @{
            @"threads" : @[ @{
                @"crashed" : @YES,
                @"notable_addresses" : @{
                    @"x9" : @{
                        @"address" : @4511086448,
                        @"type" : @"long",
                        @"value" : @"A message from beyond"
                    },
                    @"r16" : @{
                        @"address" : @4511089532,
                        @"type" : @"string",
                        @"value" : @"fatal error"
                    }
                }
            } ]
        }
    }];
    NSDictionary *payload = [report toJson];
    XCTAssertEqualObjects(@"fatal error",
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(@"", payload[@"exceptions"][0][@"message"]);
    XCTAssertEqualObjects(report.errorClass,
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(report.errorMessage,
                          payload[@"exceptions"][0][@"message"]);
}

- (void)testEnhancedErrorMessageConcatenatesMultipleMessages {
    BugsnagCrashReport *report = [[BugsnagCrashReport alloc] initWithKSReport:@{
        @"crash" : @{
            @"threads" : @[ @{
                @"crashed" : @YES,
                @"notable_addresses" : @{
                    @"x9" : @{
                        @"address" : @4511086448,
                        @"type" : @"string",
                        @"value" : @"A message from beyond"
                    },
                    @"r14" : @{
                        @"address" : @4511086448,
                        @"type" : @"string",
                        @"value" : @"Wo0o0o"
                    },
                    @"r16" : @{
                        @"address" : @4511089532,
                        @"type" : @"string",
                        @"value" : @"Fatal error"
                    }
                }
            } ]
        }
    }];
    NSDictionary *payload = [report toJson];
    XCTAssertEqualObjects(@"Fatal error",
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(@"A message from beyond | Wo0o0o",
                          payload[@"exceptions"][0][@"message"]);
    XCTAssertEqualObjects(report.errorClass,
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(report.errorMessage,
                          payload[@"exceptions"][0][@"message"]);
}

- (void)testEnhancedErrorMessageIgnoresUnknownAssertionTypes {
    BugsnagCrashReport *report = [[BugsnagCrashReport alloc] initWithKSReport:@{
        @"crash" : @{
            @"threads" : @[ @{
                @"crashed" : @YES,
                @"notable_addresses" : @{
                    @"x9" : @{
                        @"address" : @4511086448,
                        @"type" : @"string",
                        @"value" : @"A message from beyond"
                    },
                    @"r14" : @{
                        @"address" : @4511086448,
                        @"type" : @"string",
                        @"value" : @"Wo0o0o"
                    }
                }
            } ]
        }
    }];
    NSDictionary *payload = [report toJson];
    XCTAssertEqualObjects(@"Exception",
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(@"", payload[@"exceptions"][0][@"message"]);
    XCTAssertEqualObjects(report.errorClass,
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(report.errorMessage,
                          payload[@"exceptions"][0][@"message"]);
}

- (void)testEmptyReport {
    BugsnagCrashReport *report = [[BugsnagCrashReport alloc] initWithKSReport:@{}];
    XCTAssertNil(report);
}

- (void)testUnhandledReportDepth {
    // unhandled reports should calculate their own depth
    NSDictionary *dict = @{@"user.depth": @2};
    BugsnagCrashReport *report = [[BugsnagCrashReport alloc] initWithKSReport:dict];
    XCTAssertEqual(report.depth, 0);
}

- (void)testHandledReportDepth {
    // handled reports should use the serialised depth
    BugsnagHandledState *state = [BugsnagHandledState handledStateWithSeverityReason:HandledException];
    NSDictionary *dict = @{@"user.depth": @2, @"user.handledState": [state toJson]};
    BugsnagCrashReport *report = [[BugsnagCrashReport alloc] initWithKSReport:dict];
    XCTAssertEqual(report.depth, 2);
}

- (void)testUnhandledReportSeverity {
    // unhandled reports should calculate their own severity
    NSDictionary *dict = @{@"user.state.crash.severity": @"info"};
    BugsnagCrashReport *report = [[BugsnagCrashReport alloc] initWithKSReport:dict];
    XCTAssertEqual(report.severity, BSGSeverityError);
}

- (void)testHandledReportSeverity {
    // handled reports should use the serialised depth
    BugsnagHandledState *state = [BugsnagHandledState handledStateWithSeverityReason:HandledException];
    NSDictionary *dict = @{@"user.state.crash.severity": @"info", @"user.handledState": [state toJson]};
    BugsnagCrashReport *report = [[BugsnagCrashReport alloc] initWithKSReport:dict];
    XCTAssertEqual(report.severity, BSGSeverityWarning);
}

- (void)testHandledReportMetaData {
    BugsnagHandledState *state = [BugsnagHandledState handledStateWithSeverityReason:HandledException];
    BugsnagMetaData *metaData = [BugsnagMetaData new];
    [metaData addAttribute:@"Foo" withValue:@"Bar" toTabWithName:@"Custom"];
    NSDictionary *dict = @{@"user.handledState": [state toJson], @"user.metaData": [metaData toDictionary]};

    BugsnagCrashReport *report = [[BugsnagCrashReport alloc] initWithKSReport:dict];
    XCTAssertNotNil(report.metaData);
    XCTAssertEqual(report.metaData.count, 1);
    XCTAssertEqualObjects(report.metaData[@"Custom"][@"Foo"], @"Bar");
}

- (void)testUnhandledReportMetaData {
    BugsnagMetaData *metaData = [BugsnagMetaData new];
    [metaData addAttribute:@"Foo" withValue:@"Bar" toTabWithName:@"Custom"];
    NSDictionary *dict = @{@"user.metaData": [metaData toDictionary]};

    BugsnagCrashReport *report = [[BugsnagCrashReport alloc] initWithKSReport:dict];
    XCTAssertNotNil(report.metaData);
    XCTAssertEqual(report.metaData.count, 1);
    XCTAssertEqualObjects(report.metaData[@"Custom"][@"Foo"], @"Bar");
}

- (void)testAppVersionOverride {
    BugsnagCrashReport *overrideReport = [[BugsnagCrashReport alloc] initWithKSReport:@{
            @"system" : @{
                    @"CFBundleShortVersionString": @"1.1",
            },
            @"user": @{
                    @"config": @{
                            @"appVersion": @"1.2.3"
                    }
            }
    }];
    NSDictionary *dictionary = [overrideReport toJson];
    XCTAssertEqualObjects(@"1.2.3", dictionary[@"app"][@"version"]);
}

- (void)testReportAddAttr {
    BugsnagCrashReport *report = [[BugsnagCrashReport alloc] initWithKSReport:@{@"user.metaData": @{@"user": @{@"id": @"user id"}}}];
    [report addAttribute:@"foo" withValue:@"bar" toTabWithName:@"user"];
}

- (void)testReportAddMetadata {
    BugsnagCrashReport *report = [[BugsnagCrashReport alloc] initWithKSReport:@{@"user.metaData": @{@"user": @{@"id": @"user id"}}}];
    [report addMetadata:@{@"foo": @"bar"} toTabWithName:@"user"];
}

@end
