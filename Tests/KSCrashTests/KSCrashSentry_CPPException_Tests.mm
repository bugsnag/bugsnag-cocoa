//
//  KSCrashSentry_CPPException_Tests.mm
//  Bugsnag
//
//  Created by Meiyalagan Ramadurai on 27/08/26.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#include "BSG_KSCrashSentry_CPPException_Private.h"

#include <atomic>
#include <thread>

@interface KSCrashSentry_CPPException_Tests : XCTestCase
@end

@implementation KSCrashSentry_CPPException_Tests

- (void)tearDown {
    bsg_kscrashsentry_cppExceptionThreadState() = BSG_KSCPPExceptionThreadState{};
    [super tearDown];
}

- (void)testExceptionStateIsIsolatedByThread {
    BSG_KSCPPExceptionThreadState &mainState = bsg_kscrashsentry_cppExceptionThreadState();
    mainState.captureNextStackTrace = false;
    mainState.stackTrace[0] = 0xa;
    mainState.stackTraceCount = 1;

    std::atomic<bool> workerSawDefaults{false};
    std::thread worker([&] {
        BSG_KSCPPExceptionThreadState &workerState =
            bsg_kscrashsentry_cppExceptionThreadState();
        workerSawDefaults.store(workerState.captureNextStackTrace &&
                                workerState.stackTrace[0] == 0 &&
                                workerState.stackTraceCount == 0);
        workerState.captureNextStackTrace = false;
        workerState.stackTrace[0] = 0xb;
        workerState.stackTraceCount = 2;
    });
    worker.join();

    XCTAssertTrue(workerSawDefaults.load());
    XCTAssertFalse(mainState.captureNextStackTrace);
    XCTAssertEqual(mainState.stackTrace[0], (uintptr_t)0xa);
    XCTAssertEqual(mainState.stackTraceCount, 1);
}

- (void)testStackTraceViewSkipsInternalFrames {
    BSG_KSCPPExceptionThreadState state;
    state.stackTraceCount = 4;
    for (int index = 0; index < state.stackTraceCount; index++) {
        state.stackTrace[index] = (uintptr_t)(100 + index);
    }

    BSG_KSCPPExceptionStackTraceView view =
        bsg_kscrashsentry_cppExceptionStackTraceView(state, 2);

    XCTAssertEqual(view.stackTraceLength, 2);
    XCTAssertEqual(view.stackTrace, state.stackTrace + 2);
    XCTAssertEqual(view.stackTrace[0], (uintptr_t)102);
}

- (void)testStackTraceViewSafelyHandlesShortAndInvalidCounts {
    for (int count : {-1, 0, 1, 2}) {
        BSG_KSCPPExceptionThreadState state;
        state.stackTraceCount = count;

        BSG_KSCPPExceptionStackTraceView view =
            bsg_kscrashsentry_cppExceptionStackTraceView(state, 2);

        XCTAssertEqual(view.stackTraceLength, 0, @"count = %d", count);
        XCTAssertEqual(view.stackTrace, nullptr, @"count = %d", count);
    }
}

@end

