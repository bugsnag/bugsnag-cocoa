//
//  BugsnagTests.m
//  BugsnagTests
//
//  Created by Conrad Irwin on 11/6/14.
//
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "Bugsnag.h"

@interface BugsnagTests : XCTestCase

@end

@implementation BugsnagTests

- (void)setUp {
    [super setUp];
    [Bugsnag startBugsnagWithApiKey:@"123456789012345678901234"];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testExample {
    XCTAssert(YES, @"Pass");
}

// Ensure that Bugsnag deals with nil exception names appropriately
// KSCrash can crash itself if a nil name is passed through
- (void)testNotifyWithNilName {
    NSString *nilName = nil;
    NSException *exception = [NSException exceptionWithName:nilName reason:nil userInfo:nil];
    [Bugsnag notify:exception];
    XCTAssert(YES, @"Pass");
}

@end
