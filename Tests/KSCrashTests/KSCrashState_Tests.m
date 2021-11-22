//
//  bsg_kscrashstate_Tests.m
//
//  Created by Karl Stenerud on 2012-02-05.
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


#import "FileBasedTestCase.h"

#import "BSG_KSCrashState.h"
#import "BSG_KSCrashC.h"


@interface bsg_kscrashstate_Tests : FileBasedTestCase
@end


@implementation bsg_kscrashstate_Tests

- (void) testInitRelaunch
{
    BSG_KSCrash_State context = {0};
    NSString* stateFile = [self.tempPath stringByAppendingPathComponent:@"state.json"];

        bsg_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);

    XCTAssertTrue(context.applicationIsInForeground, @"");

    XCTAssertEqual(context.foregroundDurationSinceLastCrash, 0.0, @"");
    XCTAssertEqual(context.backgroundDurationSinceLastCrash, 0.0, @"");
    XCTAssertEqual(context.launchesSinceLastCrash, 1, @"");
    XCTAssertEqual(context.sessionsSinceLastCrash, 1, @"");
    XCTAssertEqual(context.appLaunchTime, 0, @"");

    XCTAssertEqual(context.foregroundDurationSinceLaunch, 0.0, @"");
    XCTAssertEqual(context.backgroundDurationSinceLaunch, 0.0, @"");
    XCTAssertEqual(context.sessionsSinceLaunch, 1, @"");

    XCTAssertFalse(context.crashedThisLaunch, @"");
    XCTAssertFalse(context.crashedLastLaunch, @"");

    memset(&context, 0, sizeof(context));
    bsg_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);

    XCTAssertTrue(context.applicationIsInForeground, @"");

    XCTAssertEqual(context.foregroundDurationSinceLastCrash, 0.0, @"");
    XCTAssertEqual(context.backgroundDurationSinceLastCrash, 0.0, @"");
    XCTAssertEqual(context.launchesSinceLastCrash, 2, @"");
    XCTAssertEqual(context.sessionsSinceLastCrash, 2, @"");
    XCTAssertEqual(context.appLaunchTime, 0, @"");

    XCTAssertEqual(context.foregroundDurationSinceLaunch, 0.0, @"");
    XCTAssertEqual(context.backgroundDurationSinceLaunch, 0.0, @"");
    XCTAssertEqual(context.sessionsSinceLaunch, 1, @"");

    XCTAssertFalse(context.crashedThisLaunch, @"");
    XCTAssertFalse(context.crashedLastLaunch, @"");
}

- (void) testInitCrash
{
    BSG_KSCrash_State context = {0};
    NSString* stateFile = [self.tempPath stringByAppendingPathComponent:@"state.json"];

    bsg_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);
    BSG_KSCrash_State checkpoint0 = context;

    usleep(1);
    bsg_kscrashstate_notifyAppCrash();
    BSG_KSCrash_State checkpointC = context;

    XCTAssertTrue(checkpointC.applicationIsInForeground ==
                 checkpoint0.applicationIsInForeground, @"");
    XCTAssertTrue(checkpointC.appLaunchTime == checkpoint0.appLaunchTime, @"");

    XCTAssertGreaterThan(checkpointC.foregroundDurationSinceLastCrash,
                         checkpoint0.foregroundDurationSinceLastCrash);
    XCTAssertTrue(checkpointC.backgroundDurationSinceLastCrash ==
                 checkpoint0.backgroundDurationSinceLastCrash, @"");
    XCTAssertTrue(checkpointC.launchesSinceLastCrash ==
                 checkpoint0.launchesSinceLastCrash, @"");
    XCTAssertTrue(checkpointC.sessionsSinceLastCrash ==
                 checkpoint0.sessionsSinceLastCrash, @"");

    XCTAssertGreaterThan(checkpointC.foregroundDurationSinceLaunch,
                         checkpoint0.foregroundDurationSinceLaunch);
    XCTAssertTrue(checkpointC.backgroundDurationSinceLaunch ==
                 checkpoint0.backgroundDurationSinceLaunch, @"");
    XCTAssertTrue(checkpointC.sessionsSinceLaunch ==
                 checkpoint0.sessionsSinceLaunch, @"");

    XCTAssertTrue(checkpointC.crashedThisLaunch, @"");
    XCTAssertFalse(checkpointC.crashedLastLaunch, @"");

    memset(&context, 0, sizeof(context));
    bsg_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);

    XCTAssertTrue(context.applicationIsInForeground, @"");

    XCTAssertEqual(context.foregroundDurationSinceLastCrash, 0.0, @"");
    XCTAssertEqual(context.backgroundDurationSinceLastCrash, 0.0, @"");
    XCTAssertEqual(context.launchesSinceLastCrash, 1, @"");
    XCTAssertEqual(context.sessionsSinceLastCrash, 1, @"");

    XCTAssertEqual(context.foregroundDurationSinceLaunch, 0.0, @"");
    XCTAssertEqual(context.backgroundDurationSinceLaunch, 0.0, @"");
    XCTAssertEqual(context.sessionsSinceLaunch, 1, @"");

    XCTAssertFalse(context.crashedThisLaunch, @"");
    XCTAssertTrue(context.crashedLastLaunch, @"");
}

