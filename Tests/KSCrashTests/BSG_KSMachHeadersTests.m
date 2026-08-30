//
//  BSG_KSMachHeadersTests.m
//  Tests
//
//  Created by Robin Macharg on 04/05/2020.
//  Current tests created by Alex Cohen on 30/08/2026.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "BSG_KSMachHeaders.h"
#import <Bugsnag/Bugsnag.h>
#import <XCTest/XCTest.h>
#import <dispatch/dispatch.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/dyld_images.h>
#import <objc/runtime.h>
#import <stdatomic.h>

@interface BSG_KSMachHeadersTests : XCTestCase
@end

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
            XCTAssertEqualObjects(@(image.name), @(dlinfo.dli_fname));
        }
    }
}

- (void)testImageLookupPopulatesCacheLazily {
    uint32_t countBefore = bsg_test_support_mach_headers_cached_image_count();
    uintptr_t address = (uintptr_t)class_getMethodImplementation(
        [NSObject class], @selector(description));
    BSG_Mach_Header_Info image;
    XCTAssertTrue(bsg_mach_headers_image_at_address(address, &image));
    XCTAssertGreaterThan(bsg_test_support_mach_headers_cached_image_count(),
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

@end
