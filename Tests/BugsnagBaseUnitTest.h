//
//  BugsnagBaseUnitTest.h
//  Bugsnag
//
//  Created by Robin Macharg on 13/02/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//
// A Unit Test base class that provides useful utility methods.

#ifndef BugsnagBaseUnitTest_h
#define BugsnagBaseUnitTest_h

@interface BugsnagBaseUnitTest : XCTestCase

-(void)setUpBugsnagWillCallNotify:(bool)willNotify;
-(void)setUpBugsnagWillCallNotify:(bool)willNotify andPersistUser:(bool)willPersistUser;

@end

#endif /* BugsnagBaseUnitTest_h */
