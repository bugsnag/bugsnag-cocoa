//
//  BugsnagBaseUnitTest.m
//  Tests
//
//  Created by Robin Macharg on 13/02/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "Bugsnag.h"
#import "BugsnagConfiguration.h"
#import "BugsnagTestConstants.h"
#import <XCTest/XCTest.h>

@interface BugsnagBaseUnitTest : XCTestCase

@end

@implementation BugsnagBaseUnitTest

/**
 * A boilerplate helper method to setup Bugsnag
 * If [Bugsnag notify] is to be called during unit testing it should either:
 *
 *   - discard events before sending or
 *   - send to an arbitrary non-functional endpoint.
 *
 * We take the former approach.
 */
-(void)setUpBugsnagWillCallNotify:(bool)willNotify {
    NSError *error;
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:&error];
    if (willNotify) {
        [configuration addOnSendBlock:^bool(NSDictionary * _Nonnull rawEventData,
                                                BugsnagEvent * _Nonnull reports)
        {
            return false;
        }];
    }
    [Bugsnag startBugsnagWithConfiguration:configuration];
}

@end