- (void)testCrashThisLaunch
{
    BSG_KSCrash_State context = {0};
    NSString* stateFile = [self.tempPath stringByAppendingPathComponent:@"state.json"];

    bsg_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                          &context);
    bsg_kscrashstate_notifyAppCrash();
    XCTAssertTrue(context.crashedThisLaunch, @"");
}

- (void)testRelaunch
{
    BSG_KSCrash_State context = {0};
    NSString* stateFile = [self.tempPath stringByAppendingPathComponent:@"state.json"];

    bsg_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);
    BSG_KSCrash_State checkpoint1 = context;

    XCTAssertFalse(checkpoint1.crashedThisLaunch, @"");
    XCTAssertFalse(checkpoint1.crashedLastLaunch, @"");

    usleep(1);
    memset(&context, 0, sizeof(context));
    bsg_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);
    BSG_KSCrash_State checkpointR = context;

    XCTAssertTrue(checkpointR.applicationIsInForeground, @"");
    XCTAssertEqual(checkpointR.appLaunchTime, 0, @"");

    // We don't save after going inactive, so this will still be 0.
    XCTAssertEqual(checkpointR.foregroundDurationSinceLastCrash, 0.0, @"");
    XCTAssertEqual(checkpointR.backgroundDurationSinceLastCrash, 0.0, @"");
    XCTAssertEqual(checkpointR.launchesSinceLastCrash, 2, @"");
    XCTAssertEqual(checkpointR.sessionsSinceLastCrash, 2, @"");

    XCTAssertEqual(checkpointR.foregroundDurationSinceLaunch, 0.0, @"");
    XCTAssertEqual(checkpointR.backgroundDurationSinceLaunch, 0.0, @"");
    XCTAssertEqual(checkpointR.sessionsSinceLaunch, 1, @"");

    XCTAssertFalse(checkpointR.crashedThisLaunch, @"");
    XCTAssertFalse(checkpointR.crashedLastLaunch, @"");
}

