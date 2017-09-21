//
//  BugsnagHandledStateTest.m
//  Bugsnag
//
//  Created by Jamie Lynch on 21/09/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "BugsnagHandledState.h"

@interface BugsnagHandledStateTest : XCTestCase

@end

@implementation BugsnagHandledStateTest

- (void)testUnhandledException {
    BugsnagHandledState *state = [BugsnagHandledState
                                  handledStateWithSeverityReason:UnhandledException];
    XCTAssertNotNil(state);
    XCTAssertTrue(state.unhandled);
    XCTAssertEqual(BSGSeverityError, state.currentSeverity);
}

- (void)testHandledException {
    BugsnagHandledState *state = [BugsnagHandledState
                                  handledStateWithSeverityReason:HandledException];
    XCTAssertNotNil(state);
    XCTAssertFalse(state.unhandled);
    XCTAssertEqual(BSGSeverityWarning, state.currentSeverity);
}

- (void)testUserSpecified {
    BugsnagHandledState *state = [BugsnagHandledState
                                  handledStateWithSeverityReason:UserSpecifiedSeverity
                                  severity:BSGSeverityInfo];
    XCTAssertNotNil(state);
    XCTAssertFalse(state.unhandled);
    XCTAssertEqual(BSGSeverityInfo, state.currentSeverity);
}

- (void)testCallbackSpecified {
    BugsnagHandledState *state = [BugsnagHandledState
                                  handledStateWithSeverityReason:HandledException];
    XCTAssertEqual(HandledException, state.calculateSeverityReasonType);
    
    state.currentSeverity = BSGSeverityInfo;
    XCTAssertEqual(UserCallbackSetSeverity, state.calculateSeverityReasonType);
}

- (void)testHandledError {
    BugsnagHandledState *state = [BugsnagHandledState
                                  handledStateWithSeverityReason:HandledError];
    XCTAssertNotNil(state);
    XCTAssertFalse(state.unhandled);
    XCTAssertEqual(BSGSeverityWarning, state.currentSeverity);
}

- (void)testSignal {
    BugsnagHandledState *state = [BugsnagHandledState
                                  handledStateWithSeverityReason:Signal];
    XCTAssertNotNil(state);
    XCTAssertTrue(state.unhandled);
    XCTAssertEqual(BSGSeverityError, state.currentSeverity);
}

- (void)testInvalidUserSpecified {
    @try {
        [BugsnagHandledState handledStateWithSeverityReason:UserCallbackSetSeverity];
        XCTFail();
    }
    @catch (NSException *ignored) {
    }
}

@end

