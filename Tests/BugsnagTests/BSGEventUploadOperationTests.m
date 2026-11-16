//
//  BSGEventUploadOperationTests.m
//  Bugsnag
//
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import "BSGTestCase.h"

#import <Bugsnag/Bugsnag.h>

#import "BSGEventUploadObjectOperation.h"
#import "BugsnagEvent+Private.h"
#import "BugsnagInternals.h"

@interface BSGEventUploadOperationTests : BSGTestCase <BSGEventUploadOperationDelegate>

@property (nonatomic) BugsnagConfiguration *configuration;
@property (nonatomic) BugsnagNotifier *notifier;
@property (nonatomic) NSDictionary *sentPayload;

@end

@implementation BSGEventUploadOperationTests

- (void)setUp {
    [super setUp];
    self.configuration = [[BugsnagConfiguration alloc] initWithApiKey:@"0192837465afbecd0192837465afbecd"];
    self.notifier = [[BugsnagNotifier alloc] init];
    self.sentPayload = nil;
}

#pragma mark - BSGEventUploadOperationDelegate

- (NSString *)storeEventPayload:(__unused NSDictionary *)eventPayload {
    return nil;
}

- (BOOL)shouldDiscardEvent:(NSDictionary *)eventPayload {
    // Capture the payload that would be sent, and stop before any network request is made.
    self.sentPayload = eventPayload;
    return YES;
}

- (BOOL)isRemoteConfigEnabled {
    return NO;
}

#pragma mark - Helpers

- (BugsnagEvent *)eventWithUnhandled:(BOOL)unhandled handledCount:(NSUInteger)handled unhandledCount:(NSUInteger)unhandledCount {
    return [[BugsnagEvent alloc] initWithJson:@{
        @"unhandled": @(unhandled),
        @"severity": unhandled ? @"error" : @"warning",
        @"severityReason": @{@"type": unhandled ? @"unhandledException" : @"handledException"},
        @"exceptions": @[@{
            @"errorClass": @"Out Of Memory",
            @"message": @"The app was likely terminated by the operating system while in the foreground",
            @"type": @"cocoa",
            @"stacktrace": @[],
        }],
        @"session": @{
            @"id": @"8f2b2a1e-0000-4000-8000-000000000000",
            @"startedAt": @"2026-11-16T12:00:00Z",
            @"events": @{@"handled": @(handled), @"unhandled": @(unhandledCount)},
        },
    }];
}

- (void)sendEvent:(BugsnagEvent *)event {
    BSGEventUploadObjectOperation *operation = [[BSGEventUploadObjectOperation alloc] initWithEvent:event delegate:self];
    [operation start];
    XCTAssertNotNil(self.sentPayload);
}

- (NSDictionary *)sentSessionEvents {
    return self.sentPayload[@"session"][@"events"];
}

#pragma mark - Tests

- (void)testOnSendErrorMarkingEventHandledUpdatesOverrideAndSessionCounts {
    [self.configuration addOnSendErrorBlock:^BOOL(BugsnagEvent *event) {
        event.unhandled = NO;
        return YES;
    }];

    [self sendEvent:[self eventWithUnhandled:YES handledCount:2 unhandledCount:1]];

    XCTAssertEqualObjects(self.sentPayload[@"unhandled"], @NO);
    XCTAssertEqualObjects(self.sentPayload[@"severityReason"][@"unhandledOverridden"], @YES);
    XCTAssertEqualObjects(self.sentSessionEvents[@"handled"], @3);
    XCTAssertEqualObjects(self.sentSessionEvents[@"unhandled"], @0);
}

- (void)testOnSendErrorMarkingEventUnhandledUpdatesOverrideAndSessionCounts {
    [self.configuration addOnSendErrorBlock:^BOOL(BugsnagEvent *event) {
        event.unhandled = YES;
        return YES;
    }];

    [self sendEvent:[self eventWithUnhandled:NO handledCount:1 unhandledCount:0]];

    XCTAssertEqualObjects(self.sentPayload[@"unhandled"], @YES);
    XCTAssertEqualObjects(self.sentPayload[@"severityReason"][@"unhandledOverridden"], @YES);
    XCTAssertEqualObjects(self.sentSessionEvents[@"handled"], @0);
    XCTAssertEqualObjects(self.sentSessionEvents[@"unhandled"], @1);
}

- (void)testOnSendErrorChangingAndRestoringUnhandledLeavesEventUnchanged {
    [self.configuration addOnSendErrorBlock:^BOOL(BugsnagEvent *event) {
        event.unhandled = NO;
        return YES;
    }];
    [self.configuration addOnSendErrorBlock:^BOOL(BugsnagEvent *event) {
        event.unhandled = YES;
        return YES;
    }];

    [self sendEvent:[self eventWithUnhandled:YES handledCount:0 unhandledCount:1]];

    XCTAssertEqualObjects(self.sentPayload[@"unhandled"], @YES);
    XCTAssertNil(self.sentPayload[@"severityReason"][@"unhandledOverridden"]);
    XCTAssertEqualObjects(self.sentSessionEvents[@"handled"], @0);
    XCTAssertEqualObjects(self.sentSessionEvents[@"unhandled"], @1);
}

- (void)testOnSendErrorMarkingEventHandledDoesNotUnderflowSessionCounts {
    [self.configuration addOnSendErrorBlock:^BOOL(BugsnagEvent *event) {
        event.unhandled = NO;
        return YES;
    }];

    [self sendEvent:[self eventWithUnhandled:YES handledCount:0 unhandledCount:0]];

    XCTAssertEqualObjects(self.sentPayload[@"unhandled"], @NO);
    XCTAssertEqualObjects(self.sentPayload[@"severityReason"][@"unhandledOverridden"], @YES);
    XCTAssertEqualObjects(self.sentSessionEvents[@"handled"], @0);
    XCTAssertEqualObjects(self.sentSessionEvents[@"unhandled"], @0);
}

@end
