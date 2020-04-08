//
//  BugsnagEventTests.m
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
#import "BugsnagBaseUnitTest.h"
#import "BugsnagTestConstants.h"
#import "BugsnagTestsDummyClass.h"

@interface BugsnagSession ()
@property NSUInteger unhandledCount;
@property NSUInteger handledCount;
@end

@interface Bugsnag ()
+ (BugsnagConfiguration *)configuration;
@end

@interface BugsnagEvent ()
- (NSDictionary *_Nonnull)toJson;
- (BOOL)shouldBeSent;
@property (nonatomic, strong) BugsnagMetadata *metadata;
@property(readwrite) NSUInteger depth;
@end

@interface BugsnagMetadata ()
- (NSDictionary *_Nonnull)toDictionary;
@end

@interface BugsnagEventTests : BugsnagBaseUnitTest
@end

@implementation BugsnagEventTests

- (void)testEnabledReleaseStagesSendsFromConfig {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.enabledReleaseStages = @[ @"foo" ];
    config.releaseStage = @"foo";
    BugsnagHandledState *state =
        [BugsnagHandledState handledStateWithSeverityReason:HandledException];
    BugsnagEvent *event =
        [[BugsnagEvent alloc] initWithErrorName:@"Bad error"
                                         errorMessage:@"it was so bad"
                                        configuration:config
                                             metadata:nil
                                         handledState:state
                                              session:nil];
    XCTAssertTrue([event shouldBeSent]);
}

- (void)testEnabledReleaseStagesSkipsSendFromConfig {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.enabledReleaseStages = @[ @"foo", @"bar" ];
    config.releaseStage = @"not foo or bar";

    BugsnagHandledState *state =
        [BugsnagHandledState handledStateWithSeverityReason:HandledException];
    BugsnagEvent *event =
        [[BugsnagEvent alloc] initWithErrorName:@"Bad error"
                                         errorMessage:@"it was so bad"
                                        configuration:config
                                             metadata:nil
                                         handledState:state
                                              session:nil];
    XCTAssertFalse([event shouldBeSent]);
}

