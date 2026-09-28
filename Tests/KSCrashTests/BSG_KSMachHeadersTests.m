//
//  BSG_KSMachHeadersTests.m
//  Tests
//
//  Created by Robin Macharg on 04/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "BSG_KSMachHeaders.h"
#import "BSG_Symbolicate.h"
#import <Bugsnag/Bugsnag.h>
#import <XCTest/XCTest.h>
#import <dispatch/dispatch.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/dyld_images.h>
#import <objc/runtime.h>
#import <stdatomic.h>
#import <mach/mach.h>

@interface BSG_KSMachHeadersTests : XCTestCase
@end

static bool initializationReadersFailedSafely;

static void readDuringInitialization(void) {
    __block atomic_bool safe = true;
    dispatch_apply(16, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0),
                   ^(__unused size_t index) {
        BSG_Mach_Header_Info image;
        uint32_t count = 99;
        if (bsg_mach_headers_get_images(&count) != NULL || count != 0 ||
            bsg_mach_headers_get_main_image(&image) ||
            bsg_mach_headers_get_self_image(&image) ||
            bsg_mach_headers_get_dyld_image(&image) ||
            bsg_mach_headers_image_at_address((uintptr_t)&readDuringInitialization, &image)) {
            atomic_store(&safe, false);
        }
    });
    initializationReadersFailedSafely = atomic_load(&safe);
}

@implementation BSG_KSMachHeadersTests

- (void)setUp {
    [super setUp];
    bsg_test_support_mach_headers_reset();
    bsg_mach_headers_initialize();
}

- (void)tearDown {
    bsg_test_support_mach_headers_reset();
    [super tearDown];
}

- (void)testInitializationDoesNotEnumerateEveryImage {
    uint32_t imageCount = 0;
    XCTAssertNotEqual(bsg_mach_headers_get_images(&imageCount), NULL);
    XCTAssertGreaterThan(imageCount, 0u);

    // Initialization caches only the main executable, dyld, and Bugsnag.
    uint32_t cachedImageCount =
        bsg_test_support_mach_headers_cached_image_count();
    XCTAssertLessThanOrEqual(cachedImageCount, 3u);
    if (imageCount > 3) {
        XCTAssertLessThan(cachedImageCount, imageCount);
    }
}

- (void)testGetImagesReturnsDyldsLiveImageArray {
    uint32_t imageCount = 0;
    const BSG_Dyld_Image_Info *images =
        bsg_mach_headers_get_images(&imageCount);

    XCTAssertNotEqual(images, NULL);
    XCTAssertGreaterThan(imageCount, 0u);

    const struct mach_header *mainHeader = _dyld_get_image_header(0);
    BOOL foundMainImage = NO;
    for (uint32_t i = 0; i < imageCount; i++) {
        if (images[i].imageLoadAddress == mainHeader) {
            foundMainImage = YES;
            break;
        }
    }
    XCTAssertTrue(foundMainImage);
}

- (void)testGetImageNameNULL {
    XCTAssertFalse(bsg_mach_headers_image_named(NULL, false, NULL));
}

- (void)testUnavailableDyldArrayReturnsZeroCount {
    struct dyld_all_image_infos info = {0};
    info.infoArrayCount = 17;
    bsg_test_support_mach_headers_set_dyld_info(&info);
    uint32_t count = 99;
    XCTAssertEqual(bsg_mach_headers_get_images(&count), NULL);
    XCTAssertEqual(count, 0u);
    BSG_Mach_Header_Info image;
    XCTAssertFalse(bsg_mach_headers_image_at_address(UINTPTR_MAX, &image));
    bsg_test_support_mach_headers_reset();
}

- (void)testReadersDoNotObservePartialInitialization {
    bsg_test_support_mach_headers_reset();
    initializationReadersFailedSafely = false;
    bsg_test_support_mach_headers_set_initialization_hook(readDuringInitialization);
    bsg_mach_headers_initialize();
    XCTAssertTrue(initializationReadersFailedSafely);
    BSG_Mach_Header_Info image;
    XCTAssertTrue(bsg_mach_headers_get_main_image(&image));
    XCTAssertTrue(bsg_mach_headers_get_self_image(&image));
}

- (void)testAllLoadedSharedCacheImagesResolve {
    uint32_t count = 0;
    const BSG_Dyld_Image_Info *images = bsg_mach_headers_get_images(&count);
    // On hosts with more than 64 shared-cache images this also covers the
    // full-cache fallback. Do not require a particular OS image count.
    for (uint32_t i = 0; i < count; i++) {
        const struct mach_header *header = images[i].imageLoadAddress;
        if (header == NULL || !(header->flags & MH_DYLIB_IN_CACHE)) {
            continue;
        }
        BSG_Mach_Header_Info image;
        XCTAssertTrue(bsg_mach_headers_image_at_address((uintptr_t)header, &image));
        XCTAssertEqual(image.header, header);
    }
}

- (void)testGetSelfImage {
    BSG_Mach_Header_Info image;
    XCTAssertTrue(bsg_mach_headers_get_self_image(&image));
    XCTAssertEqualObjects(@(image.name),
                          @(class_getImageName([Bugsnag class])));
}

