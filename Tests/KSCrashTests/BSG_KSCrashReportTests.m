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
#import "BSG_KSJSONCodec.h"
#import <mach-o/dyld_images.h>
#import <mach-o/loader.h>
#import "BSGDefines.h"

#import <execinfo.h>

// Exercise the real trace serializer with a writer that withdraws dyld's
// array and unmaps the fixture between frame and binary-image serialization.
extern void bsg_kscrw_i_prepareReportWriter(BSG_KSCrashReportWriter *, BSG_KSJSONEncodeContext *);
extern void bsg_kscrw_i_writeTraceInfo(const BSG_KSCrash_Context *, const BSG_KSCrashReportWriter *);

typedef struct {
    __unsafe_unretained NSMutableData *data;
    struct dyld_all_image_infos *dyldInfo;
    vm_address_t mapping;
    vm_size_t mappingSize;
    kern_return_t unmapResult;
    void (*beginArray)(const BSG_KSCrashReportWriter *, const char *);
} ReportImageFixture;

static int appendFixtureJSON(const char *data, size_t length, void *userData) {
    ReportImageFixture *fixture = userData;
    [fixture->data appendBytes:data length:length];
    return BSG_KSJSON_OK;
}

static void beginFixtureArray(const BSG_KSCrashReportWriter *writer, const char *key) {
    BSG_KSJSONEncodeContext *json = writer->context;
    ReportImageFixture *fixture = json->userData;
    if (key && strcmp(key, "binary_images") == 0) {
        fixture->dyldInfo->infoArray = NULL;
        fixture->unmapResult = vm_deallocate(mach_task_self(), fixture->mapping, fixture->mappingSize);
        if (fixture->unmapResult == KERN_SUCCESS) fixture->mapping = 0;
    }
    fixture->beginArray(writer, key);
}

@interface BSG_KSCrashReportTests : XCTestCase

@end

@implementation BSG_KSCrashReportTests

- (void)testBinaryImages {
    [self checkBinaryImagesWithUnavailableArray:NO];
}

- (void)testBinaryImagesWithUnavailableArray {
    [self checkBinaryImagesWithUnavailableArray:YES];
}

- (void)testReportRetainsUnloadedImageMetadata {
    [self checkReportRetainsImagesAfterUnmapping:1];
}

- (void)testReportRetainsMultipleBlocksOfImageMetadata {
    [self checkReportRetainsImagesAfterUnmapping:10];
}

- (void)testReportRetainsMoreThan512ImageMetadataEntries {
    [self checkReportRetainsImagesAfterUnmapping:513];
}

- (void)checkReportRetainsImagesAfterUnmapping:(uint32_t)count {
    bsg_mach_headers_initialize();
    vm_address_t mapping = 0;
    vm_size_t size = (vm_size_t)count * vm_page_size;
    XCTAssertEqual(vm_allocate(mach_task_self(), &mapping, size, VM_FLAGS_ANYWHERE), KERN_SUCCESS);
    if (!mapping) return;
    NSMutableData *entriesData = [NSMutableData dataWithLength:count * sizeof(struct dyld_image_info)];
    struct dyld_image_info *entries = entriesData.mutableBytes;
    // Duplicate each frame to verify that metadata is retained only once.
    NSMutableData *framesData = [NSMutableData dataWithLength:2 * count * sizeof(uintptr_t)];
    uintptr_t *frames = framesData.mutableBytes;
    NSMutableDictionary *expected = [NSMutableDictionary dictionary];
    for (uint32_t i = 0; i < count; i++) {
        struct mach_header_64 *header = (void *)(mapping + i * vm_page_size);
        header->magic = MH_MAGIC_64;
        header->filetype = MH_DYLIB;
        header->ncmds = 2;
        header->sizeofcmds = sizeof(struct segment_command_64) + sizeof(struct uuid_command);
        struct segment_command_64 *segment = (void *)(header + 1);
        segment->cmd = LC_SEGMENT_64;
        segment->cmdsize = sizeof(*segment);
        strcpy(segment->segname, SEG_TEXT);
        segment->vmsize = vm_page_size;
        struct uuid_command *uuid = (void *)(segment + 1);
        uuid->cmd = LC_UUID;
        uuid->cmdsize = sizeof(*uuid);
        memset(uuid->uuid, 0x42, sizeof(uuid->uuid));
        memcpy(uuid->uuid, &i, sizeof(i));
        char *name = (void *)(uuid + 1);
        strcpy(name, "/test/non-shared-unloadable.dylib");
        entries[i].imageLoadAddress = (void *)header;
        entries[i].imageFilePath = name;
        frames[2 * i] = frames[2 * i + 1] = (uintptr_t)header + 512;
        expected[@((uintptr_t)header)] = [[NSUUID alloc] initWithUUIDBytes:uuid->uuid].UUIDString;
    }
    struct dyld_all_image_infos dyldInfo = {0};
    dyldInfo.infoArray = entries;
    dyldInfo.infoArrayCount = count;
    bsg_test_support_mach_headers_set_dyld_info(&dyldInfo);

    BSG_KSCrash_Context context;
    memset(&context, 0, sizeof(context));
    thread_t thread = bsg_ksmachthread_self();
    context.crash.crashType = BSG_KSCrashTypeNSException;
    context.crash.offendingThread = thread;
    context.crash.allThreads = &thread;
    context.crash.allThreadsCount = 1;
    context.crash.NSException.name = "ReportImageFixture";
    context.crash.stackTrace = frames;
    context.crash.stackTraceLength = 2 * count;
    NSMutableData *data = [NSMutableData data];
    ReportImageFixture fixture = {.data = data, .dyldInfo = &dyldInfo,
        .mapping = mapping, .mappingSize = size, .unmapResult = KERN_FAILURE};
    BSG_KSJSONEncodeContext json;
    bsg_ksjsonbeginEncode(&json, false, appendFixtureJSON, &fixture);
    BSG_KSCrashReportWriter writer;
    bsg_kscrw_i_prepareReportWriter(&writer, &json);
    fixture.beginArray = writer.beginArray;
    writer.beginArray = beginFixtureArray;
    writer.beginObject(&writer, NULL);
    bsg_kscrw_i_writeTraceInfo(&context, &writer);
    writer.endContainer(&writer);
    bsg_ksjsonendEncode(&json);
    if (fixture.mapping) vm_deallocate(mach_task_self(), fixture.mapping, size);
    bsg_test_support_mach_headers_reset();
    bsg_mach_headers_initialize();

    XCTAssertEqual(fixture.unmapResult, KERN_SUCCESS);
    NSDictionary *report = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    XCTAssertNotNil(report);
    NSArray *images = report[@"binary_images"];
    XCTAssertEqual(images.count, count);
    NSMutableDictionary *actual = [NSMutableDictionary dictionary];
    for (NSDictionary *image in images) {
        actual[image[@"image_addr"]] = [image[@"uuid"] uppercaseString];
        XCTAssertEqualObjects(image[@"name"], @"/test/non-shared-unloadable.dylib");
    }
    XCTAssertEqualObjects(actual, expected);
    NSArray *backtrace = [report valueForKeyPath:@"crash.threads"][0][@"backtrace"][@"contents"];
    XCTAssertEqual(backtrace.count, 2 * count);
    for (NSDictionary *frame in backtrace) {
        XCTAssertNotNil(frame[@"object_addr"]);
        XCTAssertNotNil(actual[frame[@"object_addr"]]);
    }
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
