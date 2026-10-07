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
// known at the time it's called.

- (void)testSystemInfoNeverBlocksOnJailbreakScan
{
    // A generous upper bound: even a slow device's dyld image scan is many
    // orders of magnitude faster than this, so if +systemInfo ever starts
    // waiting on it again, this is expected to fail well before it would
    // from simply running on slow CI hardware.
    NSDate *start = [NSDate date];
    NSDictionary *info = [BSG_KSSystemInfo systemInfo];
    NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:start];
    XCTAssertNotNil(info);
    XCTAssertLessThan(elapsed, 0.25);
}

- (void)testJailbreakStatusIsReadableWithoutBlocking
{
    bsg_kssysteminfo_prefetchJailbreakStatus();
    // A bare atomic load: must return immediately regardless of whether the
    // background scan it reflects has finished yet.
    NSDate *start = [NSDate date];
    bool jailbroken = bsg_kssysteminfo_isJailbroken();
    NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:start];
    (void)jailbroken;
    XCTAssertLessThan(elapsed, 0.01);
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

@end
