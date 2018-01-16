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
#import "BugsnagApiClient.h"

@interface BugsnagSessionTrackerTest : XCTestCase
@property BugsnagConfiguration *configuration;
@property BugsnagSessionTracker *sessionTracker;
@property BugsnagUser *user;
@end

@implementation BugsnagSessionTrackerTest

- (void)setUp {
    [super setUp];
    self.configuration = [BugsnagConfiguration new];
    self.configuration.apiKey = @"test";
    self.configuration.shouldAutoCaptureSessions = YES;
    self.user = [BugsnagUser new];
    self.sessionTracker = [[BugsnagSessionTracker alloc] initWithConfig:self.configuration
                                                              apiClient:[BugsnagApiClient new]
                                                               callback:NULL];
}

- (void)testStartNewSession {
    XCTAssertNil(self.sessionTracker.currentSession);
    NSDate *now = [NSDate date];
    [self.sessionTracker startNewSession:now
                                withUser:self.user
                            autoCaptured:NO];
    BugsnagSession *session = self.sessionTracker.currentSession;
    XCTAssertNotNil(session);
    XCTAssertNotNil(session.sessionId);
    XCTAssertEqualObjects(now, session.startedAt);
    XCTAssertNotNil(session.user);
}

- (void)testUniqueSessionIds {
    [self.sessionTracker startNewSession:[NSDate date]
                                withUser:self.user
                            autoCaptured:NO];
    BugsnagSession *firstSession = self.sessionTracker.currentSession;

    [self.sessionTracker startNewSession:[NSDate date]
                                withUser:self.user
                            autoCaptured:NO];

    BugsnagSession *secondSession = self.sessionTracker.currentSession;
    XCTAssertNotEqualObjects(firstSession.sessionId, secondSession.sessionId);
}

- (void)testIncrementCounts {

    [self.sessionTracker startNewSession:[NSDate date]
                                withUser:self.user
                            autoCaptured:NO];
    [self.sessionTracker incrementHandledError];
    [self.sessionTracker incrementHandledError];

    BugsnagSession *session = self.sessionTracker.currentSession;
    XCTAssertNotNil(session);
    XCTAssertEqual(2, session.handledCount);
    XCTAssertEqual(0, session.unhandledCount);

    [self.sessionTracker startNewSession:[NSDate date]
                                withUser:self.user
                            autoCaptured:NO];

    session = self.sessionTracker.currentSession;
    XCTAssertEqual(0, session.handledCount);
    XCTAssertEqual(0, session.unhandledCount);
}

- (void)testBasicInForeground {
    XCTAssertFalse(self.sessionTracker.isInForeground);
    XCTAssertNil(self.sessionTracker.currentSession);

    NSDate *now = [NSDate date];
    [self.sessionTracker startNewSession:now withUser:nil autoCaptured:NO];
    XCTAssertTrue(self.sessionTracker.isInForeground);

    [self.sessionTracker suspendCurrentSession:now];
    XCTAssertFalse(self.sessionTracker.isInForeground);
}

@end

