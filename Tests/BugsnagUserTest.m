//
//  BugsnagUserTest.m
//  Tests
//
//  Created by Jamie Lynch on 27/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "BugsnagUser.h"

@interface BugsnagUserTest : XCTestCase
@end

@implementation BugsnagUserTest

- (void)testPayloadSerialisation {
    BugsnagUser *payload = [BugsnagUser new];
    payload.userId = @"test";
    payload.emailAddress = @"fake@example.com";
    payload.name = @"Tom Bombadil";
    
    NSDictionary *rootNode = [payload toJson];
    XCTAssertNotNil(rootNode);
    XCTAssertEqual(3, [rootNode count]);
    
    XCTAssertEqualObjects(@"test", rootNode[@"id"]);
    XCTAssertEqualObjects(@"fake@example.com", rootNode[@"emailAddress"]);
    XCTAssertEqualObjects(@"Tom Bombadil", rootNode[@"name"]);
}

@end