- (void)testSessionJson {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];

    BugsnagHandledState *state =
        [BugsnagHandledState handledStateWithSeverityReason:HandledException];
    NSDate *now = [NSDate date];
    BugsnagSession *bugsnagSession = [[BugsnagSession alloc] initWithId:@"123"
                                                              startDate:now
                                                                   user:nil
                                                           autoCaptured:NO];
    bugsnagSession.handledCount = 2;
    bugsnagSession.unhandledCount = 1;

    BugsnagEvent *event =
        [[BugsnagEvent alloc] initWithErrorName:@"Bad error"
                                         errorMessage:@"it was so bad"
                                        configuration:config
                                             metadata:nil
                                         handledState:state
                                              session:bugsnagSession];
    NSDictionary *json = [event toJson];
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
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:@{
        @"threads" : @[]
    }];
    NSDictionary *payload = [event toJson];
    XCTAssertEqualObjects(@"Exception",
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(@"", payload[@"exceptions"][0][@"message"]);
    XCTAssertEqualObjects(event.errors[0].errorClass,
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(event.errors[0].errorMessage,
                          payload[@"exceptions"][0][@"message"]);
}

- (void)testEnhancedErrorMessageNilForEmptyNotableAddresses {
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:@{
        @"threads" : @[ @{@"crashed" : @YES, @"notable_addresses" : @{}} ]
    }];
    NSDictionary *payload = [event toJson];
    XCTAssertEqualObjects(@"Exception",
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(@"", payload[@"exceptions"][0][@"message"]);
    XCTAssertEqualObjects(event.errors[0].errorClass,
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(event.errors[0].errorMessage,
                          payload[@"exceptions"][0][@"message"]);
}

- (void)testEnhancedErrorMessageForFatalErrorWithoutAdditionalMessage {
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:@{
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
    NSDictionary *payload = [event toJson];
    XCTAssertEqualObjects(@"fatal error",
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(@"", payload[@"exceptions"][0][@"message"]);
    XCTAssertEqualObjects(event.errors[0].errorClass,
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(event.errors[0].errorMessage,
                          payload[@"exceptions"][0][@"message"]);
}

- (void)testEnhancedErrorMessageForAssertionWithoutAdditionalMessage {
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:@{
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
    NSDictionary *payload = [event toJson];
    XCTAssertEqualObjects(@"assertion failed",
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(@"", payload[@"exceptions"][0][@"message"]);
    XCTAssertEqualObjects(event.errors[0].errorClass,
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(event.errors[0].errorMessage,
                          payload[@"exceptions"][0][@"message"]);
}

- (void)testEnhancedErrorMessageForAssertionError {
    for (NSString *assertionName in @[
             @"assertion failed", @"Assertion failed", @"fatal error",
             @"Fatal error"
         ]) {
        BugsnagEvent *event =
            [[BugsnagEvent alloc] initWithKSReport:@{
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
        NSDictionary *payload = [event toJson];
        XCTAssertEqualObjects(assertionName,
                              payload[@"exceptions"][0][@"errorClass"]);
        XCTAssertEqualObjects(@"Something went wrong",
                              payload[@"exceptions"][0][@"message"]);
        XCTAssertEqualObjects(event.errors[0].errorClass,
                              payload[@"exceptions"][0][@"errorClass"]);
        XCTAssertEqualObjects(event.errors[0].errorMessage,
                              payload[@"exceptions"][0][@"message"]);
    }
}

- (void)testEnhancedErrorMessageIgnoresFilePaths {
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:@{
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
    NSDictionary *payload = [event toJson];
    XCTAssertEqualObjects(@"fatal error",
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(@"", payload[@"exceptions"][0][@"message"]);
    XCTAssertEqualObjects(event.errors[0].errorClass,
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(event.errors[0].errorMessage,
                          payload[@"exceptions"][0][@"message"]);
}

- (void)testEnhancedErrorMessageIgnoresNonStrings {
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:@{
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
    NSDictionary *payload = [event toJson];
    XCTAssertEqualObjects(@"fatal error",
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(@"", payload[@"exceptions"][0][@"message"]);
    XCTAssertEqualObjects(event.errors[0].errorClass,
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(event.errors[0].errorMessage,
                          payload[@"exceptions"][0][@"message"]);
}

- (void)testEnhancedErrorMessageConcatenatesMultipleMessages {
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:@{
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
    NSDictionary *payload = [event toJson];
    XCTAssertEqualObjects(@"Fatal error",
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(@"A message from beyond | Wo0o0o",
                          payload[@"exceptions"][0][@"message"]);
    XCTAssertEqualObjects(event.errors[0].errorClass,
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(event.errors[0].errorMessage,
                          payload[@"exceptions"][0][@"message"]);
}

- (void)testEnhancedErrorMessageIgnoresUnknownAssertionTypes {
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:@{
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
    NSDictionary *payload = [event toJson];
    XCTAssertEqualObjects(@"Exception",
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(@"", payload[@"exceptions"][0][@"message"]);
    XCTAssertEqualObjects(event.errors[0].errorClass,
                          payload[@"exceptions"][0][@"errorClass"]);
    XCTAssertEqualObjects(event.errors[0].errorMessage,
                          payload[@"exceptions"][0][@"message"]);
}

- (void)testEmptyReport {
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:@{}];
    XCTAssertNil(event);
}

- (void)testUnhandledReportDepth {
    // unhandled reports should calculate their own depth
    NSDictionary *dict = @{@"user.depth": @2};
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:dict];
    XCTAssertEqual(event.depth, 0);
}

- (void)testHandledReportDepth {
    // handled reports should use the serialised depth
    BugsnagHandledState *state = [BugsnagHandledState handledStateWithSeverityReason:HandledException];
    NSDictionary *dict = @{@"user.depth": @2, @"user.handledState": [state toJson]};
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:dict];
    XCTAssertEqual(event.depth, 2);
}

- (void)testUnhandledReportSeverity {
    // unhandled reports should calculate their own severity
    NSDictionary *dict = @{@"user.state.crash.severity": @"info"};
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:dict];
    XCTAssertEqual(event.severity, BSGSeverityError);
}

- (void)testHandledReportSeverity {
    // handled reports should use the serialised depth
    BugsnagHandledState *state = [BugsnagHandledState handledStateWithSeverityReason:HandledException];
    NSDictionary *dict = @{@"user.state.crash.severity": @"info", @"user.handledState": [state toJson]};
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:dict];
    XCTAssertEqual(event.severity, BSGSeverityWarning);
}

- (void)testHandledReportMetaData {
    BugsnagHandledState *state = [BugsnagHandledState handledStateWithSeverityReason:HandledException];
    BugsnagMetadata *metadata = [BugsnagMetadata new];
    [metadata addMetadata:@"Bar" withKey:@"Foo" toSection:@"Custom"];
    NSDictionary *dict = @{@"user.handledState": [state toJson], @"user.metaData": [metadata toDictionary]};

    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:dict];
    [event clearMetadataFromSection:@"device"];
    XCTAssertNotNil(event.metadata);
    XCTAssertEqual([[event.metadata toDictionary] count], 1);
    XCTAssertEqualObjects([event.metadata getMetadataFromSection:@"Custom" withKey:@"Foo"], @"Bar");
}

/**
 * Test report metadata handling in OOM situations
 */
- (void)testHandledReportMetaDataOOM {
    BugsnagHandledState *state = [BugsnagHandledState handledStateWithSeverityReason:UnhandledException];
    BugsnagMetadata *metadata = [BugsnagMetadata new];
    [metadata addMetadata:@"Bar" withKey:@"Foo" toSection:@"Custom"];
    NSDictionary *dict = @{
        @"user.state.didOOM" : @YES,
        @"user.handledState": [state toJson],
        @"user.metaData": [metadata toDictionary]
    };

    BugsnagEvent *report1 = [[BugsnagEvent alloc] initWithKSReport:dict];
    XCTAssertNotNil(report1.metadata);
    XCTAssertEqual([[report1.metadata toDictionary] count], 0);

    // OOM metadata is set from the session user data.
    [metadata addMetadata:@"OOMuser" withKey:@"id" toSection:@"user"];
    [metadata addMetadata:@"OOMemail" withKey:@"email" toSection:@"user"];
    [metadata addMetadata:@"OOMname" withKey:@"name" toSection:@"user"];
    
    // Try it again with more fully formed session data
    dict = @{
        @"user.state.didOOM" : @YES,
        @"user.handledState": [state toJson],
        @"user.state.oom.session" : [metadata toDictionary]
    };
    
    BugsnagEvent *report2 = [[BugsnagEvent alloc] initWithKSReport:dict];
    
    XCTAssertNotNil(report2.metadata);
    XCTAssertEqual([[report2.metadata toDictionary] count], 1);
    XCTAssertEqualObjects([report2.metadata getMetadataFromSection:@"user" withKey:@"id"], @"OOMuser");
    XCTAssertEqualObjects([report2.metadata getMetadataFromSection:@"user" withKey:@"name"], @"OOMname");
    XCTAssertEqualObjects([report2.metadata getMetadataFromSection:@"user" withKey:@"email"], @"OOMemail");
}

- (void)testUnhandledReportMetaData {
    BugsnagMetadata *metadata = [BugsnagMetadata new];
    [metadata addMetadata:@"Bar" withKey:@"Foo" toSection:@"Custom"];
    NSDictionary *dict = @{@"user.metaData": [metadata toDictionary]};

    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:dict];
    [event clearMetadataFromSection:@"device"];
    XCTAssertNotNil(event.metadata);
    XCTAssertEqual([[event.metadata toDictionary] count], 1);
    XCTAssertEqualObjects([event.metadata getMetadataFromSection:@"Custom" withKey:@"Foo"], @"Bar");
}

- (void)testAppVersionOverride {
    BugsnagEvent *overrideReport = [[BugsnagEvent alloc] initWithKSReport:@{
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
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:@{@"user.metaData": @{@"user": @{@"id": @"user id"}}}];
    [event addMetadata:@"user" withKey:@"foo" toSection:@"bar"];
}

- (void)testReportAddMetadata {
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:@{@"user.metaData": @{@"user": @{@"id": @"user id"}}}];
    [event addMetadata:@{@"foo": @"bar"} toSection:@"user"];
}


/**
 * Test that BugsnagEvent has an apiKey value and supports non-persistent
 * per-event changes to apiKey.
 */
- (void)testApiKey {
    
    [self setUpBugsnagWillCallNotify:false];

    NSException *ex = [[NSException alloc] initWithName:@"myName" reason:@"myReason1" userInfo:nil];
    
    // Check that the event is passed the apiKey
    [Bugsnag notify:ex block:^(BugsnagEvent * _Nonnull event) {
        XCTAssertEqualObjects(event.apiKey, DUMMY_APIKEY_32CHAR_1);
    }];
    
    // Check that we can change it
    [Bugsnag notify:ex block:^(BugsnagEvent * _Nonnull event) {
        XCTAssertEqualObjects(event.apiKey, DUMMY_APIKEY_32CHAR_1);
        event.apiKey = DUMMY_APIKEY_32CHAR_2;
        XCTAssertEqual(event.apiKey, DUMMY_APIKEY_32CHAR_2);
        XCTAssertEqualObjects(Bugsnag.configuration.apiKey, DUMMY_APIKEY_32CHAR_1);
    }];

    // Check that the global configuration is unaffected
    [Bugsnag notify:ex block:^(BugsnagEvent * _Nonnull event) {
        XCTAssertEqualObjects(event.apiKey, DUMMY_APIKEY_32CHAR_1);
        event.apiKey = DUMMY_APIKEY_32CHAR_1;
        XCTAssertEqual(event.apiKey, DUMMY_APIKEY_32CHAR_1);
        XCTAssertEqualObjects(Bugsnag.configuration.apiKey, DUMMY_APIKEY_32CHAR_1);
        event.apiKey = DUMMY_APIKEY_32CHAR_3;
        XCTAssertEqual(event.apiKey, DUMMY_APIKEY_32CHAR_3);
    }];
    
    // Check that previous local and global values are not persisted erroneously
    Bugsnag.configuration.apiKey = DUMMY_APIKEY_32CHAR_4;
    [Bugsnag notify:ex block:^(BugsnagEvent * _Nonnull event) {
        XCTAssertEqual(event.apiKey, DUMMY_APIKEY_32CHAR_4);
        event.apiKey = DUMMY_APIKEY_32CHAR_1;
        XCTAssertEqual(event.apiKey, DUMMY_APIKEY_32CHAR_1);
        XCTAssertEqual(Bugsnag.configuration.apiKey, DUMMY_APIKEY_32CHAR_4);
        event.apiKey = DUMMY_APIKEY_32CHAR_2;
        XCTAssertEqual(event.apiKey, DUMMY_APIKEY_32CHAR_2);
    }];
    
    // Check that validation is performed and that invalid API keys can't be set
    Bugsnag.configuration.apiKey = DUMMY_APIKEY_32CHAR_1;
    [Bugsnag notify:ex block:^(BugsnagEvent * _Nonnull event) {
        event.apiKey = DUMMY_APIKEY_16CHAR;
        XCTAssertEqual(event.apiKey, DUMMY_APIKEY_32CHAR_1);
    }];
}

// MARK: - Metadata interface

- (void)testAddMetadataSectionKeyValue {
    
    [self setUpBugsnagWillCallNotify:true];
    
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:@{
        @"user.metaData": @{
                @"user": @{@"id": @"user id"}
        }}];
    [event addMetadata:@{@"foo": @"bar"} toSection:@"section"];
    
    // Known
    XCTAssertEqual([event getMetadataFromSection:@"section" withKey:@"foo"], @"bar");
    XCTAssertNotNil([event getMetadataFromSection:@"section"]);
    XCTAssertEqual([[event getMetadataFromSection:@"section"] count], 1);
    [event addMetadata:@{@"baz": @"bam"} toSection:@"section"];
    XCTAssertEqual([[event getMetadataFromSection:@"section"] count], 2);
    XCTAssertEqual([event getMetadataFromSection:@"section" withKey:@"baz"], @"bam");
    // check type
    NSDictionary *v = [event getMetadataFromSection:@"section"];
    XCTAssertTrue([((NSString *)[v valueForKey:@"foo"]) isEqualToString:@"bar"]);

    // Unknown
    XCTAssertNil([event getMetadataFromSection:@"section" withKey:@"bob"]);
    XCTAssertNil([event getMetadataFromSection:@"anotherSection" withKey:@"baz"]);
    XCTAssertNil([event getMetadataFromSection:@"dummySection"]);
}

/**
 * Invalid data should not be set.  Manually check for coverage of logging code.
 */
- (void)testInvalidSectionData {
    [self setUpBugsnagWillCallNotify:true];
    
    NSException *ex = [[NSException alloc] initWithName:@"myName" reason:@"myReason1" userInfo:nil];
    
    [Bugsnag notify:ex block:^(BugsnagEvent * _Nonnull event) {
        NSDictionary *invalidDict = @{};
        NSDictionary *validDict = @{@"myKey" : @"myValue"};
        [event addMetadata:invalidDict toSection:@"mySection"];
        XCTAssertEqual([[event.metadata toDictionary] count], 0);
        [event addMetadata:validDict toSection:@"mySection"];
        XCTAssertEqual([[event.metadata toDictionary] count], 1);
    }];
}

- (void)testInvalidKeyValueData {
    [self setUpBugsnagWillCallNotify:true];
    
    NSException *ex = [[NSException alloc] initWithName:@"myName" reason:@"myReason1" userInfo:nil];
    
    [Bugsnag notify:ex block:^(BugsnagEvent * _Nonnull event) {
        [event addMetadata:[NSNull null] withKey:@"myKey" toSection:@"mySection"];

        // Invalid value for a non-existant section doesn't cause the section to be created
        XCTAssertEqual([[event.metadata toDictionary] count], 0);
        XCTAssertNil([event.metadata getMetadataFromSection:@"myKey"]);

        [event addMetadata:@"aValue" withKey:@"myKey" toSection:@"mySection"];
        XCTAssertEqual([[event.metadata toDictionary] count], 1);
        XCTAssertNotNil([event.metadata getMetadataFromSection:@"mySection" withKey:@"myKey"]);
        
        BugsnagTestsDummyClass *dummy = [BugsnagTestsDummyClass new];
        [event addMetadata:dummy withKey:@"myNewKey" toSection:@"mySection"];
        XCTAssertEqual([[event.metadata toDictionary] count], 1);
        XCTAssertNil([event.metadata getMetadataFromSection:@"mySection" withKey:@"myNewKey"]);
        
        [event addMetadata:@"realValue" withKey:@"myNewKey" toSection:@"mySection"];
        XCTAssertEqual([[event.metadata toDictionary] count], 1);
        XCTAssertNotNil([event.metadata getMetadataFromSection:@"mySection" withKey:@"myNewKey"]);
    }];
}

- (void)testClearMetadataSection {
    // Setup
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:@{
        @"user.metaData": @{
                @"user": @{@"id": @"user id"}
        }}];
    [event clearMetadataFromSection:@"device"];
    [event addMetadata:@{@"foo": @"bar"} toSection:@"section1"];
    [event addMetadata:@{@"baz": @"bill"} toSection:@"section1"];
    [event addMetadata:@{@"alice": @"bob"} toSection:@"section2"];
    XCTAssertEqual([[event.metadata toDictionary] count], 3);
    
    // Known
    [event clearMetadataFromSection:@"section1"];
    XCTAssertEqual([[event.metadata toDictionary] count], 2);
    
    // Unknown
    [event addMetadata:@{@"foo": @"bar"} toSection:@"section1"];
    [event addMetadata:@{@"baz": @"bill"} toSection:@"section1"];
    [event clearMetadataFromSection:@"section3"];
    XCTAssertEqual([[event.metadata toDictionary] count], 3);
    
    // Empty
    [event addMetadata:@{@"foo": @"bar"} toSection:@"section1"];
    [event addMetadata:@{@"baz": @"bill"} toSection:@"section1"];
    [event clearMetadataFromSection:@"section1"];
    [event clearMetadataFromSection:@"section2"];
    [event clearMetadataFromSection:@"section3"];
    XCTAssertEqual([[event.metadata toDictionary] count], 1);

    [event clearMetadataFromSection:@"user"];
    XCTAssertEqual([[event.metadata toDictionary] count], 0);
  
    [event clearMetadataFromSection:@"section1"];
    [event clearMetadataFromSection:@"section2"];
    [event clearMetadataFromSection:@"section3"];
    [event clearMetadataFromSection:@"user"];
    XCTAssertEqual([[event.metadata toDictionary] count], 0);
}

- (void)testClearMetadataSectionWithKey {
    // Setup
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:@{
        @"user.metaData": @{
                @"user": @{@"id": @"user id"}
        }}];
    [event clearMetadataFromSection:@"device"];
    [event addMetadata:@{@"foo": @"bar"} toSection:@"section1"];
    [event addMetadata:@{@"baz": @"bill"} toSection:@"section1"];
    [event addMetadata:@{@"alice": @"bob"} toSection:@"section2"];
    XCTAssertEqual([[event.metadata toDictionary] count], 3);

    // Remove a key
    XCTAssertEqual([[event getMetadataFromSection:@"section1"] count], 2);
    [event clearMetadataFromSection:@"section1" withKey:@"foo"];
    XCTAssertEqual([[event getMetadataFromSection:@"section1"] count], 1);
    
    // Remove all keys, check section exists
    [event clearMetadataFromSection:@"section1" withKey:@"baz"];
    XCTAssertNotNil([event getMetadataFromSection:@"section1"]);
    XCTAssertEqual([[event getMetadataFromSection:@"section1"] count], 0);
}

- (void)testClearMetadataSectionWithKeyNonExistentKeys {
    // Setup
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:@{
        @"user.metaData": @{
                @"user": @{@"id": @"user id"}
        }}];
    [event clearMetadataFromSection:@"device"];
    [event addMetadata:@{@"foo": @"bar"} toSection:@"section1"];
    [event addMetadata:@{@"baz": @"bill"} toSection:@"section1"];
    [event addMetadata:@{@"alice": @"bob"} toSection:@"section2"];
    XCTAssertEqual([[event.metadata toDictionary] count], 3);

    // Nonexistent key
    [event clearMetadataFromSection:@"section1" withKey:@"flump"];
    XCTAssertEqual([[event getMetadataFromSection:@"section1"] count], 2);
    [event clearMetadataFromSection:@"section1" withKey:@"foo"];
    XCTAssertEqual([[event getMetadataFromSection:@"section1"] count], 1);
    XCTAssertEqual([[event.metadata toDictionary] count], 3);
    
    // Nonexistent section
    [event clearMetadataFromSection:@"section52" withKey:@"baz"];
    XCTAssertEqual([[event.metadata toDictionary] count], 3);
    XCTAssertEqual([[event getMetadataFromSection:@"section1"] count], 1);
    XCTAssertEqual([[event getMetadataFromSection:@"section2"] count], 1);
}

- (void)testUnhandled {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    BugsnagHandledState *state = [BugsnagHandledState handledStateWithSeverityReason:HandledException];
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithErrorName:@"Bad error"
                                                     errorMessage:@"it was so bad"
                                                    configuration:config
                                                         metadata:nil
                                                     handledState:state
                                                          session:nil];
    XCTAssertFalse(event.unhandled);

    state = [BugsnagHandledState handledStateWithSeverityReason:UnhandledException];
    event = [[BugsnagEvent alloc] initWithErrorName:@"Bad error"
                                                     errorMessage:@"it was so bad"
                                                    configuration:config
                                                         metadata:nil
                                                     handledState:state
                                                          session:nil];
    XCTAssertTrue(event.unhandled);
}

- (void)testMetadataMutability {
    [self setUpBugsnagWillCallNotify:false];
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:@{@"dummy" : @"value"}];
    
    // Immutable in, mutable out
    [event addMetadata:@{@"foo" : @"bar"} toSection:@"section1"];
    NSObject *metadata1 = [event getMetadataFromSection:@"section1"];
    XCTAssertTrue([metadata1 isKindOfClass:[NSMutableDictionary class]]);
    
    // Mutable in, mutable out
    [event addMetadata:[@{@"foo" : @"bar"} mutableCopy] toSection:@"section2"];
    NSObject *metadata2 = [event getMetadataFromSection:@"section2"];
    XCTAssertTrue([metadata2 isKindOfClass:[NSMutableDictionary class]]);
}

@end
