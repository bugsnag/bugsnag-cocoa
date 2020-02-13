//
//  BugsnagMetadataTests.m
//  Tests
//
//  Created by Robin Macharg on 12/02/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "BugsnagMetadata.h"

@interface BugsnagMetadataTests : XCTestCase

@end

@implementation BugsnagMetadataTests

- (void)testGetMetadataSectionKey {
    BugsnagMetadata *metadata = [BugsnagMetadata new];
    [metadata addAttribute:@"myKey1" withValue:@"myValue1" toTabWithName:@"section1"];
    [metadata addAttribute:@"myKey2" withValue:@"myValue2" toTabWithName:@"section1"];
    [metadata addAttribute:@"myKey3" withValue:@"myValue3" toTabWithName:@"section2"];
    
    // Test known values
    XCTAssertEqual([metadata getMetadata:@"section1" key:@"myKey1"], @"myValue1");
    XCTAssertEqual([metadata getMetadata:@"section1" key:@"myKey2"], @"myValue2");
    
    // unknown values
    XCTAssertNil([metadata getMetadata:@"sections1" key:@"noKey"]);
    XCTAssertNil([metadata getMetadata:@"noSection" key:@"noKey"]);
}

@end