- (void)testBGRelaunch
{
    BSG_KSCrash_State context = {0};
    NSString* stateFile = [self.tempPath stringByAppendingPathComponent:@"state.json"];

    bsg_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);
    BSG_KSCrash_State checkpoint0 = context;
    NSParameterAssert(context.applicationIsInForeground);

    usleep(1);
    bsg_kscrashstate_notifyAppInForeground(false);
    BSG_KSCrash_State checkpoint1 = context;

    XCTAssertTrue(checkpoint1.applicationIsInForeground !=
                 checkpoint0.applicationIsInForeground, @"");
    XCTAssertFalse(checkpoint1.applicationIsInForeground, @"");
    XCTAssertTrue(checkpoint0.appLaunchTime == checkpoint1.appLaunchTime, @"");

    XCTAssertGreaterThan(checkpoint1.foregroundDurationSinceLastCrash,
                         checkpoint0.foregroundDurationSinceLastCrash);
    XCTAssertTrue(checkpoint1.backgroundDurationSinceLastCrash ==
                 checkpoint0.backgroundDurationSinceLastCrash, @"");
    XCTAssertTrue(checkpoint1.launchesSinceLastCrash ==
                 checkpoint0.launchesSinceLastCrash, @"");
    XCTAssertTrue(checkpoint1.sessionsSinceLastCrash ==
                 checkpoint0.sessionsSinceLastCrash, @"");

    XCTAssertGreaterThan(checkpoint1.foregroundDurationSinceLaunch,
                         checkpoint0.foregroundDurationSinceLaunch);
    XCTAssertTrue(checkpoint1.backgroundDurationSinceLaunch ==
                 checkpoint0.backgroundDurationSinceLaunch, @"");
    XCTAssertTrue(checkpoint1.sessionsSinceLaunch ==
                 checkpoint0.sessionsSinceLaunch, @"");

    XCTAssertFalse(checkpoint1.crashedThisLaunch, @"");
    XCTAssertFalse(checkpoint1.crashedLastLaunch, @"");

    usleep(1);
    memset(&context, 0, sizeof(context));
    bsg_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);
    BSG_KSCrash_State checkpointR = context;

    XCTAssertTrue(checkpointR.applicationIsInForeground, @"");

    XCTAssertTrue(checkpointR.foregroundDurationSinceLastCrash > 0, @"");
    XCTAssertEqual(checkpointR.backgroundDurationSinceLastCrash, 0.0, @"");
    XCTAssertEqual(checkpointR.launchesSinceLastCrash, 2, @"");
    XCTAssertEqual(checkpointR.sessionsSinceLastCrash, 2, @"");

    XCTAssertEqual(checkpointR.foregroundDurationSinceLaunch, 0.0, @"");
    XCTAssertEqual(checkpointR.backgroundDurationSinceLaunch, 0.0, @"");
    XCTAssertEqual(checkpointR.sessionsSinceLaunch, 1, @"");

    XCTAssertFalse(checkpointR.crashedThisLaunch, @"");
    XCTAssertFalse(checkpointR.crashedLastLaunch, @"");
}

- (void)testBGTerminate
{
    BSG_KSCrash_State context = {0};
    NSString* stateFile = [self.tempPath stringByAppendingPathComponent:@"state.json"];

    bsg_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);
    NSParameterAssert(context.applicationIsInForeground);
    usleep(1);
    bsg_kscrashstate_notifyAppInForeground(false);
    BSG_KSCrash_State checkpoint0 = context;
    usleep(1);
    bsg_kscrashstate_notifyAppTerminate();

    usleep(1);
    memset(&context, 0, sizeof(context));
    bsg_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);
    BSG_KSCrash_State checkpointR = context;

    XCTAssertTrue(checkpointR.applicationIsInForeground, @"");
    XCTAssertEqual(checkpointR.appLaunchTime, 0, @"");

    XCTAssertTrue(checkpointR.backgroundDurationSinceLastCrash >
                 checkpoint0.backgroundDurationSinceLastCrash, @"");
    XCTAssertEqual(checkpointR.launchesSinceLastCrash, 2, @"");
    XCTAssertEqual(checkpointR.sessionsSinceLastCrash, 2, @"");

    XCTAssertEqual(checkpointR.foregroundDurationSinceLaunch, 0.0, @"");
    XCTAssertEqual(checkpointR.backgroundDurationSinceLaunch, 0.0, @"");
    XCTAssertEqual(checkpointR.sessionsSinceLaunch, 1, @"");

    XCTAssertFalse(checkpointR.crashedThisLaunch, @"");
    XCTAssertFalse(checkpointR.crashedLastLaunch, @"");
}

