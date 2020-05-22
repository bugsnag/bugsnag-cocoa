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
 *
 * @param willNotify Whether the notifier should actually send the event to the server
 */

-(void)setUpBugsnagWillCallNotify:(bool)willNotify
{
    // Default to not persisting user info
    [self setUpBugsnagWillCallNotify:willNotify
                      andPersistUser:false];
}

-(void)setUpBugsnagWillCallNotify:(bool)willNotify
                   andPersistUser:(bool)willPersistUser
{
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    [configuration setPersistUser:willPersistUser];
    
    if (willNotify) {
        [configuration addOnSendErrorBlock:^BOOL(BugsnagEvent *_Nonnull event) {
            return false;
        }];
    }
    [Bugsnag startWithConfiguration:configuration];
}

@end
