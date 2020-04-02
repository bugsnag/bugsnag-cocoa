//
//  BugsnagKSCrashSysInfoParserTestTest.m
//  Tests
//
//  Created by Jamie Lynch on 15/05/2018.
//  Copyright © 2018 Bugsnag. All rights reserved.
//

@import XCTest;

#import "BugsnagKSCrashSysInfoParser.h"
NSNumber * _Nullable BSGDeviceFreeSpace(NSSearchPathDirectory directory);

@interface BugsnagKSCrashSysInfoParserTest : XCTestCase
@end

@implementation BugsnagKSCrashSysInfoParserTest

- (void)testDeviceFreeSpaceShouldBeLargeNumber {
    NSNumber *freeBytes = BSGDeviceFreeSpace(NSCachesDirectory);
    XCTAssertNotNil(freeBytes, @"expect a valid number for successful call to retrieve free space");
    XCTAssertGreaterThan([freeBytes integerValue], 1000, @"expect at least 1k of free space on test device");
}

- (void)testDeviceFreeSpaceShouldBeNilWhenFailsToRetrieveIt {
    NSSearchPathDirectory notAccessibleDirectory = NSAdminApplicationDirectory;
    NSNumber *freeBytes = BSGDeviceFreeSpace(notAccessibleDirectory);
    XCTAssertNil(freeBytes, @"expect nil when fails to retrieve free space for the directory");
}

@end
