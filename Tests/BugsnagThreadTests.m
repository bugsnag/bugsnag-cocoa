//
//  BugsnagThreadTests.m
//  Tests
//
//  Created by Jamie Lynch on 07/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "BSG_KSMachHeaders.h"
#import "BugsnagStackframe+Private.h"
#import "BugsnagThread+Private.h"

#include <stdatomic.h>

@interface BugsnagThreadTests : XCTestCase
@property NSArray *binaryImages;
@property NSDictionary *thread;
@end

@implementation BugsnagThreadTests

+ (void)setUp {
    bsg_mach_headers_initialize();
    bsg_mach_headers_register_for_changes();
}

- (void)setUp {
    self.thread = @{
            @"current_thread": @YES,
            @"crashed": @YES,
            @"index": @4,
            @"backtrace": @{
                    @"skipped": @0,
                    @"contents": @[
                            @{
                                    @"symbol_name": @"kscrashsentry_reportUserException",
                                    @"symbol_addr": @4491038467,
                                    @"instruction_addr": @4491038575,
                                    @"object_name": @"CrashProbeiOS",
                                    @"object_addr": @4490747904
                            }
                    ]
            },
    };
    self.binaryImages = @[@{
            @"uuid": @"D0A41830-4FD2-3B02-A23B-0741AD4C7F52",
            @"image_vmaddr": @4294967296,
            @"image_addr": @4490747904,
            @"image_size": @483328,
            @"name": @"/Users/joesmith/foo",
    }];
}

- (void)testThreadFromDict {
    BugsnagThread *thread = [[BugsnagThread alloc] initWithThread:self.thread binaryImages:self.binaryImages];
    XCTAssertNotNil(thread);

    XCTAssertEqualObjects(@"4", thread.id);
    XCTAssertNil(thread.name);
    XCTAssertEqual(BSGThreadTypeCocoa, thread.type);
    XCTAssertTrue(thread.errorReportingThread);

    // validate stacktrace
    XCTAssertEqual(1, [thread.stacktrace count]);
    BugsnagStackframe *frame = thread.stacktrace[0];
    XCTAssertEqualObjects(@"kscrashsentry_reportUserException", frame.method);
    XCTAssertEqualObjects(@"/Users/joesmith/foo", frame.machoFile);
    XCTAssertEqualObjects(@"D0A41830-4FD2-3B02-A23B-0741AD4C7F52", frame.machoUuid);
}

- (void)testThreadToDict {
    BugsnagThread *thread = [[BugsnagThread alloc] initWithThread:self.thread binaryImages:self.binaryImages];
    thread.name = @"bugsnag-thread-1";

    NSDictionary *dict = [thread toDictionary];
    XCTAssertEqualObjects(@"4", dict[@"id"]);
    XCTAssertEqualObjects(@"bugsnag-thread-1", dict[@"name"]);
    XCTAssertEqualObjects(@"cocoa", dict[@"type"]);
    XCTAssertTrue([dict[@"errorReportingThread"] boolValue]);

    // validate stacktrace
    XCTAssertEqual(1, [dict[@"stacktrace"] count]);
    NSDictionary *frame = dict[@"stacktrace"][0];
    XCTAssertEqualObjects(@"kscrashsentry_reportUserException", frame[@"method"]);
    XCTAssertEqualObjects(@"/Users/joesmith/foo", frame[@"machoFile"]);
    XCTAssertEqualObjects(@"D0A41830-4FD2-3B02-A23B-0741AD4C7F52", frame[@"machoUUID"]);
}

/**
 * Dictionary info not enhanced if not an error reporting thread
 */
- (void)testThreadEnhancementNotCrashed {
    NSDictionary *dict = @{
            @"backtrace": @{
                    @"contents": @[
                            @{},
                            @{},
                            @{},
                    ]
            },
            @"crashed": @NO
    };
    NSDictionary *thread = [BugsnagThread enhanceThreadInfo:dict depth:0 errorType:nil];
    XCTAssertEqual(dict, thread);
}

/**
 * Dictionary info enhanced if an error reporting thread
 */
- (void)testThreadEnhancementCrashed {
    NSDictionary *dict = @{
            @"backtrace": @{
                    @"contents": @[
                            @{},
                            @{},
                            @{},
                    ]
            },
            @"crashed": @YES
    };
    NSDictionary *thread = [BugsnagThread enhanceThreadInfo:dict depth:0 errorType:nil];
    XCTAssertNotEqual(dict, thread);
    NSArray *trace = thread[@"backtrace"][@"contents"];
    XCTAssertEqual(3, [trace count]);
}

/**
 * Frames enhanced with lc/pr info
 */
- (void)testThreadEnhancementLcPr {
    NSDictionary *dict = @{
            @"backtrace": @{
                    @"contents": @[
                            @{},
                            @{},
                            @{}
                    ]
            },
            @"crashed": @YES
    };
    NSDictionary *thread = [BugsnagThread enhanceThreadInfo:dict depth:0 errorType:@"signal"];
    XCTAssertNotEqual(dict, thread);
    NSArray *trace = thread[@"backtrace"][@"contents"];
    XCTAssertEqual(3, [trace count]);

    XCTAssertEqual(1, [trace[0] count]);
    XCTAssertTrue(trace[0][@"isPC"]);
    XCTAssertEqual(1, [trace[1] count]);
    XCTAssertTrue(trace[1][@"isLR"]);
    XCTAssertEqual(0, [trace[2] count]);
}

