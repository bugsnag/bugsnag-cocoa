//
//  BugsnagSessionTrackerTest.m
//  Tests
//
//  Created by Jamie Lynch on 27/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "BugsnagUser.h"
#import "BugsnagConfiguration.h"
#import "BugsnagSessionTracker.h"
#import "BugsnagSessionTrackingApiClient.h"
#import "BugsnagTestConstants.h"

@interface BugsnagConfiguration ()
- (void)deletePersistedUserData;
@end

@interface BugsnagSessionTrackerTest : XCTestCase
@property BugsnagConfiguration *configuration;
@property BugsnagSessionTracker *sessionTracker;
@property BugsnagUser *user;
@end

@implementation BugsnagSessionTrackerTest

- (void)setUp {
    [super setUp];
    self.configuration = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    [self.configuration deletePersistedUserData];
    self.sessionTracker = [[BugsnagSessionTracker alloc] initWithConfig:self.configuration
                                                     postRecordCallback:nil];
}

- (void)testStartNewSession {
    XCTAssertNil(self.sessionTracker.runningSession);
    [self.sessionTracker startNewSession];
    BugsnagSession *session = self.sessionTracker.runningSession;
    XCTAssertNotNil(session);
    XCTAssertNotNil(session.sessionId);
    XCTAssertTrue([[NSDate date] timeIntervalSinceDate:session.startedAt] < 1);
    XCTAssertFalse(session.autoCaptured);
}

- (void)testStartNewSessionWithUser {
    [self.configuration setUser:@"123" withName:@"Bill" andEmail:nil];
    XCTAssertNil(self.sessionTracker.runningSession);
    [self.sessionTracker startNewSession];
    BugsnagSession *session = self.sessionTracker.runningSession;

    XCTAssertNotNil(session);
    XCTAssertNotNil(session.sessionId);
    XCTAssertTrue([[NSDate date] timeIntervalSinceDate:session.startedAt] < 1);
    XCTAssertEqual(session.user.name, @"Bill");
    XCTAssertEqual(session.user.userId, @"123");
    XCTAssertNil(session.user.emailAddress);
    XCTAssertFalse(session.autoCaptured);
}

- (void)testStartNewAutoCapturedSession {
    XCTAssertNil(self.sessionTracker.runningSession);
    [self.sessionTracker startNewSessionIfAutoCaptureEnabled];
    BugsnagSession *session = self.sessionTracker.runningSession;

    XCTAssertNotNil(session);
    XCTAssertNotNil(session.sessionId);
    XCTAssertTrue([[NSDate date] timeIntervalSinceDate:session.startedAt] < 1);
    XCTAssertTrue(session.autoCaptured);
    XCTAssertNil(session.user.name);
    XCTAssertNil(session.user.userId);
    XCTAssertNil(session.user.emailAddress);
}

- (void)testStartNewAutoCapturedSessionWithUser {
    [self.configuration setUser:@"123" withName:@"Bill" andEmail:@"bill@example.com"];
    XCTAssertNil(self.sessionTracker.runningSession);
    [self.sessionTracker startNewSessionIfAutoCaptureEnabled];
    BugsnagSession *session = self.sessionTracker.runningSession;

    XCTAssertNotNil(session);
    XCTAssertNotNil(session.sessionId);
    XCTAssertTrue([[NSDate date] timeIntervalSinceDate:session.startedAt] < 1);
    XCTAssertEqual(session.user.name, @"Bill");
    XCTAssertEqual(session.user.userId, @"123");
    XCTAssertEqual(session.user.emailAddress, @"bill@example.com");
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
    XCTAssertNotEqualObjects(firstSession.sessionId, secondSession.sessionId);
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

@end
