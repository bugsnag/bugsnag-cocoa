//
//  BugsnagAddOnSessionTests.m
//  Tests
//
//  Created by Robin Macharg on 11/03/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//
#import "Bugsnag.h"
#import "BugsnagTestConstants.h"
#import <XCTest/XCTest.h>

@interface BugsnagAddOnSessionTests : XCTestCase
@end

@implementation BugsnagAddOnSessionTests

/**
 * Test that adding an onSession block via the Bugsnag object works as expected
 * This is in a separate file due to the Bugsnag object currently having no clean way to
 * reset itself between tests.  There was configuration leakage betwen tests.
 */
- (void)testAddOnSessionBlock {
    
    __block int called = 0; // A counter

    __block XCTestExpectation *expectation1 = [self expectationWithDescription:@"Remove On Session Block 1X"];
    expectation1.inverted = YES;
    __block XCTestExpectation *expectation2 = [self expectationWithDescription:@"Remove On Session Block 2X"];
    __block XCTestExpectation *expectation3 = [self expectationWithDescription:@"Remove On Session Block 3X"];
    expectation3.inverted = YES;
    
    NSError *error;
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:&error];
    configuration.autoTrackSessions = NO;
    
    // non-sending bugsnag
    [configuration addOnSendBlock:^bool(NSDictionary * _Nonnull rawEventData, BugsnagEvent * _Nonnull reports) {
        return false;
    }];

    BugsnagOnSessionBlock sessionBlock = ^(NSMutableDictionary * _Nonnull sessionPayload) {
        switch (called) {
        case 0:
            // not called
            [expectation1 fulfill];
            break;
        case 1:
            [expectation2 fulfill];
            break;
        case 2:
            [expectation3 fulfill];
            break;
        }
    };

    // This should do nothing: there is no underlying config to add the onSessionBlock to.
    [Bugsnag addOnSessionBlock:sessionBlock];
    [Bugsnag startBugsnagWithConfiguration:configuration];

    // We should NOT have this expectation met
    [self waitForExpectations:@[expectation1] timeout:5.0];
    
    [Bugsnag pauseSession];
    called++;

    // Should be able to add it this time
    [Bugsnag addOnSessionBlock:sessionBlock];
    [Bugsnag startSession];
    [self waitForExpectations:@[expectation2] timeout:5.0];

    [Bugsnag pauseSession];
    called++;

    [Bugsnag removeOnSessionBlock:sessionBlock];
    [Bugsnag startSession];
    // This expectation should also NOT be met
    [self waitForExpectations:@[expectation3] timeout:5.0];
}

@end
