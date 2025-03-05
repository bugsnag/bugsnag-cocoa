//
//  KSCrashNames_Test.m
//  Bugsnag
//
//  Created by Karl Stenerud on 01.10.21.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "KSCrashNames.h"
#include <mach/thread_info.h>

@interface KSCrashNames_Test : XCTestCase

@end

@implementation KSCrashNames_Test

- (void)testValidStates {
    XCTAssertTrue(strcmp(kscrashthread_state_name(TH_STATE_RUNNING), "TH_STATE_RUNNING") == 0);
    XCTAssertTrue(strcmp(kscrashthread_state_name(TH_STATE_STOPPED), "TH_STATE_STOPPED") == 0);
    XCTAssertTrue(strcmp(kscrashthread_state_name(TH_STATE_WAITING), "TH_STATE_WAITING") == 0);
    XCTAssertTrue(strcmp(kscrashthread_state_name(TH_STATE_UNINTERRUPTIBLE), "TH_STATE_UNINTERRUPTIBLE") == 0);
    XCTAssertTrue(strcmp(kscrashthread_state_name(TH_STATE_HALTED), "TH_STATE_HALTED") == 0);
}

- (void)testInvalidStates {
    for (integer_t i = -100; i <= 100; i++) {
        switch (i) {
            case TH_STATE_RUNNING:
            case TH_STATE_STOPPED:
            case TH_STATE_WAITING:
            case TH_STATE_UNINTERRUPTIBLE:
            case TH_STATE_HALTED:
                continue;
            default:
                XCTAssert(kscrashthread_state_name(i) == NULL);
        }
    }
}

@end