- (void)testBGCrash
{
    BSG_KSCrash_State context = {0};
    NSString* stateFile = [self.tempPath stringByAppendingPathComponent:@"state.json"];

    bsg_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);
    usleep(1);
    NSParameterAssert(context.applicationIsInForeground);
    bsg_kscrashstate_notifyAppInForeground(false);
    BSG_KSCrash_State checkpoint0 = context;

    usleep(1);
    bsg_kscrashstate_notifyAppCrash();
    BSG_KSCrash_State checkpointC = context;

    XCTAssertTrue(checkpointC.applicationIsInForeground ==
                 checkpoint0.applicationIsInForeground, @"");
    XCTAssertTrue(checkpointC.appLaunchTime == checkpoint0.appLaunchTime, @"");

    XCTAssertTrue(checkpointC.foregroundDurationSinceLastCrash ==
                 checkpoint0.foregroundDurationSinceLastCrash, @"");
    XCTAssertTrue(checkpointC.backgroundDurationSinceLastCrash >
                 checkpoint0.backgroundDurationSinceLastCrash, @"");
    XCTAssertTrue(checkpointC.launchesSinceLastCrash ==
                 checkpoint0.launchesSinceLastCrash, @"");
    XCTAssertTrue(checkpointC.sessionsSinceLastCrash ==
                 checkpoint0.sessionsSinceLastCrash, @"");

    XCTAssertTrue(checkpointC.foregroundDurationSinceLaunch ==
                 checkpoint0.foregroundDurationSinceLaunch, @"");
    XCTAssertTrue(checkpointC.backgroundDurationSinceLaunch >
                 checkpoint0.backgroundDurationSinceLaunch, @"");
    XCTAssertTrue(checkpointC.sessionsSinceLaunch ==
                 checkpoint0.sessionsSinceLaunch, @"");

    XCTAssertTrue(checkpointC.crashedThisLaunch, @"");
    XCTAssertFalse(checkpointC.crashedLastLaunch, @"");

    memset(&context, 0, sizeof(context));
    bsg_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);

    XCTAssertTrue(context.applicationIsInForeground, @"");

    XCTAssertEqual(context.foregroundDurationSinceLastCrash, 0.0, @"");
    XCTAssertEqual(context.backgroundDurationSinceLastCrash, 0.0, @"");
    XCTAssertEqual(context.launchesSinceLastCrash, 1, @"");
    XCTAssertEqual(context.sessionsSinceLastCrash, 1, @"");

    XCTAssertEqual(context.foregroundDurationSinceLaunch, 0.0, @"");
    XCTAssertEqual(context.backgroundDurationSinceLaunch, 0.0, @"");
    XCTAssertEqual(context.sessionsSinceLaunch, 1, @"");

    XCTAssertFalse(context.crashedThisLaunch, @"");
    XCTAssertTrue(context.crashedLastLaunch, @"");
}

- (void) testAppLaunchTime
{
    BSG_KSCrash_State context = {0};
    NSString* stateFile = [self.tempPath stringByAppendingPathComponent:@"state.json"];
    NSData *data = [NSJSONSerialization dataWithJSONObject:@{@"appLaunchTime": @34234235534534 } options:0 error:nil];
    [data writeToFile:stateFile atomically:YES];

    bsg_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                          &context);
    usleep(1);
    XCTAssertEqual(34234235534534, context.appLaunchTime);
}

- (void)testBGFGRelaunch
{
    BSG_KSCrash_State context = {0};
    NSString* stateFile = [self.tempPath stringByAppendingPathComponent:@"state.json"];

    bsg_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);
    usleep(1);
    bsg_kscrashstate_notifyAppInForeground(false);
    usleep(1);
    BSG_KSCrash_State checkpoint0 = context;

    usleep(1);
    bsg_kscrashstate_notifyAppInForeground(true);
    BSG_KSCrash_State checkpoint1 = context;

    XCTAssertTrue(checkpoint1.applicationIsInForeground !=
                 checkpoint0.applicationIsInForeground, @"");
    XCTAssertTrue(checkpoint1.applicationIsInForeground, @"");
    XCTAssertTrue(checkpoint1.appLaunchTime == checkpoint0.appLaunchTime, @"");

    XCTAssertTrue(checkpoint1.foregroundDurationSinceLastCrash ==
                 checkpoint0.foregroundDurationSinceLastCrash, @"");
    XCTAssertTrue(checkpoint1.backgroundDurationSinceLastCrash >
                 checkpoint0.backgroundDurationSinceLastCrash, @"");
    XCTAssertTrue(checkpoint1.launchesSinceLastCrash ==
                 checkpoint0.launchesSinceLastCrash, @"");
    XCTAssertTrue(checkpoint1.sessionsSinceLastCrash ==
                 checkpoint0.sessionsSinceLastCrash + 1, @"");

    XCTAssertTrue(checkpoint1.foregroundDurationSinceLaunch ==
                 checkpoint0.foregroundDurationSinceLaunch, @"");
    XCTAssertTrue(checkpoint1.backgroundDurationSinceLaunch >
                 checkpoint0.backgroundDurationSinceLaunch, @"");
    XCTAssertTrue(checkpoint1.sessionsSinceLaunch ==
                 checkpoint0.sessionsSinceLaunch + 1, @"");

    XCTAssertFalse(checkpoint1.crashedThisLaunch, @"");
    XCTAssertFalse(checkpoint1.crashedLastLaunch, @"");

    usleep(1);
    memset(&context, 0, sizeof(context));
    bsg_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);
    BSG_KSCrash_State checkpointR = context;

    XCTAssertTrue(checkpointR.applicationIsInForeground, @"");

    XCTAssertTrue(checkpointR.foregroundDurationSinceLastCrash > 0, @"");
    // We don't save after going to FG, so this will still be 0.
    XCTAssertEqual(checkpointR.backgroundDurationSinceLastCrash, 0.0, @"");
    XCTAssertEqual(checkpointR.launchesSinceLastCrash, 2, @"");
    XCTAssertEqual(checkpointR.sessionsSinceLastCrash, 2, @"");

    XCTAssertEqual(checkpointR.foregroundDurationSinceLaunch, 0.0, @"");
    XCTAssertEqual(checkpointR.backgroundDurationSinceLaunch, 0.0, @"");
    XCTAssertEqual(checkpointR.sessionsSinceLaunch, 1, @"");

    XCTAssertFalse(checkpointR.crashedThisLaunch, @"");
    XCTAssertFalse(checkpointR.crashedLastLaunch, @"");
}