- (void)testMainImage {
    BSG_Mach_Header_Info image;
    XCTAssertTrue(bsg_mach_headers_get_main_image(&image));
    XCTAssertEqualObjects(@(image.name), NSBundle.mainBundle.executablePath);
    XCTAssertEqual(image.header->filetype, MH_EXECUTE);
}

- (void)testDyldImage {
    BSG_Mach_Header_Info image;
    XCTAssertTrue(bsg_mach_headers_get_dyld_image(&image));
    XCTAssertNotEqual(image.header, NULL);
    XCTAssertNotEqual(image.name, NULL);
}

- (void)testImageNamed {
    BSG_Mach_Header_Info mainImage;
    XCTAssertTrue(bsg_mach_headers_get_main_image(&mainImage));

    BSG_Mach_Header_Info foundImage;
    XCTAssertTrue(
        bsg_mach_headers_image_named(mainImage.name, true, &foundImage));
    XCTAssertEqual(foundImage.header, mainImage.header);
}

- (void)testImageAtAddress {
    for (NSNumber *number in NSThread.callStackReturnAddresses) {
        uintptr_t address = number.unsignedIntegerValue;
        BSG_Mach_Header_Info image;
        struct dl_info dlinfo = {0};
        if (dladdr((const void *)address, &dlinfo) != 0) {
            XCTAssertTrue(bsg_mach_headers_image_at_address(address, &image));
            XCTAssertEqual(image.header, dlinfo.dli_fbase);
            XCTAssertEqual(image.imageVmAddr + image.slide,
                           (uint64_t)dlinfo.dli_fbase);
            NSString *imagePath =
                [@(image.name) stringByResolvingSymlinksInPath];
            NSString *dladdrPath =
                [@(dlinfo.dli_fname) stringByResolvingSymlinksInPath];
            XCTAssertEqualObjects(imagePath, dladdrPath);
        }
    }
}

- (void)testImageLookupDoesNotGrowStartupCache {
    uint32_t countBefore = bsg_test_support_mach_headers_cached_image_count();
    uintptr_t address = (uintptr_t)class_getMethodImplementation(
        [NSObject class], @selector(description));
    BSG_Mach_Header_Info image;
    XCTAssertTrue(bsg_mach_headers_image_at_address(address, &image));
    XCTAssertEqual(bsg_test_support_mach_headers_cached_image_count(),
                   countBefore);
}

- (void)testConcurrentImageLookups {
    uintptr_t address = (uintptr_t)class_getMethodImplementation(
        [NSObject class], @selector(description));
    __block atomic_bool allLookupsSucceeded = true;
    dispatch_apply(64, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0),
                   ^(__unused size_t index) {
                     BSG_Mach_Header_Info image;
                     if (!bsg_mach_headers_image_at_address(address, &image)) {
                         atomic_store(&allLookupsSucceeded, false);
                     }
                   });
    XCTAssertTrue(atomic_load(&allLookupsSucceeded));
}

- (void)testInvalidAddressesDoNotMatchAnImage {
    BSG_Mach_Header_Info image;
    XCTAssertFalse(bsg_mach_headers_image_at_address(0, &image));
    XCTAssertFalse(bsg_mach_headers_image_at_address(0x1000, &image));
    XCTAssertFalse(bsg_mach_headers_image_at_address(UINTPTR_MAX, &image));
}

- (void)testImageMetadataSurvivesUnmapping {
    vm_address_t address = 0;
    XCTAssertEqual(vm_allocate(mach_task_self(), &address, vm_page_size, VM_FLAGS_ANYWHERE), KERN_SUCCESS);
    if (!address) return;
    struct mach_header_64 *header = (void *)address;
    header->magic = MH_MAGIC_64;
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
    char *path = (void *)(uuid + 1);
    strcpy(path, "/test/unloadable.dylib");
    BSG_Mach_Header_Info image;
    BOOL found = bsg_mach_headers_image_for_header((void *)header, path, &image);
    XCTAssertTrue(found);
    BSG_Mach_Header_Info copy;
    if (found) bsg_mach_headers_copy_image(&copy, &image);
    XCTAssertEqual(vm_deallocate(mach_task_self(), address, vm_page_size), KERN_SUCCESS);
    if (found) {
        XCTAssertEqualObjects(@(image.name), @"/test/unloadable.dylib");
        XCTAssertEqual(image.uuid[0], 0x42);
        memset(&image, 0, sizeof(image));
        XCTAssertEqualObjects(@(copy.name), @"/test/unloadable.dylib");
        XCTAssertEqual(copy.uuid[15], 0x42);
    }
    XCTAssertFalse(bsg_mach_headers_image_for_header((void *)address, "/test/unloadable.dylib", &image));
    struct bsg_symbolicate_result result;
    bsg_symbolicate(address, &result);
    XCTAssertEqual(result.image_header, NULL);
}

- (void)testUnreadableDyldEntryFailsSafely {
    vm_address_t address = 0;
    XCTAssertEqual(vm_allocate(mach_task_self(), &address, vm_page_size, VM_FLAGS_ANYWHERE), KERN_SUCCESS);
    if (!address) return;
    XCTAssertEqual(vm_deallocate(mach_task_self(), address, vm_page_size), KERN_SUCCESS);
    BSG_Dyld_Image_Info entry;
    XCTAssertFalse(bsg_mach_headers_read_image_entry((void *)address, 0, &entry));
}

@end
