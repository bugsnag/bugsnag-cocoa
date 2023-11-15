//
//  BugsnagUserTest.m
//  Tests
//
//  Created by Jamie Lynch on 27/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import "BSGTestCase.h"

#import "BugsnagEvent+Private.h"
#import "BugsnagUser+Private.h"

@interface BugsnagUserTest : BSGTestCase
@end

@implementation BugsnagUserTest

- (void)testDictDeserialisation {

    NSDictionary *dict = @{
            @"id": @"test",
            @"email": @"fake@example.com",
            @"name": @"Tom Bombadil"
    };
    BugsnagUser *user = [[BugsnagUser alloc] initWithDictionary:dict];

    XCTAssertNotNil(user);
    XCTAssertEqualObjects(user.id, @"test");
    XCTAssertEqualObjects(user.email, @"fake@example.com");
    XCTAssertEqualObjects(user.name, @"Tom Bombadil");
}

- (void)testDictNullDeserialisation {

    NSDictionary *dict = @{
            @"id": [NSNull null],
            @"email": [NSNull null],
            @"name": [NSNull null]
    };
    BugsnagUser *user = [[BugsnagUser alloc] initWithDictionary:dict];

    XCTAssertNotNil(user);
    XCTAssertNil(user.id);
    XCTAssertNil(user.email);
    XCTAssertNil(user.name);
}

- (void)testDictNullSerialisation {
    BugsnagUser *user = [[BugsnagUser alloc] initWithId:nil name:nil emailAddress:nil];
    NSDictionary *dict = [user toJson];
    XCTAssertEqualObjects(@{}, dict);

    dict = [user toJsonWithNSNulls];
    NSDictionary *expected = @{
            @"id": [NSNull null],
            @"email": [NSNull null],
            @"name": [NSNull null]
    };
    XCTAssertEqualObjects(expected, dict);
}

- (void)testPayloadSerialisation {
    BugsnagUser *payload = [[BugsnagUser alloc] initWithId:@"test" name:@"Tom Bombadil" emailAddress:@"fake@example.com"];
    NSDictionary *rootNode = [payload toJson];
    XCTAssertNotNil(rootNode);
    XCTAssertEqual(3, [rootNode count]);
    
    XCTAssertEqualObjects(@"test", rootNode[@"id"]);
    XCTAssertEqualObjects(@"fake@example.com", rootNode[@"email"]);
    XCTAssertEqualObjects(@"Tom Bombadil", rootNode[@"name"]);
}

- (void)testUserEvent {
    // Setup
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:@{
            @"user.metaData": @{
                    @"user": @{
                            @"id": @"123",
                            @"name": @"Jane Smith",
                            @"email": @"jane@example.com",
                    }
            }}];
    XCTAssertEqualObjects(@"123", event.user.id);
    XCTAssertEqualObjects(@"Jane Smith", event.user.name);
    XCTAssertEqualObjects(@"jane@example.com", event.user.email);
}

@end
