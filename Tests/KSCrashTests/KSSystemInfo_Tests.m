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

// The jailbreak status is detected synchronously (once) from +systemInfo, so
// every reader sees the same, final answer straight away: there is no window
// in which an early reader can get a provisional value.
- (void) testJailbrokenIsPresentAndStable
{
    NSNumber *first = [BSG_KSSystemInfo systemInfo][@BSG_KSSystemField_Jailbroken];
    XCTAssertTrue([first isKindOfClass:[NSNumber class]]);
    for (int i = 0; i < 5; i++) {
        XCTAssertEqualObjects([BSG_KSSystemInfo systemInfo][@BSG_KSSystemField_Jailbroken], first);
    }
}

- (void) testJailbrokenIsConsistentAcrossThreads
{
    NSNumber *expected = [BSG_KSSystemInfo systemInfo][@BSG_KSSystemField_Jailbroken];
    __block BOOL allMatch = YES;
    dispatch_apply(16, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t __unused i) {
        NSNumber *value = [BSG_KSSystemInfo systemInfo][@BSG_KSSystemField_Jailbroken];
        if (![value isEqual:expected]) {
            @synchronized (self) { allMatch = NO; }
        }
    });
    XCTAssertTrue(allMatch);
}

- (void) testSystemInfoJSONAgreesWithSystemInfoOnJailbroken
{
    char *json = bsg_kssysteminfo_toJSON();
    XCTAssertTrue(json != NULL);
    if (json == NULL) return;
    NSData *data = [NSData dataWithBytes:json length:strlen(json)];
    free(json);
    NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    XCTAssertEqualObjects(parsed[@BSG_KSSystemField_Jailbroken],
                          [BSG_KSSystemInfo systemInfo][@BSG_KSSystemField_Jailbroken]);
}

@end
