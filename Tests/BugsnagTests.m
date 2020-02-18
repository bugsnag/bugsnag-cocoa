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

// MARK: - BugsnagTests

@interface BugsnagTests : XCTestCase

@end

@implementation BugsnagTests

/**
 * Test that global metadata is added correctly, applied to each event, and
 * deleted appropriately.
 */
- (void)testBugsnagMetadataAddition {
    
    __block XCTestExpectation *expectation = [self expectationWithDescription:@"Localized metadata changes"];
    NSError *error;
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:&error];
    // It's a test so failing to send is OK.
    [configuration addBeforeSendBlock:^bool(NSDictionary * _Nonnull rawEventData,
                                            BugsnagEvent * _Nonnull reports)
    {
        return false;
    }];
    
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
    
    [Bugsnag notify:exception1 block:^(BugsnagEvent * _Nonnull event) {
        XCTAssertNil([[[event metadata] valueForKey:@"mySection1"] valueForKey:@"aKey1"]);
        XCTAssertNil([[[event metadata] valueForKey:@"mySection2"] valueForKey:@"aKey2"]);
    }];
    
    // Check that event-level metadata alteration doesn't affect configuration-level metadata
    [Bugsnag addMetadataToSection:@"mySection1" key:@"aKey1" value:@"aValue1"];
    [Bugsnag notify:exception1 block:^(BugsnagEvent * _Nonnull event) {
        // NSDictionary returned; immutable, so let's replace it wholesale
        [event setMetadata:@{@"myNewSection" : @{@"myNewKey" : @"myNewValue"}}];
        XCTAssertNil([[[event metadata] valueForKey:@"mySection1"] valueForKey:@"aKey1"]);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:0.1 handler:^(NSError * _Nullable error) {
        // Check old values still exist
        XCTAssertEqual([[[[Bugsnag configuration] metadata] getMetadata: @"mySection1"] valueForKey:@"aKey1"], @"aValue1");
        
        // Check "new" values don't exist
        XCTAssertNil([[[[Bugsnag configuration] metadata] getMetadata:@"myNewSection"] valueForKey:@"myNewKey"]);
        XCTAssertNil([[[Bugsnag configuration] metadata] getMetadata:@"myNewSection"]);
        expectation = nil;
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

/**
 * Test that pausing the session performs as expected.
 * NOTE: For now this test is inadequate.  Some form of dependency injection
 *       or mocking is required to isolate and test the session pausing semantics.
 */
-(void)testBugsnagPauseSession {
    NSError *error;
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:&error];
    [configuration addBeforeSendBlock:^bool(NSDictionary * _Nonnull rawEventData,
                                            BugsnagEvent * _Nonnull reports)
    {
        return false;
    }];

    [Bugsnag startBugsnagWithConfiguration:configuration];

    // For now only test that the method exists
    [Bugsnag pauseSession];
}

/**
 * Test that the BugsnagConfiguration-mirroring Bugsnag.context is mutable
 */
- (void)testMutableContext {
    // Allow for checks inside blocks that may (potentially) be run asynchronously
    __block XCTestExpectation *expectation1 = [self expectationWithDescription:@"Localized metadata changes"];
    
    NSError *error;
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:&error];
    [configuration setContext:@"firstContext"];
    [configuration addBeforeSendBlock:^bool(NSDictionary * _Nonnull rawEventData,
                                            BugsnagEvent * _Nonnull reports)
    {
        return false;
    }];
    
    [Bugsnag startBugsnagWithConfiguration:configuration];

    NSException *exception1 = [[NSException alloc] initWithName:@"exception1" reason:@"reason1" userInfo:nil];

    // Check that the context is set going in to the test and that we can change it
    [Bugsnag notify:exception1 block:^(BugsnagEvent * _Nonnull event) {
        XCTAssertEqual([[Bugsnag configuration] context], @"firstContext");
        
        // Change the global context
        [Bugsnag setContext:@"secondContext"];
        
        // Check that it's made it into the configuration (from the point of view of the block)
        // and that setting it here doesn't affect the event's value.
        XCTAssertEqual([[Bugsnag configuration] context], @"secondContext");
        XCTAssertEqual([event context], @"firstContext");
        
        [expectation1 fulfill];
    }];

    // Test that the context (changed inside the notify block) remains changed
    // And that the event picks up this value.
    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError * _Nullable error) {
        XCTAssertEqual([[Bugsnag configuration] context], @"secondContext");
        
        [Bugsnag notify:exception1 block:^(BugsnagEvent * _Nonnull report) {
            XCTAssertEqual([[Bugsnag configuration] context], @"secondContext");
            XCTAssertEqual([report context], @"secondContext");
        }];
    }];
}

@end
