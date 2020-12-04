//
//  BugsnagSessionTrackerTest.m
//  Tests
//
//  Created by Jamie Lynch on 27/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "BugsnagUser.h"
#import "BugsnagConfiguration+Private.h"
#import "BugsnagSession+Private.h"
#import "BugsnagSessionTracker+Private.h"
#import "BugsnagSessionTrackingApiClient.h"
#import "BugsnagTestConstants.h"

@interface BugsnagSessionTrackerTest : XCTestCase
@property BugsnagConfiguration *configuration;
@property BugsnagSessionTracker *sessionTracker;
@property BugsnagUser *user;
@end

@implementation BugsnagSessionTrackerTest

- (void)setUp {
    [super setUp];
    self.configuration = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    [self.configuration deletePersistedUserData];
    self.sessionTracker = [[BugsnagSessionTracker alloc] initWithConfig:self.configuration
                                                                 client:nil
                                                     postRecordCallback:nil];
}

- (void)testStartNewSession {
    XCTAssertNil(self.sessionTracker.runningSession);
    [self.sessionTracker startNewSession];
    BugsnagSession *session = self.sessionTracker.runningSession;
    XCTAssertNotNil(session);
    XCTAssertNotNil(session.id);
    XCTAssertTrue([[NSDate date] timeIntervalSinceDate:session.startedAt] < 1);
    XCTAssertFalse(session.autoCaptured);
}

- (void)testStartNewSessionWithUser {
    [self.configuration setUser:@"123" withEmail:nil andName:@"Bill"];
    XCTAssertNil(self.sessionTracker.runningSession);
    [self.sessionTracker startNewSession];
    BugsnagSession *session = self.sessionTracker.runningSession;

    XCTAssertNotNil(session);
    XCTAssertNotNil(session.id);
    XCTAssertTrue([[NSDate date] timeIntervalSinceDate:session.startedAt] < 1);
    XCTAssertFalse(session.autoCaptured);
}

- (void)testStartNewAutoCapturedSession {
    XCTAssertNil(self.sessionTracker.runningSession);
    [self.sessionTracker startNewSessionIfAutoCaptureEnabled];
    BugsnagSession *session = self.sessionTracker.runningSession;

    XCTAssertNotNil(session);
    XCTAssertNotNil(session.id);
    XCTAssertTrue([[NSDate date] timeIntervalSinceDate:session.startedAt] < 1);
    XCTAssertTrue(session.autoCaptured);
    XCTAssertNil(session.user.name);
    XCTAssertNil(session.user.id);
    XCTAssertNil(session.user.email);
}

- (void)testStartNewAutoCapturedSessionWithUser {
    [self.configuration setUser:@"123" withEmail:@"bill@example.com" andName:@"Bill"];
    XCTAssertNil(self.sessionTracker.runningSession);
    [self.sessionTracker startNewSessionIfAutoCaptureEnabled];
    BugsnagSession *session = self.sessionTracker.runningSession;

    XCTAssertNotNil(session);
    XCTAssertNotNil(session.id);
    XCTAssertTrue([[NSDate date] timeIntervalSinceDate:session.startedAt] < 1);
    XCTAssertTrue(session.autoCaptured);
}

- (void)testStartNewAutoCapturedSessionWithAutoCaptureDisabled {
    XCTAssertNil(self.sessionTracker.runningSession);
    self.configuration.autoTrackSessions = NO;
    [self.sessionTracker startNewSessionIfAutoCaptureEnabled];
    BugsnagSession *session = self.sessionTracker.runningSession;

    XCTAssertNil(session);
}

- (void)testUniqueSessionIds {
    [self.sessionTracker startNewSession];
    BugsnagSession *firstSession = self.sessionTracker.runningSession;

    [self.sessionTracker startNewSession];

    BugsnagSession *secondSession = self.sessionTracker.runningSession;
    XCTAssertNotEqualObjects(firstSession.id, secondSession.id);
}

- (void)testIncrementCounts {

    [self.sessionTracker startNewSession];
    [self.sessionTracker handleHandledErrorEvent];
    [self.sessionTracker handleHandledErrorEvent];

    BugsnagSession *session = self.sessionTracker.runningSession;
    XCTAssertNotNil(session);
    XCTAssertEqual(2, session.handledCount);
    XCTAssertEqual(0, session.unhandledCount);

    [self.sessionTracker startNewSession];

    session = self.sessionTracker.runningSession;
    XCTAssertEqual(0, session.handledCount);
    XCTAssertEqual(0, session.unhandledCount);

    [self.sessionTracker handleUnhandledErrorEvent];
    XCTAssertEqual(0, session.handledCount);
    XCTAssertEqual(1, session.unhandledCount);

    [self.sessionTracker handleHandledErrorEvent];
    XCTAssertEqual(1, session.handledCount);
    XCTAssertEqual(1, session.unhandledCount);
}

- (void)testOnSendBlockFalse {
    self.configuration = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    [self.configuration addOnSessionBlock:^BOOL(BugsnagSession *sessionPayload) {
        return NO;
    }];
    self.sessionTracker = [[BugsnagSessionTracker alloc] initWithConfig:self.configuration
                                                                 client:nil
                                                     postRecordCallback:nil];
    [self.sessionTracker startNewSession];
    XCTAssertNil(self.sessionTracker.currentSession);
}

- (void)testOnSendBlockTrue {
    __block XCTestExpectation *expectation = [self expectationWithDescription:@"Session block is invoked"];

    self.configuration = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    [self.configuration addOnSessionBlock:^BOOL(BugsnagSession *sessionPayload) {
        [expectation fulfill];
        return YES;
    }];
    self.sessionTracker = [[BugsnagSessionTracker alloc] initWithConfig:self.configuration
                                                                 client:nil
                                                     postRecordCallback:nil];
    [self.sessionTracker startNewSession];
    [self waitForExpectations:@[expectation] timeout:2];
    XCTAssertNotNil(self.sessionTracker.currentSession);
}


@end
