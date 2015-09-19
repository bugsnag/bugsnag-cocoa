//
//  BugsnagSinkTests.m
//  Bugsnag
//
//  Created by Simon Maynard on 12/1/14.
//
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "Bugsnag.h"
#import "BugsnagCrashReport.h"
#import "BugsnagSink.h"

@interface BugsnagSinkTests : XCTestCase
@property BugsnagCrashReport *report;
@property BugsnagSink *sink;
@end

@interface BugsnagSink ()
- (NSDictionary*) getBodyFromReports:(NSArray*) reports;
@end

@implementation BugsnagSinkTests

- (void)setUp {
    [super setUp];
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"report" ofType:@"json"];
    NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:[contents dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    self.report = [[BugsnagCrashReport alloc] initWithKSReport:dictionary];
    self.sink = [[BugsnagSink alloc] init];
    
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] init];
    config.autoNotify = NO;
    config.apiKey = @"apiKeyHere";
    [Bugsnag startBugsnagWithConfiguration:config];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testGetBodyFromReports {
    NSArray *reports = @[ self.report ];
    NSDictionary *dict = [self.sink getBodyFromReports:reports];
    
    [self check:[dict allKeys] ContainsOnly:@[ @"apiKey", @"notifier", @"events" ]];
    
    // Test apiKey
    XCTAssertEqualObjects([dict objectForKey:@"apiKey"], @"apiKeyHere");
    
    // Test notifier dictionary
    [self check:[[dict objectForKey:@"notifier"] allKeys] ContainsOnly:@[ @"name", @"version", @"url" ]];
    XCTAssertEqualObjects([[dict objectForKey:@"notifier"] valueForKey:@"name"], @"iOS Bugsnag Notifier");
    XCTAssertEqualObjects([[dict objectForKey:@"notifier"] valueForKey:@"url"], @"https://github.com/bugsnag/bugsnag-cocoa");
    XCTAssertNotEqualObjects([[dict objectForKey:@"notifier"] valueForKey:@"version"], nil);
    XCTAssertTrue([[[dict objectForKey:@"notifier"] valueForKey:@"version"] isKindOfClass:[NSString class]]);
    
    // Check events array
    XCTAssert(((NSArray*)[dict objectForKey:@"events"]).count == 1);
    
    // Check event
    NSDictionary *event = [((NSArray*)[dict objectForKey:@"events"]) objectAtIndex:0];
    NSArray* eventKeys = @[@"app", @"appState", @"breadcrumbs", @"context", @"device",
                           @"deviceState", @"dsymUUID", @"exceptions", @"metaData",
                           @"payloadVersion", @"severity", @"threads"];
    XCTAssertEqualObjects([[event allKeys] sortedArrayUsingSelector:@selector(compare:)], eventKeys);
    XCTAssertEqualObjects([event objectForKey:@"dsymUUID"], self.report.dsymUUID);
    XCTAssertEqualObjects([event objectForKey:@"payloadVersion"], @"2");
    XCTAssertEqualObjects([event objectForKey:@"severity"], self.report.severity);
    XCTAssertEqualObjects([event objectForKey:@"breadcrumbs"], self.report.breadcrumbs);
    XCTAssertEqualObjects([event objectForKey:@"context"], self.report.context);
    XCTAssertEqualObjects([event objectForKey:@"metaData"], (@{
                                                               @"error": @{
                                                                    @"mach": @{
                                                                            @"code": @0,
                                                                            @"exception_name": @"EXC_CRASH",
                                                                            @"subcode": @0,
                                                                            @"exception": @10
                                                                            },
                                                                    @"user_reported": @{
                                                                            @"name": @"name",
                                                                            @"line_of_code": @""
                                                                            },
                                                                    @"reason": @"reason",
                                                                    @"signal": @{
                                                                            @"name": @"SIGABRT",
                                                                            @"signal": @6,
                                                                            @"code": @0
                                                                            },
                                                                    @"type": @"user",
                                                                    @"address": @0
                                                                    },
                                                               @"user": @{
                                                                    @"id": self.report.deviceAppHash
                                                                    },
                                                               @"tab": @{
                                                                    @"key": @"value"
                                                                    }
                                                                }));
    
}

- (void)check:(NSArray*)subject ContainsOnly:(NSArray*)values {
    XCTAssert(subject.count == values.count);
    for (id object in values) {
        XCTAssert([subject containsObject:object]);
    }
}

@end
