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
#import "BSG_KSMachHeaders.h"
#import <mach-o/dyld_images.h>
#import <mach-o/loader.h>
#import "BSGDefines.h"

#import <execinfo.h>

@interface BSG_KSCrashReportTests : XCTestCase

@end

@implementation BSG_KSCrashReportTests

- (void)testBinaryImages {
    [self checkBinaryImagesWithUnavailableArray:NO];
}

- (void)testBinaryImagesWithUnavailableArray {
    [self checkBinaryImagesWithUnavailableArray:YES];
}

- (void)checkBinaryImagesWithUnavailableArray:(BOOL)unavailable {
    NSString *crashReportFilePath = [self temporaryFile:@"crash_report.json"];
    NSString *recrashReportFilePath = [self temporaryFile:@"recrash_report"];
    NSString *stateFilePath = [self temporaryFile:@"kscrash_state"];
    NSString *crashID = [[NSUUID UUID] UUIDString];
    
    bsg_kscrash_init();
    bsg_kscrash_setHandlingCrashTypes(BSG_KSCrashTypeNSException);
    bsg_kscrash_install([crashReportFilePath fileSystemRepresentation],
                        [recrashReportFilePath fileSystemRepresentation],
                        [stateFilePath fileSystemRepresentation],
                        [crashID UTF8String]);
    
    uintptr_t stackTrace[500];
    
    BSG_KSCrash_Context *context = crashContext();
    context->crash.crashType = BSG_KSCrashTypeNSException;
    context->crash.offendingThread = bsg_ksmachthread_self();
    context->crash.registersAreValid = false;
    context->crash.NSException.name = "BSG_KSCrashReportTests";
    context->crash.crashReason = "testBinaryImages";
    context->crash.stackTrace = stackTrace;
    context->crash.stackTraceLength = backtrace((void **)stackTrace, sizeof(stackTrace) / sizeof(*stackTrace));
    context->crash.threadTracingEnabled = false;
    
    const char *reportPath = [crashReportFilePath fileSystemRepresentation];
    struct dyld_all_image_infos info = {0};
    NSMutableDictionary *expectedUUIDs = [NSMutableDictionary dictionary];
    if (unavailable) {
        // Use startup-cached images. NSLog's image is not necessarily in the
        // dyld shared cache on Simulator, so looking it up need not retain it.
        BSG_Mach_Header_Info mainImage;
        BOOL hasMainImage = bsg_mach_headers_get_main_image(&mainImage);
        XCTAssertTrue(hasMainImage);
        if (!hasMainImage) return;
        stackTrace[0] = (uintptr_t)&bsg_mach_headers_initialize;
        // A synthetic address inside the main image is sufficient here: this
        // test checks binary-image metadata, not function-name resolution.
        // Stay inside the image after the reporter adjusts a return address
        // back to its calling instruction.
        stackTrace[1] = (uintptr_t)mainImage.header + sizeof(struct mach_header_64);
        context->crash.stackTraceLength = 2;
        for (NSUInteger i = 0; i < 2; i++) {
            BSG_Mach_Header_Info image;
            BOOL found = bsg_mach_headers_image_at_address(stackTrace[i], &image);
            XCTAssertTrue(found);
            if (!found) return;
            XCTAssertNotEqual(image.uuid, NULL);
            BOOL cached = NO;
            BSG_Mach_Header_Info cachedImage;
            for (uint32_t index = 0; bsg_mach_headers_get_cached_image(index, &cachedImage); index++) {
                if (cachedImage.header == image.header) {
                    cached = YES;
                    break;
                }
            }
            XCTAssertTrue(cached, @"The fixture image must be cached before withdrawing dyld's array");
            if (image.uuid != NULL) {
                expectedUUIDs[@((uintptr_t)image.header)] =
                    [[[NSUUID alloc] initWithUUIDBytes:image.uuid] UUIDString];
            }
        }
        info.infoArrayCount = 17;
        bsg_test_support_mach_headers_set_dyld_info(&info);
    }
#if BSG_HAVE_MACH_THREADS
    bsg_kscrashsentry_suspendThreads();
#else
    // Match the NSException handler on watchOS: collect threads even though
    // suspension is unavailable, so the reporter can write the supplied stack.
    context->crash.allThreadsCount = 0;
    context->crash.allThreads = bsg_ksmachgetAllThreads(&context->crash.allThreadsCount);
    memset(context->crash.allThreadRunStates, 0, sizeof(context->crash.allThreadRunStates));
#endif
    bsg_kscrashreport_writeStandardReport(context, reportPath);
#if BSG_HAVE_MACH_THREADS
    bsg_kscrashsentry_resumeThreads();
#else
    if (context->crash.allThreads != NULL) {
        bsg_ksmachfreeThreads(context->crash.allThreads, context->crash.allThreadsCount);
    }
    context->crash.allThreads = NULL;
    context->crash.allThreadsCount = 0;
#endif
    if (unavailable) {
        bsg_test_support_mach_headers_reset();
        bsg_mach_headers_initialize();
    }
    
    NSDictionary *report = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:crashReportFilePath] options:0 error:nil];
    
    NSArray *binaryImages = [report valueForKeyPath:@"binary_images"];
    XCTAssert([binaryImages isKindOfClass:[NSArray class]]);
    if (unavailable) {
        XCTAssertNotNil(report);
        NSMutableDictionary *actualUUIDs = [NSMutableDictionary dictionary];
        for (NSDictionary *image in binaryImages) {
            XCTAssertNotNil(image[@"name"]);
            XCTAssertNotNil(image[@"uuid"]);
            if (image[@"uuid"] != nil) {
                actualUUIDs[image[@"image_addr"]] = [image[@"uuid"] uppercaseString];
            }
        }
        XCTAssertEqualObjects(actualUUIDs, expectedUUIDs);
        XCTAssertEqual(binaryImages.count, expectedUUIDs.count); // No duplicates.
    }
    NSSet *binaryImageAddrs = [NSSet setWithArray:[binaryImages valueForKeyPath:@"image_addr"]];
    
    NSMutableSet *backtraceImageAddrs = [NSMutableSet setWithArray:[report valueForKeyPath:@"crash.threads.@distinctUnionOfArrays.backtrace.contents.object_addr"]];
    [backtraceImageAddrs removeObject:[NSNull null]];
    
    XCTAssertEqualObjects(binaryImageAddrs, backtraceImageAddrs);
}

- (void)testWriteStandardReportPerformance {
    NSString *crashReportFilePath = [self temporaryFile:@"crash_report"];
    NSString *recrashReportFilePath = [self temporaryFile:@"recrash_report"];
    NSString *stateFilePath = [self temporaryFile:@"kscrash_state"];
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
        stackTrace[i] = (uintptr_t)NSLog;
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
#if BSG_HAVE_MACH_THREADS
            bsg_kscrashsentry_suspendThreads();
#endif
            bsg_kscrashreport_writeStandardReport(context, reportPath);
#if BSG_HAVE_MACH_THREADS
            bsg_kscrashsentry_resumeThreads();
#endif
        }
        [self stopMeasuring];
        
        NSDictionary *report = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:crashReportFilePath] options:0 error:nil];
        XCTAssert([report isKindOfClass:[NSDictionary class]], @"%@", report);
        [[NSFileManager defaultManager] removeItemAtPath:crashReportFilePath error:nil];
    }];
}

- (NSString *)temporaryFile:(NSString *)fileName {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    [self addTeardownBlock:^{
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }];
    return path;
}

@end
