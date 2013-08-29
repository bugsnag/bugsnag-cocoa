//
//  BugsnagTests.m
//  BugsnagTests
//
//  Created by Simon Maynard on 8/28/13.
//  Copyright (c) 2013 Simon Maynard. All rights reserved.
//

#import "BugsnagTests.h"
#import "BugsnagEvent.h"

@implementation BugsnagTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)testExceptions {
    @try {
        @throw [NSException exceptionWithName:@"errorClass" reason:@"errorMessage" userInfo:nil];
    }
    @catch (NSException *exception) {
        NSLog(@"%@",[exception callStackSymbols]);
        NSLog(@"%@",[BugsnagEvent getStackTraceWithException:nil]);
    }
    //NSLog(@"%@",[BugsnagEvent loadedImages]);
}
@end
