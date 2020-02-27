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

- (void)testMutableCopyWithZone {
    
    BugsnagMetadata *metadata = [BugsnagMetadata new];
    [metadata addAttribute:@"myKey" withValue:@"myValue" toTabWithName:@"section1"];
    
    BugsnagMetadata *copy = [metadata mutableCopyWithZone:nil];
    XCTAssertNotEqual(metadata, copy);
    
    // Until/unless it's decided otherwise the copy is a shallow one.
    XCTAssertEqual([metadata getMetadata:@"section1"], [copy getMetadata:@"section1"]);
}

-(void)testClearMetadataInSectionWithKey {
    BugsnagMetadata *metadata = [BugsnagMetadata new];
    [metadata addAttribute:@"myKey1" withValue:@"myValue1" toTabWithName:@"section1"];
    [metadata addAttribute:@"myKey2" withValue:@"myValue2" toTabWithName:@"section1"];
    [metadata addAttribute:@"myKey3" withValue:@"myValue3" toTabWithName:@"section2"];
    
    XCTAssertEqual([[metadata getMetadata:@"section1"] count], 2);
    XCTAssertEqual([[metadata getMetadata:@"section2"] count], 1);
    
    [metadata clearMetadataInSection:@"section1" key:@"myKey1"];
    XCTAssertEqual([[metadata getMetadata:@"section1"] count], 1);
    XCTAssertNil([[metadata getMetadata:@"section1"] valueForKey:@"myKey1"]);
    XCTAssertEqual([[metadata getMetadata:@"section1"] valueForKey:@"myKey2"], @"myValue2");
    
    // The short whole-section version
    // Existing section
    [metadata clearMetadataInSection:@"section2"];
    XCTAssertNil([metadata getMetadata:@"section2"]);
    XCTAssertEqual([[metadata getMetadata:@"section1"] valueForKey:@"myKey2"], @"myValue2");
    
    // nonexistent sections
    [metadata clearMetadataInSection:@"section3"];
    
    // Add it back in, but different
    [metadata  addAttribute:@"myKey4" withValue:@"myValue4" toTabWithName:@"section2"];
    XCTAssertEqual([[metadata getMetadata:@"section2"] valueForKey:@"myKey4"], @"myValue4");
}

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
