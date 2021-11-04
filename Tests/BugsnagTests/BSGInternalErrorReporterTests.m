//
//  BSGInternalErrorReporterTests.m
//  Bugsnag
//
//  Created by Nick Dowell on 06/05/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <Bugsnag/Bugsnag.h>

#import "BSGInternalErrorReporter.h"
#import "BugsnagEvent+Private.h"
#import "BugsnagNotifier.h"

@interface BSGInternalErrorReporterTests : XCTestCase <BSGInternalErrorReporterDataSource>

@property (nonatomic) BugsnagConfiguration *configuration;
@property (nonatomic) BugsnagNotifier *notifier;

@end

@implementation BSGInternalErrorReporterTests

- (void)setUp {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    [BSGInternalErrorReporter setSharedInstance:nil];
#pragma clang diagnostic pop
    self.configuration = [[BugsnagConfiguration alloc] initWithApiKey:@"0192837465afbecd0192837465afbecd"];
    self.notifier = [[BugsnagNotifier alloc] init];
}

- (void)testEventWithErrorClass {
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:@"0192837465afbecd0192837465afbecd"];
    BSGInternalErrorReporter *reporter = [[BSGInternalErrorReporter alloc] initWithDataSource:self];
    
    BugsnagEvent *event = [reporter eventWithErrorClass:@"Internal error" message:@"Something went wrong" diagnostics:@{} groupingHash:@"test"];
    XCTAssertEqualObjects(event.errors[0].errorClass, @"Internal error");
    XCTAssertEqualObjects(event.errors[0].errorMessage, @"Something went wrong");
    XCTAssertEqualObjects(event.groupingHash, @"test");
    XCTAssertEqualObjects(event.threads, @[]);
    XCTAssertGreaterThan(event.errors[0].stacktrace.count, 0);
    XCTAssertNil(event.apiKey);
    
    NSDictionary *diagnostics = [event.metadata getMetadataFromSection:@"BugsnagDiagnostics"];
    XCTAssertEqualObjects(diagnostics[@"apiKey"], configuration.apiKey);
}

- (void)testEventWithException {
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:@"0192837465afbecd0192837465afbecd"];
    BSGInternalErrorReporter *reporter = [[BSGInternalErrorReporter alloc] initWithDataSource:self];
    
    NSException *exception = nil;
    @try {
        NSLog(@"%@", @[][0]);
    } @catch (NSException *e) {
        exception = e;
    }
    
    BugsnagEvent *event = [reporter eventWithException:exception diagnostics:nil groupingHash:@"test"];
    XCTAssertEqualObjects(event.errors[0].errorClass, @"NSRangeException");
    XCTAssertEqualObjects(event.errors[0].errorMessage, @"*** -[__NSArray0 objectAtIndex:]: index 0 beyond bounds for empty NSArray");
    XCTAssertEqualObjects(event.groupingHash, @"test");
    XCTAssertEqualObjects(event.threads, @[]);
    XCTAssertGreaterThan(event.errors[0].stacktrace.count, 0);
    XCTAssertNil(event.apiKey);
    
    NSDictionary *diagnostics = [event.metadata getMetadataFromSection:@"BugsnagDiagnostics"];
    XCTAssertEqualObjects(diagnostics[@"apiKey"], configuration.apiKey);
}

- (void)testRequestForEvent {
    self.configuration.endpoints.notify = @"https://notify.example.com";
    
    BugsnagNotifier *notifier = [[BugsnagNotifier alloc] init];
    BSGInternalErrorReporter *reporter = [[BSGInternalErrorReporter alloc] initWithDataSource:self];

    BugsnagEvent *event = [[BugsnagEvent alloc] init];
    
    NSURLRequest *request = [reporter requestForEvent:event error:NULL];
    XCTAssertEqualObjects(request.URL, [NSURL URLWithString:self.configuration.endpoints.notify]);
    XCTAssertEqualObjects(request.HTTPMethod, @"POST");
    
    XCTAssertEqualObjects([request valueForHTTPHeaderField:@"Bugsnag-Internal-Error"], @"bugsnag-cocoa");
    XCTAssertNil([request valueForHTTPHeaderField:@"Bugsnag-Api-Key"]);
    XCTAssertNil([request valueForHTTPHeaderField:@"Bugsnag-Stacktrace-Types"]);
    XCTAssertNotNil([request valueForHTTPHeaderField:@"Bugsnag-Integrity"]);
    XCTAssertNotNil([request valueForHTTPHeaderField:@"Bugsnag-Sent-At"]);
    
    NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:(NSData * _Nonnull)request.HTTPBody options:0 error:NULL];
    XCTAssertEqualObjects(payload[@"events"], @[[event toJsonWithRedactedKeys:nil]]);
    XCTAssertEqualObjects(payload[@"notifier"], [notifier toDict]);
    XCTAssertEqualObjects(payload[@"payloadVersion"], @"4.0");
    XCTAssertNil(payload[@"apiKey"]);
}

- (void)testPerformBlock {
    XCTestExpectation *expectation = [self expectationWithDescription:@"+performBlock: block is called once sharedInstance is set"];
    [BSGInternalErrorReporter performBlock:^(BSGInternalErrorReporter *reporter) {
        XCTAssertNotNil(reporter);
        [expectation fulfill];
    }];
    [BSGInternalErrorReporter setSharedInstance:[[BSGInternalErrorReporter alloc] initWithDataSource:self]];
    [self waitForExpectations:@[expectation] timeout:1];
    
    expectation = [self expectationWithDescription:@"+performBlock: block is called immediately"];
    [BSGInternalErrorReporter performBlock:^(BSGInternalErrorReporter *reporter) {
        XCTAssertNotNil(reporter);
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:0];
}

// MARK: - BSGInternalErrorReporterDataSource

- (BugsnagAppWithState *)generateAppWithState:(nonnull NSDictionary *)systemInfo {
    return [[BugsnagAppWithState alloc] init];
}

- (BugsnagDeviceWithState *)generateDeviceWithState:(nonnull NSDictionary *)systemInfo {
     return [[BugsnagDeviceWithState alloc] init];
}

@end
