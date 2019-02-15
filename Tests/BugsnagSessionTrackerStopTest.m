//
//  BugsnagSessionTrackerStopTest.m
//  Tests
//
//  Created by Jamie Lynch on 15/02/2019.
//  Copyright © 2019 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "BugsnagConfiguration.h"
#import "BugsnagSessionTracker.h"

@interface BugsnagSessionTrackerStopTest : XCTestCase
@property BugsnagConfiguration *configuration;
@property BugsnagSessionTracker *tracker;
@end

@implementation BugsnagSessionTrackerStopTest

- (void)setUp {
    [super setUp];
    self.configuration = [BugsnagConfiguration new];
    self.configuration.apiKey = @"test";
    self.configuration.shouldAutoCaptureSessions = NO;
    self.tracker = [[BugsnagSessionTracker alloc] initWithConfig:self.configuration postRecordCallback:nil];
}

/**
 * Verifies that a session can be resumed after it is stopped
 */
- (void)testResumeFromStoppedSession {
    [self.tracker startNewSession];
    BugsnagSession *original = self.tracker.currentSession;
    XCTAssertNotNil(original);

    [self.tracker stopSession];
    XCTAssertNil(self.tracker.currentSession);

    XCTAssertTrue([self.tracker resumeSession]);
    XCTAssertEqual(original, self.self.tracker.currentSession);
}

/**
 * Verifies that a new session is started when calling resumeSession,
 * if there is no stopped session
 */
- (void)testResumeWithNoStoppedSession {
    XCTAssertNil(self.tracker.currentSession);
    XCTAssertFalse([self.tracker resumeSession]);
    XCTAssertNotNil(self.tracker.currentSession);
}

/**
 * Verifies that a new session can be created after the previous one is stopped
 */
- (void)testStartNewAfterStoppedSession {
    [self.tracker startNewSession];
    BugsnagSession *originalSession = self.tracker.currentSession;

    [self.tracker stopSession];
    [self.tracker startNewSession];
    XCTAssertNotEqual(originalSession, self.tracker.currentSession);
}

/**
 * Verifies that calling resumeSession multiple times only starts one session
 */
- (void)testMultipleResumesHaveNoEffect {
    [self.tracker startNewSession];
    BugsnagSession *original = self.tracker.currentSession;
    [self.tracker stopSession];

    XCTAssertTrue([self.tracker resumeSession]);
    XCTAssertEqual(original, self.tracker.currentSession);

    XCTAssertFalse([self.tracker resumeSession]);
    XCTAssertEqual(original, self.tracker.currentSession);
}

/**
 * Verifies that calling stopSession multiple times only stops one session
 */
- (void)testMultipleStopsHaveNoEffect {
    [self.tracker startNewSession];
    XCTAssertNotNil(self.tracker.currentSession);

    [self.tracker stopSession];
    XCTAssertNil(self.tracker.currentSession);

    [self.tracker stopSession];
    XCTAssertNil(self.tracker.currentSession);
}

/**
 * Verifies that if a handled or unhandled error occurs when a session is stopped, the
 * error count is not updated
 */
- (void)testStoppedSessionDoesNotIncrement {
    [self.tracker startNewSession];

    self.tracker.currentSession.handledCount++;
    self.tracker.currentSession.unhandledCount++;
    XCTAssertEqual(1, self.tracker.currentSession.handledCount);
    XCTAssertEqual(1, self.tracker.currentSession.unhandledCount);

    [self.tracker stopSession];
    self.tracker.currentSession.handledCount++;
    self.tracker.currentSession.unhandledCount++;
    [self.tracker resumeSession];
    XCTAssertEqual(1, self.tracker.currentSession.handledCount);
    XCTAssertEqual(1, self.tracker.currentSession.unhandledCount);

    self.tracker.currentSession.handledCount++;
    self.tracker.currentSession.unhandledCount++;
    XCTAssertEqual(2, self.tracker.currentSession.handledCount);
    XCTAssertEqual(2, self.tracker.currentSession.unhandledCount);
}

@end
