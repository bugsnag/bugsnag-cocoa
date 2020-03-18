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

@interface BugsnagConfiguration()
@property BugsnagMetadata *metadata;
- (void)registerStateObserverWithBlock:(void (^_Nonnull)(BugsnagStateEvent *_Nonnull))event;
@end

@interface BugsnagStateEventTest : XCTestCase
@property BugsnagConfiguration *config;
@property BugsnagStateEvent *event;
@property BugsnagMetadata *observedMetadata;
@end

@implementation BugsnagStateEventTest

- (void)setUp {
    self.config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];

    [self.config registerStateObserverWithBlock:^(BugsnagStateEvent *event) {
        self.event = event;
    }];

    __weak __typeof__(self) weakSelf = self;
    [self.config.metadata addObserver:^(BugsnagMetadata *metadata) {
        weakSelf.observedMetadata = metadata;
    }];
}

- (void)testUserUpdate {
    [self.config setUser:@"123" withEmail:@"test@example.com" andName:@"Jamie"];

    BugsnagStateEvent* obj = self.event;
    XCTAssertEqualObjects(@"UserUpdate", obj.name);

    NSDictionary *dict = obj.data;
    XCTAssertEqualObjects(@"123", dict[@"id"]);
    XCTAssertEqualObjects(@"Jamie", dict[@"name"]);
    XCTAssertEqualObjects(@"test@example.com", dict[@"email"]);
}

- (void)testContextUpdate {
    [self.config setContext:@"Foo"];
    BugsnagStateEvent* obj = self.event;
    XCTAssertEqualObjects(@"ContextUpdate", obj.name);
    XCTAssertEqualObjects(@"Foo", obj.data);
}

- (void)testMetadataUpdate {
    XCTAssertNil(self.observedMetadata);
    [self.config addMetadata:@"Bar" withKey:@"Foo" toSection:@"test"];
    XCTAssertEqualObjects(self.config.metadata, self.observedMetadata);
}

@end
