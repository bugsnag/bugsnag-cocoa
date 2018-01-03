//
//  BugsnagCrashReportTests.m
//  Bugsnag
//
//  Created by Simon Maynard on 12/1/14.
//
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "Bugsnag.h"
#import "BugsnagHandledState.h"
#import "BugsnagSession.h"
#import "BSG_RFC3339DateTool.h"

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
    XCTAssertEqualObjects([BSG_RFC3339DateTool stringFromDate:now], session[@"startedAt"]);

    NSDictionary *events = session[@"events"];
    XCTAssertNotNil(events);
    XCTAssertEqualObjects(@2, events[@"handled"]);
    XCTAssertEqualObjects(@1, events[@"unhandled"]);
}

- (void)testEnhancedErrorMessage {
    BugsnagCrashReport *errorReport = [BugsnagCrashReport new];
    NSMutableDictionary *thread = [NSMutableDictionary new];
    
    // nil for empty threads
    XCTAssertNil([errorReport enhancedErrorMessageForThread:thread]);
    NSMutableDictionary *addresses = [NSMutableDictionary new];
    
    // nil for empty notable addresses
    thread[@"notable_addresses"] = addresses;
    XCTAssertNil([errorReport enhancedErrorMessageForThread:thread]);
    
    // nil for "fatal error" with no additional dict present
    
    for (NSString *reservedWord in @[@"fatal error", @"assertion failed"]) {
        addresses[@"r14"] = @{
                              @"address": @4511089532,
                              @"type": @"string",
                              @"value": reservedWord
                              };
        XCTAssertNil([errorReport enhancedErrorMessageForThread:thread]);
    }
    
    // returns msg for "fatal error" with additional dict present
    addresses[@"r12"] = @{
                          @"address": @4511086448,
                          @"type": @"string",
                          @"value": @"Whoops - fatalerror"
                          };
    XCTAssertEqualObjects(@"Whoops - fatalerror", [errorReport enhancedErrorMessageForThread:thread]);
    
    
    // ignores additional dict if more than 2 "/" present
    addresses[@"r24"] = @{
                          @"address": @4511084983,
                          @"type": @"string",
                          @"value": @"/usr/include/lib/something.swift"
                          };
    XCTAssertEqualObjects(@"Whoops - fatalerror", [errorReport enhancedErrorMessageForThread:thread]);
    
    // ignores dict if not type string
    addresses[@"r25"] = @{
                          @"address": @4511084983,
                          @"type": @"long",
                          @"value": @"Swift is hard"
                          };
    XCTAssertEqualObjects(@"Whoops - fatalerror", [errorReport enhancedErrorMessageForThread:thread]);
    
    // sorts and concatenates multiple multiple messages
    addresses[@"r26"] = @{
                          @"address": @4511082095,
                          @"type": @"string",
                          @"value": @"Swift is hard"
                          };
    XCTAssertEqualObjects(@"Swift is hard | Whoops - fatalerror", [errorReport enhancedErrorMessageForThread:thread]);
    
    // ignores stack frames
    addresses[@"stack523409"] = @{
                                  @"address": @4511080001,
                                  @"type": @"string",
                                  @"value": @"Not a register"
                                  };
    XCTAssertEqualObjects(@"Swift is hard | Whoops - fatalerror", [errorReport enhancedErrorMessageForThread:thread]);
    
    // ignores values if no reserved word used
    addresses[@"r14"] = nil;
    XCTAssertNil([errorReport enhancedErrorMessageForThread:thread]);
}

@end
