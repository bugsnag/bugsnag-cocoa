//
//  KSSystemInfo_Tests.m
//
//  Created by Karl Stenerud on 2013-01-26.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import <XCTest/XCTest.h>

#import "BSG_KSSystemInfo.h"
#import "BSG_KSSystemInfoC.h"


// Test-only bridge between the plain C jailbreak-scan hook
// (bsg_test_support_systeminfo_set_jailbreak_scan_hook, which takes a plain
// function pointer, not a block) and a per-test semaphore.
static dispatch_semaphore_t sKSSystemInfoTestsHoldSemaphore;
static void KSSystemInfoTestsWaitOnHoldSemaphore(void) {
    dispatch_semaphore_wait(sKSSystemInfoTestsHoldSemaphore, DISPATCH_TIME_FOREVER);
}

@interface KSSystemInfo_Tests : XCTestCase @end


@implementation KSSystemInfo_Tests

- (void) testSystemInfo
{
    NSDictionary* info = [BSG_KSSystemInfo systemInfo];
    XCTAssertNotNil(info, @"");
}

- (void) testSystemInfoJSON
{
    const char* json = bsg_kssysteminfo_toJSON();
    XCTAssertTrue(json != NULL, @"");
}

- (void) testCopyProcessName
{
    char* processName = bsg_kssysteminfo_copyProcessName();
    XCTAssertTrue(processName != NULL, @"");
    if(processName != NULL)
    {
        free(processName);
    }
}

// Regression coverage for the non-blocking jailbreak status (see the long
// comment above is_jailbroken() in BSG_KSSystemInfo.m): +systemInfo must
// never wait on the background legacy-scan, only report the best answer
// known at the time it's called. These deliberately avoid wall-clock
// thresholds (flaky under load on CI/simulator hardware) in favor of a test
// hook that holds the scan open deterministically, per review feedback on
// the original timing-based versions of these tests.

- (void)testSystemInfoNeverBlocksWhileScanIsHeldOpen
{
    bsg_test_support_systeminfo_reset_jailbreak_scan();
    dispatch_semaphore_t hold = dispatch_semaphore_create(0);
    sKSSystemInfoTestsHoldSemaphore = hold;
    bsg_test_support_systeminfo_set_jailbreak_scan_hook(&KSSystemInfoTestsWaitOnHoldSemaphore);

    bsg_kssysteminfo_prefetchJailbreakStatus();
    // The background scan is now blocked indefinitely inside the hook above.
    // If +systemInfo (or bsg_kssysteminfo_isJailbroken(), exercised below)
    // ever started waiting on it again, these calls would hang until the
    // test times out; instead they must return immediately regardless.
    NSDictionary *info = [BSG_KSSystemInfo systemInfo];
    XCTAssertNotNil(info);
    XCTAssertNotNil(info[@BSG_KSSystemField_Jailbroken]);
    bool jailbroken = bsg_kssysteminfo_isJailbroken();
    (void)jailbroken;
    XCTAssertFalse(bsg_kssysteminfo_isJailbreakDetectionComplete());

    dispatch_semaphore_signal(hold);
    XCTestExpectation *done = [self expectationWithDescription:@"held scan completes once released"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        while (!bsg_kssysteminfo_isJailbreakDetectionComplete()) {
            usleep(1000);
        }
        [done fulfill];
    });
    [self waitForExpectationsWithTimeout:10 handler:nil];
    bsg_test_support_systeminfo_reset_jailbreak_scan();
    sKSSystemInfoTestsHoldSemaphore = nil;
}

- (void)testJailbreakDetectionEventuallyCompletes
{
    bsg_kssysteminfo_prefetchJailbreakStatus();
    XCTestExpectation *done = [self expectationWithDescription:@"legacy scan completes"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        // Poll rather than block on anything from the production code: this
        // is the test confirming completion eventually happens at all, not
        // exercising the (lack of) blocking behavior itself.
        while (!bsg_kssysteminfo_isJailbreakDetectionComplete()) {
            usleep(1000);
        }
        [done fulfill];
    });
    [self waitForExpectationsWithTimeout:10 handler:nil];
    XCTAssertTrue(bsg_kssysteminfo_isJailbreakDetectionComplete());
}

- (void)testNotifyWhenJailbreakDetectionCompleteNeverRunsSynchronously
{
    // XCTest methods run on the main thread, so a completion that fired
    // synchronously (before notifyWhenJailbreakDetectionComplete: returns)
    // would observe NSThread.isMainThread == YES here.
    XCTestExpectation *done = [self expectationWithDescription:@"completion runs"];
    [BSG_KSSystemInfo notifyWhenJailbreakDetectionComplete:^(BOOL jailbroken) {
        (void)jailbroken;
        XCTAssertFalse(NSThread.isMainThread);
        [done fulfill];
    }];
    [self waitForExpectationsWithTimeout:10 handler:nil];
}

- (void)testNotifyWhenJailbreakDetectionCompleteFiresAfterHeldScanReleases
{
    bsg_test_support_systeminfo_reset_jailbreak_scan();
    dispatch_semaphore_t hold = dispatch_semaphore_create(0);
    sKSSystemInfoTestsHoldSemaphore = hold;
    bsg_test_support_systeminfo_set_jailbreak_scan_hook(&KSSystemInfoTestsWaitOnHoldSemaphore);

    XCTestExpectation *done = [self expectationWithDescription:@"notified after release"];
    __block BOOL notified = NO;
    [BSG_KSSystemInfo notifyWhenJailbreakDetectionComplete:^(BOOL jailbroken) {
        (void)jailbroken;
        notified = YES;
        [done fulfill];
    }];
    // Give the completion a moment to (incorrectly) fire early, then confirm
    // it hasn't: the scan is still held at this point.
    usleep(50 * 1000);
    XCTAssertFalse(notified);

    dispatch_semaphore_signal(hold);
    [self waitForExpectationsWithTimeout:10 handler:nil];
    XCTAssertTrue(notified);
    bsg_test_support_systeminfo_reset_jailbreak_scan();
    sKSSystemInfoTestsHoldSemaphore = nil;
}

@end
