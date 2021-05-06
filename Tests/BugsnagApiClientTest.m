//
//  BugsnagApiClientTest.m
//  Bugsnag-iOSTests
//
//  Created by Karl Stenerud on 04.09.20.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "BugsnagApiClient.h"
#import <Bugsnag/Bugsnag.h>
#import "BugsnagTestConstants.h"
#import "URLSessionMock.h"

@interface BugsnagApiClientTest : XCTestCase

@end

@implementation BugsnagApiClientTest

- (void)testBadJSON {
    BugsnagApiClient *client = [[BugsnagApiClient alloc] initWithSession:nil queueName:@"test"];
    XCTAssertNoThrow([client sendJSONPayload:(id)@{@1: @"a"} headers:(id)@{@1: @"a"} toURL:[NSURL URLWithString:@"file:///dev/null"]
                           completionHandler:^(BugsnagApiClientDeliveryStatus status, NSError * _Nullable error) {}]);
}

- (void)testHTTPStatusCodes {
    NSURL *url = [NSURL URLWithString:@"https://example.com"];
    URLSessionMock *session = [[URLSessionMock alloc] init];
    BugsnagApiClient *client = [[BugsnagApiClient alloc] initWithSession:(id)session queueName:@""];
    
    void (^ test)(NSInteger, BugsnagApiClientDeliveryStatus, BOOL) =
    ^(NSInteger statusCode, BugsnagApiClientDeliveryStatus expectedDeliveryStatus, BOOL expectError) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"completionHandler should be called"];
        id response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:statusCode HTTPVersion:@"1.1" headerFields:nil];
        [session mockData:[NSData data] response:response error:nil];
        [client sendJSONPayload:@{} headers:@{} toURL:url completionHandler:^(BugsnagApiClientDeliveryStatus status, NSError * _Nullable error) {
            XCTAssertEqual(status, expectedDeliveryStatus);
            expectError ? XCTAssertNotNil(error) : XCTAssertNil(error);
            [expectation fulfill];
        }];
    };
    
    test(200, BugsnagApiClientDeliveryStatusDelivered, NO);
    
    // Permanent failures
    test(400, BugsnagApiClientDeliveryStatusUndeliverable, YES);
    test(401, BugsnagApiClientDeliveryStatusUndeliverable, YES);
    test(403, BugsnagApiClientDeliveryStatusUndeliverable, YES);
    test(404, BugsnagApiClientDeliveryStatusUndeliverable, YES);
    test(405, BugsnagApiClientDeliveryStatusUndeliverable, YES);
    test(406, BugsnagApiClientDeliveryStatusUndeliverable, YES);
    
    // Transient failures
    test(402, BugsnagApiClientDeliveryStatusFailed, YES);
    test(407, BugsnagApiClientDeliveryStatusFailed, YES);
    test(408, BugsnagApiClientDeliveryStatusFailed, YES);
    test(429, BugsnagApiClientDeliveryStatusFailed, YES);
    test(500, BugsnagApiClientDeliveryStatusFailed, YES);
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testNotConnectedToInternetError {
    NSURL *url = [NSURL URLWithString:@"https://example.com"];
    URLSessionMock *session = [[URLSessionMock alloc] init];
    BugsnagApiClient *client = [[BugsnagApiClient alloc] initWithSession:(id)session queueName:@""];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"completionHandler should be called"];
    [session mockData:nil response:nil error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:@{
        NSURLErrorFailingURLErrorKey: url,
    }]];
    [client sendJSONPayload:@{} headers:@{} toURL:url completionHandler:^(BugsnagApiClientDeliveryStatus status, NSError * _Nullable error) {
        XCTAssertEqual(status, BugsnagApiClientDeliveryStatusFailed);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, NSURLErrorDomain);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testSHA1HashStringWithData {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertNil([BugsnagApiClient SHA1HashStringWithData:nil]);
#pragma clang diagnostic pop
    XCTAssertEqualObjects([BugsnagApiClient SHA1HashStringWithData:[@"{\"foo\":\"bar\"}" dataUsingEncoding:NSUTF8StringEncoding]], @"a5e744d0164540d33b1d7ea616c28f2fa97e754a");
}

@end
