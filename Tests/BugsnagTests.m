//
//  BugsnagTests.m
//  Tests
//
//  Created by Robin Macharg on 04/02/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//
// Unit tests of global Bugsnag behaviour

#import "Bugsnag.h"
#import "BugsnagTestConstants.h"
#import <XCTest/XCTest.h>

@interface BugsnagTests : XCTestCase

@end

@implementation BugsnagTests

/**
 * Test that global metadata is added correctly, applied to each event, and
 * deleted appropriately.
 */
- (void)testBugsnagMetadataAddition {
    
    NSError *error;
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:&error];
    [Bugsnag startBugsnagWithConfiguration:configuration];
    [Bugsnag addMetadataToSection:@"mySection1" key:@"aKey1" value:@"aValue1"];
    
    // We should see our added metadata in every request.  Let's try a couple:
    
    NSException *exception1 = [[NSException alloc] initWithName:@"exception1" reason:@"reason1" userInfo:nil];
    NSException *exception2 = [[NSException alloc] initWithName:@"exception2" reason:@"reason2" userInfo:nil];

    [Bugsnag notify:exception1 block:^(BugsnagEvent * _Nonnull report) {
        XCTAssertEqual([[[report metadata] valueForKey:@"mySection1"] valueForKey:@"aKey1"], @"aValue1");
        XCTAssertEqual([report errorClass], @"exception1");
        XCTAssertEqual([report errorMessage], @"reason1");
        XCTAssertNil([[report metadata] valueForKey:@"mySection2"]);
        
        // Add some additional metadata once we're sure it's not already there
        [Bugsnag addMetadataToSection:@"mySection2" key:@"aKey2" value:@"aValue2"];
    }];
    
    [Bugsnag notify:exception2 block:^(BugsnagEvent * _Nonnull report) {
        XCTAssertEqual([[[report metadata] valueForKey:@"mySection1"] valueForKey:@"aKey1"], @"aValue1");
        XCTAssertEqual([[[report metadata] valueForKey:@"mySection2"] valueForKey:@"aKey2"], @"aValue2");
        XCTAssertEqual([report errorClass], @"exception2");
        XCTAssertEqual([report errorMessage], @"reason2");
    }];

    // Check nil value causes deletions
    
    [Bugsnag addMetadataToSection:@"mySection1" key:@"aKey1" value:nil];
    [Bugsnag addMetadataToSection:@"mySection2" key:@"aKey2" value:nil];
    
    [Bugsnag notify:exception1 block:^(BugsnagEvent * _Nonnull report) {
        XCTAssertNil([[[report metadata] valueForKey:@"mySection1"] valueForKey:@"aKey1"]);
        XCTAssertNil([[[report metadata] valueForKey:@"mySection2"] valueForKey:@"aKey2"]);
    }];
}

/**
 * Test that the global Bugsnag metadata retrieval performs as expected:
 * return a section when there is one, or nil otherwise.
 */
- (void)testGetMetadata {
    NSError *error;
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:&error];
    [Bugsnag startBugsnagWithConfiguration:configuration];
    XCTAssertNil([Bugsnag getMetadata:@"dummySection"]);
    [Bugsnag addMetadataToSection:@"dummySection" key:@"aKey1" value:@"aValue1"];
    NSMutableDictionary *section = [Bugsnag getMetadata:@"dummySection"];
    XCTAssertNotNil(section);
    XCTAssertEqual(section[@"aKey1"], @"aValue1");
    XCTAssertNil([Bugsnag getMetadata:@"anotherSection"]);
    
    XCTAssertTrue([[Bugsnag getMetadata:@"dummySection" key:@"aKey1"] isEqualToString:@"aValue1"]);
    XCTAssertNil([Bugsnag getMetadata:@"noSection" key:@"notaKey1"]);
}

@end
