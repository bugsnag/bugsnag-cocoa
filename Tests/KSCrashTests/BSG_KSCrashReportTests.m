//
//  BSG_KSCrashReportTests.m
//  Bugsnag
//
//  Created by Nick Dowell on 06/01/2022.
//  Copyright © 2022 Bugsnag Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "BSG_KSCrashC.h"
#import "BSG_KSCrashReport.h"
#import "BSG_KSCrashSentry_Private.h"
#import "BSG_KSMach.h"

@interface BSG_KSCrashReportTests : XCTestCase

@end

@implementation BSG_KSCrashReportTests

- (void)testWriteStandardReportPerformance {
    NSString *directory = NSTemporaryDirectory();
    NSString *crashReportFilePath = [directory stringByAppendingPathComponent:@"crash_report"];
    NSString *recrashReportFilePath = [directory stringByAppendingPathComponent:@"recrash_report"];
    NSString *stateFilePath = [directory stringByAppendingPathComponent:@"kscrash_state"];
    NSString *crashID = [[NSUUID UUID] UUIDString];
    
    bsg_kscrash_init();
    bsg_kscrash_setHandlingCrashTypes(BSG_KSCrashTypeNSException);
    bsg_kscrash_install([crashReportFilePath fileSystemRepresentation],
                        [recrashReportFilePath fileSystemRepresentation],
                        [stateFilePath fileSystemRepresentation],
                        [crashID UTF8String]);
    
    // Make a fake stack trace with addresses from a library (Foundation) that will generate a non-trivial symbolication workload.
    
    const int numFrames = 500;
    uintptr_t stackTrace[numFrames];
    for (int i = 0; i < numFrames; i++) {
        stackTrace[i] = NSLog;
        assert(stackTrace[i] != 0);
    }
    
    BSG_KSCrash_Context *context = crashContext();
    context->crash.crashType = BSG_KSCrashTypeNSException;
    context->crash.offendingThread = bsg_ksmachthread_self();
    context->crash.registersAreValid = false;
    context->crash.NSException.name = "BSG_KSCrashReportTests";
    context->crash.crashReason = "testWriteStandardReportPerformance";
    context->crash.stackTrace = stackTrace;
    context->crash.stackTraceLength = numFrames;
    context->crash.threadTracingEnabled = true;
    
    [self measureMetrics:[[self class] defaultPerformanceMetrics] automaticallyStartMeasuring:NO forBlock:^{
        const char *reportPath = [crashReportFilePath fileSystemRepresentation];
        
        [self startMeasuring]; {
            bsg_kscrashsentry_suspendThreads();
            bsg_kscrashreport_writeStandardReport(context, reportPath);
            bsg_kscrashsentry_resumeThreads();
        }
        [self stopMeasuring];
        
        [[NSFileManager defaultManager] removeItemAtPath:crashReportFilePath error:nil];
    }];
    
    [[NSFileManager defaultManager] removeItemAtPath:recrashReportFilePath error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:stateFilePath error:nil];
}

@end
