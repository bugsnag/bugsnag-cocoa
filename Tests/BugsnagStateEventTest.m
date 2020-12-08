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
#import "BugsnagMetadata+Private.h"

@interface BugsnagClient()
@property BugsnagMetadata *metadata;
- (void)addObserverWithBlock:(BugsnagObserverBlock _Nonnull)observer;
- (void)removeObserverWithBlock:(BugsnagObserverBlock _Nonnull)observer;
@end

@interface BugsnagStateEventTest : XCTestCase
@property BugsnagClient *client;
@property BugsnagStateEvent *event;
@property BugsnagObserverBlock block;
@end

@implementation BugsnagStateEventTest

- (void)setUp {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    self.client = [Bugsnag startWithConfiguration:config];

    __weak __typeof__(self) weakSelf = self;
    self.block = ^(BugsnagStateEvent *event) {
        weakSelf.event = event;
    };
    [self.client addObserverWithBlock:self.block];
}

- (void)testUserUpdate {
    [self.client setUser:@"123" withEmail:@"test@example.com" andName:@"Jamie"];

    BugsnagStateEvent* obj = self.event;
    XCTAssertEqualObjects(@"UserUpdate", obj.type);

    NSDictionary *dict = obj.data;
    XCTAssertEqualObjects(@"123", dict[@"id"]);
    XCTAssertEqualObjects(@"Jamie", dict[@"name"]);
    XCTAssertEqualObjects(@"test@example.com", dict[@"email"]);
}

- (void)testContextUpdate {
    [self.client setContext:@"Foo"];
    BugsnagStateEvent* obj = self.event;
    XCTAssertEqualObjects(@"ContextUpdate", obj.type);
    XCTAssertEqualObjects(@"Foo", obj.data);
}

- (void)testMetadataUpdate {
    XCTAssertNotNil(self.event);
    self.event = nil;
    [self.client addMetadata:@"Bar" withKey:@"Foo2" toSection:@"test"];
    XCTAssertEqualObjects(self.client.metadata, self.event.data);
}

- (void)testRemoveObserver {
    XCTAssertNotNil(self.event);
    self.event = nil;
    [self.client removeObserverWithBlock:self.block];
    [self.client setUser:@"123" withEmail:@"test@example.com" andName:@"Jamie"];
    [self.client setContext:@"Foo"];
    [self.client addMetadata:@"Bar" withKey:@"Foo" toSection:@"test"];
    XCTAssertNil(self.event);
}

- (void)testAddObserverTriggersCallback {
    [self.client setUser:@"123" withEmail:@"test@example.com" andName:@"Jamie"];
    [self.client setContext:@"Foo"];
    [self.client addMetadata:@"Bar" withKey:@"Foo" toSection:@"test"];

    __block NSDictionary *user;
    __block NSString *context;
    __block BugsnagMetadata *metadata;

    self.block = ^(BugsnagStateEvent *event) {
        if ([kStateEventContext isEqualToString:event.type]) {
            context = event.data;
        } else if ([kStateEventUser isEqualToString:event.type]) {
            user = event.data;
        } else if ([kStateEventMetadata isEqualToString:event.type]) {
            metadata = event.data;
        }
    };
    XCTAssertNil(user);
    XCTAssertNil(context);
    XCTAssertNil(metadata);
    [self.client addObserverWithBlock:self.block];

    NSDictionary *expectedUser = @{@"id": @"123", @"email": @"test@example.com", @"name": @"Jamie"};
    XCTAssertEqualObjects(expectedUser, user);
    XCTAssertEqualObjects(@"Foo", context);
    XCTAssertEqualObjects(self.client.metadata, metadata);
}

@end
