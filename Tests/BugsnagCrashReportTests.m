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
@property BugsnagCrashReport *report;
@end

@implementation BugsnagCrashReportTests

- (void)setUp {
    [super setUp];
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"report" ofType:@"json"];
    NSString *contents = [NSString stringWithContentsOfFile:path
                                                   encoding:NSUTF8StringEncoding
                                                      error:nil];
    NSDictionary *dictionary = [NSJSONSerialization
        JSONObjectWithData:[contents dataUsingEncoding:NSUTF8StringEncoding]
                   options:0
                     error:nil];
    self.report = [[BugsnagCrashReport alloc] initWithKSReport:dictionary];
}

- (void)tearDown {
    [super tearDown];
    self.report = nil;
}

- (void)testReadReleaseStage {
    XCTAssertEqualObjects(self.report.releaseStage, @"production");
}

- (void)testReadNotifyReleaseStages {
    XCTAssertEqualObjects(self.report.notifyReleaseStages,
                          (@[ @"production", @"development" ]));
}

- (void)testReadNotifyReleaseStagesSends {
    XCTAssertTrue([self.report shouldBeSent]);
}

- (void)testAddMetadataAddsNewTab {
    NSDictionary *metadata = @{@"color" : @"blue", @"beverage" : @"tea"};
    [self.report addMetadata:metadata toTabWithName:@"user prefs"];
    NSDictionary *prefs = self.report.metaData[@"user prefs"];
    XCTAssertEqual(@"blue", prefs[@"color"]);
    XCTAssertEqual(@"tea", prefs[@"beverage"]);
    XCTAssert([prefs count] == 2);
}

- (void)testAddMetadataMergesExistingTab {
    NSDictionary *oldMetadata = @{@"color" : @"red", @"food" : @"carrots"};
    [self.report addMetadata:oldMetadata toTabWithName:@"user prefs"];
    NSDictionary *metadata = @{@"color" : @"blue", @"beverage" : @"tea"};
    [self.report addMetadata:metadata toTabWithName:@"user prefs"];
    NSDictionary *prefs = self.report.metaData[@"user prefs"];
    XCTAssertEqual(@"blue", prefs[@"color"]);
    XCTAssertEqual(@"tea", prefs[@"beverage"]);
    XCTAssertEqual(@"carrots", prefs[@"food"]);
    XCTAssert([prefs count] == 3);
}

- (void)testAddAttributeAddsNewTab {
    [self.report addAttribute:@"color"
                    withValue:@"blue"
                toTabWithName:@"prefs"];
    NSDictionary *prefs = self.report.metaData[@"prefs"];
    XCTAssertEqual(@"blue", prefs[@"color"]);
}

- (void)testAddAttributeOverridesExistingValue {
    [self.report addAttribute:@"color" withValue:@"red" toTabWithName:@"prefs"];
    [self.report addAttribute:@"color"
                    withValue:@"blue"
                toTabWithName:@"prefs"];
    NSDictionary *prefs = self.report.metaData[@"prefs"];
    XCTAssertEqual(@"blue", prefs[@"color"]);
}

- (void)testAddAttributeRemovesValue {
    [self.report addAttribute:@"color" withValue:@"red" toTabWithName:@"prefs"];
    [self.report addAttribute:@"color" withValue:nil toTabWithName:@"prefs"];
    NSDictionary *prefs = self.report.metaData[@"prefs"];
    XCTAssertNil(prefs[@"color"]);
}

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

- (void)testDefaultErrorMessageNil {
    BugsnagCrashReport *report =
        [[BugsnagCrashReport alloc] initWithKSReport:@{}];
    NSDictionary *payload = [report toJson];
    XCTAssertEqualObjects(@"Exception",
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(@"", payload[@"exceptions"][0][@"message"]);
    XCTAssertEqualObjects(report.errorClass,
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(report.errorMessage,
                          payload[@"exceptions"][0][@"message"]);
}

- (void)testIncomplete {
    XCTAssertTrue([[[BugsnagCrashReport alloc] initWithKSReport:@{}] isIncomplete]);
    XCTAssertFalse([[[BugsnagCrashReport alloc] initWithKSReport:@{@"foo": @"bar"}] isIncomplete]);
}

- (void)testFallbackValues {
    BugsnagCrashReport *report =
        [[BugsnagCrashReport alloc] initWithKSReport:@{} fileMetadata:@"w-h-SomeErr thing"];
    XCTAssertTrue([report isIncomplete]);
    NSDictionary *payload = [report toJson];
    XCTAssertEqualObjects(@"SomeErr thing", payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(@"warning", payload[@"severity"]);
    XCTAssertEqualObjects(@NO, payload[@"unhandled"]);
}

- (void)testUnneededFallbackValues {
    BugsnagHandledState *state = [BugsnagHandledState handledStateWithSeverityReason:UserCallbackSetSeverity
                                                                            severity:BSGSeverityInfo
                                                                           attrValue:nil];
    NSDictionary *dict = @{@"user.handledState": [state toJson]};
    BugsnagCrashReport *report =
        [[BugsnagCrashReport alloc] initWithKSReport:dict fileMetadata:@"w-h-SomeErr thing"];
    XCTAssertFalse([report isIncomplete]);
    NSDictionary *payload = [report toJson];
    XCTAssertEqualObjects(@"SomeErr thing", payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(@"info", payload[@"severity"]);
    XCTAssertEqualObjects(@NO, payload[@"unhandled"]);
}

- (void)testUnhandledFallbackValues {
    BugsnagCrashReport *report =
    [[BugsnagCrashReport alloc] initWithKSReport:@{} fileMetadata:@"foofoo-e-u-SomeErr thing"];
    XCTAssertTrue([report isIncomplete]);
    NSDictionary *payload = [report toJson];
    XCTAssertEqualObjects(@"SomeErr thing", payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(@"error", payload[@"severity"]);
    XCTAssertEqualObjects(@YES, payload[@"unhandled"]);
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

- (void)testEnhancedErrorMessageIgnoresStackFrames {
    BugsnagCrashReport *report = [[BugsnagCrashReport alloc] initWithKSReport:@{
        @"crash" : @{
            @"threads" : @[ @{
                @"crashed" : @YES,
                @"notable_addresses" : @{
                    @"stack@2342387" : @{
                        @"address" : @4511086448,
                        @"type" : @"string",
                        @"value" : @"some nonsense"
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
    XCTAssertNotNil(report);
}

- (void)testUnhandledReportDepth {
    // unhandled reports should calculate their own depth
    NSDictionary *dict = @{@"user.state.crash.depth": @2};
    BugsnagCrashReport *report = [[BugsnagCrashReport alloc] initWithKSReport:dict];
    XCTAssertEqual(report.depth, 0);
}

- (void)testHandledReportDepth {
    // handled reports should use the serialised depth
    BugsnagHandledState *state = [BugsnagHandledState handledStateWithSeverityReason:HandledException];
    NSDictionary *dict = @{@"user.state.crash.depth": @2, @"user.handledState": [state toJson]};
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

- (void)testNoReportMetaData {
    BugsnagCrashReport *report = [[BugsnagCrashReport alloc] initWithKSReport:@{}];
    XCTAssertNotNil(report.metaData);
    XCTAssertEqual(report.metaData.count, 0);
}

- (void)testAppVersion {
    NSDictionary *dictionary = [self.report toJson];
    XCTAssertEqualObjects(@"1.0", dictionary[@"app"][@"version"]);
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

@end