/**
 * Frames enhanced with lc/pr info, wrong error type
 */
- (void)testThreadEnhancementWrongErrorType {
    NSDictionary *dict = @{
            @"backtrace": @{
                    @"contents": @[
                            @{},
                            @{},
                            @{}
                    ]
            },
            @"crashed": @YES
    };
    NSDictionary *thread = [BugsnagThread enhanceThreadInfo:dict depth:0 errorType:@"NSException"];
    XCTAssertNotEqual(dict, thread);
    NSArray *trace = thread[@"backtrace"][@"contents"];
    XCTAssertEqual(3, [trace count]);

    XCTAssertEqual(1, [trace[0] count]);
    XCTAssertTrue(trace[0][@"isPC"]);
    XCTAssertEqual(0, [trace[1] count]);
    XCTAssertEqual(0, [trace[2] count]);
}

/**
 * Frames not enhanced with lc/pr info in stack overflow
 */
- (void)testThreadEnhancementStackoverflow {
    NSDictionary *dict = @{
            @"backtrace": @{
                    @"contents": @[
                            @{},
                            @{},
                            @{}
                    ]
            },
            @"crashed": @YES,
            @"stack": @{
                    @"overflow": @YES
            }
    };
    NSDictionary *thread = [BugsnagThread enhanceThreadInfo:dict depth:0 errorType:@"signal"];
    XCTAssertNotEqual(dict, thread);
    NSArray *trace = thread[@"backtrace"][@"contents"];
    XCTAssertEqual(3, [trace count]);
    XCTAssertEqual(0, [trace[0] count]);
    XCTAssertEqual(0, [trace[1] count]);
    XCTAssertEqual(0, [trace[2] count]);
}

- (void)testStacktraceOverride {
    BugsnagThread *thread = [[BugsnagThread alloc] initWithThread:self.thread binaryImages:self.binaryImages];
    XCTAssertNotNil(thread.stacktrace);
    XCTAssertEqual(1, thread.stacktrace.count);
    thread.stacktrace = @[];
    XCTAssertEqual(0, thread.stacktrace.count);
}

// MARK: - BugsnagThread (Recording)

- (void)testAllThreads {
    NSArray<BugsnagThread *> *threads = [BugsnagThread allThreads:YES callStackReturnAddresses:NSThread.callStackReturnAddresses];
    [threads[0].stacktrace makeObjectsPerformSelector:@selector(symbolicateIfNeeded)];
    XCTAssertTrue(threads[0].errorReportingThread);
    XCTAssertEqualObjects(threads[0].name, @"com.apple.main-thread");
    XCTAssertEqualObjects(threads[0].stacktrace.firstObject.method, @(__PRETTY_FUNCTION__));
    XCTAssertGreaterThan(threads.count, 1);
}

- (void)testCurrentThread {
    NSArray<BugsnagThread *> *threads = [BugsnagThread allThreads:NO callStackReturnAddresses:NSThread.callStackReturnAddresses];
    [threads[0].stacktrace makeObjectsPerformSelector:@selector(symbolicateIfNeeded)];
    XCTAssertEqual(threads.count, 1);
    XCTAssertTrue(threads[0].errorReportingThread);
    XCTAssertEqualObjects(threads[0].id, @"0");
    XCTAssertEqualObjects(threads[0].name, @"com.apple.main-thread");
    XCTAssertEqualObjects(threads[0].stacktrace.firstObject.method, @(__PRETTY_FUNCTION__));
}

- (void)testCurrentThreadFromBackground {
    __block BugsnagThread *thread = nil;
    XCTestExpectation *expectation = [self expectationWithDescription:@"Thread recorded in background"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        thread = [BugsnagThread allThreads:NO callStackReturnAddresses:NSThread.callStackReturnAddresses][0];
        [thread.stacktrace makeObjectsPerformSelector:@selector(symbolicateIfNeeded)];
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertTrue(thread.errorReportingThread);
    XCTAssertGreaterThan(thread.id.intValue, 0);
    XCTAssertNotNil(thread.name);
    XCTAssertNotEqualObjects(thread.name, @"com.apple.main-thread");
    XCTAssert([thread.stacktrace.firstObject.method hasSuffix:@"_block_invoke"]);
}

- (void)testMainThread {
    BugsnagThread *thread = [BugsnagThread mainThread];
    XCTAssertNil(thread);
}

- (void)testMainThreadFromBackground {
    NSParameterAssert(NSThread.currentThread.isMainThread);
    __block BugsnagThread *thread = nil;
    __block atomic_int state = 0;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        while (atomic_load(&state) != 1) {
            // Wait for main thread to be back in -testMainThreadFromBackground
        }
        thread = [BugsnagThread mainThread];
        [thread.stacktrace makeObjectsPerformSelector:@selector(symbolicateIfNeeded)];
        atomic_store(&state, 2);
    });
    atomic_store(&state, 1);
    while (atomic_load(&state) != 2) {
        // Wait for `thread` to be set by background queue.
        // Busy waiting so that this method will appear at the top of the stack trace.
    }
    XCTAssertTrue(thread.errorReportingThread);
    XCTAssertEqualObjects(thread.id, @"0");
    XCTAssertEqualObjects(thread.name, @"com.apple.main-thread");
    XCTAssertEqualObjects(thread.stacktrace.firstObject.method, @(__PRETTY_FUNCTION__));
}

@end
