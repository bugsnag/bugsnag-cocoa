//
//  BugsnagSessionTest.m
//  Tests
//
//  Created by Jamie Lynch on 27/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "BugsnagSession.h"
#import "BSG_RFC3339DateTool.h"

@interface BugsnagSessionTest : XCTestCase
@end

@implementation BugsnagSessionTest

- (void)testDictDeserialise {
    NSDate *now = [NSDate date];

    NSDictionary *dict = @{
            @"id": @"test",
            @"startedAt": [BSG_RFC3339DateTool stringFromDate:now],
            @"unhandledCount": @1,
            @"handledCount": @2,
            @"user": @{
                    @"name": @"Joe Bloggs"
            }
    };

    BugsnagSession *session = [[BugsnagSession alloc] initWithDictionary:dict];
    XCTAssertNotNil(session);

    XCTAssertEqualObjects(@"test", session.sessionId);
    XCTAssertNotNil(session.startedAt);
    XCTAssertEqual(2, session.handledCount);
    XCTAssertEqual(1, session.unhandledCount);
    XCTAssertNotNil(session.user);
    XCTAssertEqualObjects(@"Joe Bloggs", session.user.name);
}

- (void)testPayloadSerialisation {
    NSDate *now = [NSDate date];
    BugsnagSession *payload = [[BugsnagSession alloc] initWithId:@"test"
                                                       startDate:now
                                                            user:[BugsnagUser new]
                                                    autoCaptured:NO];
    payload.unhandledCount = 1;
    payload.handledCount = 2;

    NSDictionary *rootNode = [payload toJson];
    XCTAssertNotNil(rootNode);
    XCTAssertEqual(3, [rootNode count]);
    
    XCTAssertEqualObjects(@"test", rootNode[@"id"]);
    XCTAssertEqualObjects([BSG_RFC3339DateTool stringFromDate:now], rootNode[@"startedAt"]);
    XCTAssertNotNil(rootNode[@"user"]);
}

- (void)testFullSerialization {
    NSDate *startDate = [NSDate date];
    NSDictionary *dict = @{
                           @"id": @"test",
                           @"startedAt": [BSG_RFC3339DateTool stringFromDate:[NSDate date]],
                           @"unhandledCount": @1,
                           @"handledCount": @2,
                           @"user": @{
                                   @"name": @"Joe Bloggs"
                                   }
                           };

    BugsnagSession *session = [[BugsnagSession alloc] initWithDictionary:dict];
    NSDictionary *newDict = [session toDictionary];
    XCTAssertEqualObjects(@"test", newDict[@"id"]);
    XCTAssertEqualObjects(@1, newDict[@"unhandledCount"]);
    XCTAssertEqualObjects(@2, newDict[@"handledCount"]);
    XCTAssertEqualObjects(@"Joe Bloggs", newDict[@"user"][@"name"]);
    // same date within a reasonable delta
    XCTAssert([startDate timeIntervalSince1970] - [[BSG_RFC3339DateTool dateFromString:newDict[@"startedAt"]] timeIntervalSince1970] < 1);
}

@end
