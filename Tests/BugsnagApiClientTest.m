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

@interface BugsnagApiClientTest : XCTestCase

@end

@implementation BugsnagApiClientTest

- (void)testBadJSON {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    BugsnagApiClient* client = [[BugsnagApiClient alloc] initWithConfig:config queueName:@"test"];
    [client sendItems:1 withPayload:@{@1: @"a"} toURL:[NSURL URLWithString:@"file:///dev/null"] headers:@{@1: @"a"} onCompletion:^(NSUInteger reportCount, BOOL success, NSError *error) {
    }];
}

@end