- (void)testBGFGCrash
{
    BSG_KSCrash_State context = {0};
    NSString* stateFile = [self.tempPath stringByAppendingPathComponent:@"state.json"];

    bsg_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);
    usleep(1);
    bsg_kscrashstate_notifyAppInForeground(false);
    usleep(1);
    bsg_kscrashstate_notifyAppInForeground(true);
    BSG_KSCrash_State checkpoint0 = context;

    usleep(1);
    bsg_kscrashstate_notifyAppCrash();
    BSG_KSCrash_State checkpointC = context;

    XCTAssertTrue(checkpointC.applicationIsInForeground ==
                 checkpoint0.applicationIsInForeground, @"");
    XCTAssertTrue(checkpointC.appLaunchTime == checkpoint0.appLaunchTime, @"");

    XCTAssertGreaterThan(checkpointC.foregroundDurationSinceLastCrash,
                         checkpoint0.foregroundDurationSinceLastCrash);
    XCTAssertTrue(checkpointC.backgroundDurationSinceLastCrash ==
                 checkpoint0.backgroundDurationSinceLastCrash, @"");
    XCTAssertTrue(checkpointC.launchesSinceLastCrash ==
                 checkpoint0.launchesSinceLastCrash, @"");
    XCTAssertTrue(checkpointC.sessionsSinceLastCrash ==
                 checkpoint0.sessionsSinceLastCrash, @"");

    XCTAssertGreaterThan(checkpointC.foregroundDurationSinceLaunch,
                         checkpoint0.foregroundDurationSinceLaunch);
    XCTAssertTrue(checkpointC.backgroundDurationSinceLaunch ==
                 checkpoint0.backgroundDurationSinceLaunch, @"");
    XCTAssertTrue(checkpointC.sessionsSinceLaunch ==
                 checkpoint0.sessionsSinceLaunch, @"");

    XCTAssertTrue(checkpointC.crashedThisLaunch, @"");
    XCTAssertFalse(checkpointC.crashedLastLaunch, @"");

    memset(&context, 0, sizeof(context));
    bsg_kscrashstate_init([stateFile cStringUsingEncoding:NSUTF8StringEncoding],
                      &context);

    XCTAssertTrue(context.applicationIsInForeground, @"");

    XCTAssertEqual(context.foregroundDurationSinceLastCrash, 0.0, @"");
    XCTAssertEqual(context.backgroundDurationSinceLastCrash, 0.0, @"");
    XCTAssertEqual(context.launchesSinceLastCrash, 1, @"");
    XCTAssertEqual(context.sessionsSinceLastCrash, 1, @"");

    XCTAssertEqual(context.foregroundDurationSinceLaunch, 0.0, @"");
    XCTAssertEqual(context.backgroundDurationSinceLaunch, 0.0, @"");
    XCTAssertEqual(context.sessionsSinceLaunch, 1, @"");

    XCTAssertFalse(context.crashedThisLaunch, @"");
    XCTAssertTrue(context.crashedLastLaunch, @"");
}

@end
