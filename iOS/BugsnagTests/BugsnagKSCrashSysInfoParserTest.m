//
//  BugsnagKSCrashSysInfoParserTestTest.m
//  Tests
//
//  Created by Jamie Lynch on 15/05/2018.
//  Copyright © 2018 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "BugsnagKSCrashSysInfoParser.h"

@interface BugsnagKSCrashSysInfoParserTest : XCTestCase
@end

@implementation BugsnagKSCrashSysInfoParserTest

- (void)testEmptyDictSerialisation {
    // ensures that an empty dictionary parameter returns a fallback dictionary populated with at least some information
    NSDictionary *device = BSGParseDevice(@{});
    XCTAssertNotNil(device);
    XCTAssertNotNil(device[@"locale"]);
    XCTAssertNotNil(device[@"freeDisk"]);
    XCTAssertNotNil(device[@"simulator"]);
}

@end
