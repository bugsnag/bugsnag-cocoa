//
//  BugsnagStateEventTest.m
//  Tests
//
//  Created by Jamie Lynch on 18/03/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "Bugsnag.h"
#import "BugsnagConfiguration.h"
#import "BugsnagTestConstants.h"
#import "BugsnagStateEvent.h"
#import "BugsnagMetadataInternal.h"

@interface BugsnagClient()
@property BugsnagMetadata *metadata;
- (void)registerStateObserverWithBlock:(void (^_Nonnull)(BugsnagStateEvent *_Nonnull))event;
@end

@interface BugsnagStateEventTest : XCTestCase
@property BugsnagClient *client;
@property BugsnagStateEvent *event;
@end

@implementation BugsnagStateEventTest

- (void)setUp {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    self.client = [Bugsnag startWithConfiguration:config];

    [self.client registerStateObserverWithBlock:^(BugsnagStateEvent *event) {
        self.event = event;
    }];
}

- (void)testUserUpdate {
    [self.client setUser:@"123" withEmail:@"test@example.com" andName:@"Jamie"];

    BugsnagStateEvent* obj = self.event;
    XCTAssertEqualObjects(@"UserUpdate", obj.name);

    NSDictionary *dict = obj.data;
    XCTAssertEqualObjects(@"123", dict[@"id"]);
    XCTAssertEqualObjects(@"Jamie", dict[@"name"]);
    XCTAssertEqualObjects(@"test@example.com", dict[@"email"]);
}

- (void)testContextUpdate {
    [self.client setContext:@"Foo"];
    BugsnagStateEvent* obj = self.event;
    XCTAssertEqualObjects(@"ContextUpdate", obj.name);
    XCTAssertEqualObjects(@"Foo", obj.data);
}

- (void)testMetadataUpdate {
    XCTAssertNil(self.event);
    [self.client addMetadata:@"Bar" withKey:@"Foo" toSection:@"test"];
    XCTAssertEqualObjects(self.client.metadata, self.event.data);
}

@end
