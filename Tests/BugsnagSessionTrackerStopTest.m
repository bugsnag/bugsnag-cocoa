//
//  BugsnagSessionTrackerStopTest.m
//  Tests
//
//  Created by Jamie Lynch on 15/02/2019.
//  Copyright © 2019 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "BugsnagSessionTracker.h"
#import "BugsnagTestConstants.h"

@interface BugsnagSessionTrackerStopTest : XCTestCase
@property BugsnagConfiguration *configuration;
@property BugsnagSessionTracker *tracker;
@end

@implementation BugsnagSessionTrackerStopTest

- (void)setUp {
    [super setUp];
    self.configuration = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    self.configuration.autoTrackSessions = NO;
    self.tracker = [[BugsnagSessionTracker alloc] initWithConfig:self.configuration postRecordCallback:nil];
}

/**
 * Verifies that a session can be resumed after it is stopped
 */
- (void)testResumeFromStoppedSession {
    [self.tracker startNewSession];
    BugsnagSession *original = self.tracker.runningSession;
    XCTAssertNotNil(original);

    [self.tracker stopSession];
    XCTAssertNil(self.tracker.runningSession);

    XCTAssertTrue([self.tracker resumeSession]);
    XCTAssertEqual(original, self.self.tracker.runningSession);
}

/**
 * Verifies that a new session is started when calling resumeSession,
 * if there is no stopped session
 */
- (void)testResumeWithNoStoppedSession {
    XCTAssertNil(self.tracker.runningSession);
    XCTAssertFalse([self.tracker resumeSession]);
    XCTAssertNotNil(self.tracker.runningSession);
}

/**
 * Verifies that a new session can be created after the previous one is stopped
 */
- (void)testStartNewAfterStoppedSession {
    [self.tracker startNewSession];
    BugsnagSession *originalSession = self.tracker.runningSession;

    [self.tracker stopSession];
    [self.tracker startNewSession];
    XCTAssertNotEqual(originalSession, self.tracker.runningSession);
}

/**
 * Verifies that calling resumeSession multiple times only starts one session
 */
- (void)testMultipleResumesHaveNoEffect {
    [self.tracker startNewSession];
    BugsnagSession *original = self.tracker.runningSession;
    [self.tracker stopSession];

    XCTAssertTrue([self.tracker resumeSession]);
    XCTAssertEqual(original, self.tracker.runningSession);

    XCTAssertFalse([self.tracker resumeSession]);
    XCTAssertEqual(original, self.tracker.runningSession);
}

/**
 * Verifies that calling stopSession multiple times only stops one session
 */
- (void)testMultipleStopsHaveNoEffect {
    [self.tracker startNewSession];
    XCTAssertNotNil(self.tracker.runningSession);

    [self.tracker stopSession];
    XCTAssertNil(self.tracker.runningSession);

    [self.tracker stopSession];
    XCTAssertNil(self.tracker.runningSession);
}

/**
 * Verifies that if a handled or unhandled error occurs when a session is stopped, the
 * error count is not updated
 */
- (void)testStoppedSessionDoesNotIncrement {
    [self.tracker startNewSession];

    self.tracker.runningSession.handledCount++;
    self.tracker.runningSession.unhandledCount++;
    XCTAssertEqual(1, self.tracker.runningSession.handledCount);
    XCTAssertEqual(1, self.tracker.runningSession.unhandledCount);

    [self.tracker stopSession];
    self.tracker.runningSession.handledCount++;
    self.tracker.runningSession.unhandledCount++;
    [self.tracker resumeSession];
    XCTAssertEqual(1, self.tracker.runningSession.handledCount);
    XCTAssertEqual(1, self.tracker.runningSession.unhandledCount);

    self.tracker.runningSession.handledCount++;
    self.tracker.runningSession.unhandledCount++;
    XCTAssertEqual(2, self.tracker.runningSession.handledCount);
    XCTAssertEqual(2, self.tracker.runningSession.unhandledCount);
}

@end
