//
//  BSG_KSMachHeadersTests.m
//  Tests
//
//  Created by Robin Macharg on 04/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "BSG_KSMachHeaders.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>

void bsg_mach_headers_add_image(const struct mach_header *mh, intptr_t slide);

const struct mach_header header1 = {
    .magic = MH_MAGIC,
    .cputype = 0,
    .cpusubtype = 0,
    .filetype = 0,
    .ncmds = 1,
    .sizeofcmds = 0,
    .flags = 0
};
const struct segment_command command1 = {
    LC_SEGMENT,0,SEG_TEXT,111,10,0,0,0,0,0,0
};

const struct mach_header header2 = {
    .magic = MH_MAGIC,
    .cputype = 0,
    .cpusubtype = 0,
    .filetype = 0,
    .ncmds = 1,
    .sizeofcmds = 0,
    .flags = 0
};
const struct segment_command command2 = {
    LC_SEGMENT,0,SEG_TEXT,222,10,0,0,0,0,0,0
};

@interface BSG_KSMachHeadersTests : XCTestCase
@end

@implementation BSG_KSMachHeadersTests

- (void)testAddRemoveHeaders {
    
    bsg_mach_headers_initialize();
    
    bsg_mach_headers_add_image(&header1, 0);
    
    BSG_Mach_Header_Info *listTail;
    
    listTail = bsg_mach_headers_get_images();
    XCTAssertEqual(listTail->imageVmAddr, 111);
    XCTAssert(listTail->unloaded == FALSE);
    
    bsg_mach_headers_add_image(&header2, 0);

    listTail = bsg_mach_headers_get_images();
    XCTAssertEqual(listTail->imageVmAddr, 111);
    XCTAssert(listTail->unloaded == FALSE);
    XCTAssertEqual(listTail->next->imageVmAddr, 222);
    XCTAssert(listTail->next->unloaded == FALSE);

    bsg_mach_headers_remove_image(&header1, 0);
    
    listTail = bsg_mach_headers_get_images();
    XCTAssertEqual(listTail->imageVmAddr, 111);
    XCTAssert(listTail->unloaded == TRUE);
    XCTAssertEqual(listTail->next->imageVmAddr, 222);
    XCTAssert(listTail->next->unloaded == FALSE);

    bsg_mach_headers_remove_image(&header2, 0);
    
    listTail = bsg_mach_headers_get_images();
    XCTAssertEqual(listTail->imageVmAddr, 111);
    XCTAssert(listTail->unloaded == TRUE);
    XCTAssertEqual(listTail->next->imageVmAddr, 222);
    XCTAssert(listTail->next->unloaded == TRUE);
    
}

- (void)testFindImageAtAddress {
    bsg_mach_headers_initialize();
    
    bsg_mach_headers_add_image(&header1, 0);
    bsg_mach_headers_add_image(&header2, 0);
    
    BSG_Mach_Header_Info *item;
    item = bsg_mach_headers_image_at_address(&header1);
    XCTAssertEqual(item->imageVmAddr, 111);
    
    item = bsg_mach_headers_image_at_address(&header2);
    XCTAssertEqual(item->imageVmAddr, 222);
}

- (void) testGetImageNameNULL
{
    BSG_Mach_Header_Info *img = bsg_mach_headers_image_named(NULL, false);
    XCTAssertTrue(img == NULL);
}

- (void)testMainImage {
    bsg_mach_headers_initialize();

    XCTAssert(bsg_mach_headers_get_main_image() != NULL);
}

- (void)testImageAtAddress {
    bsg_mach_headers_initialize();
    
    for (NSNumber *number in NSThread.callStackReturnAddresses) {
        uintptr_t address = number.unsignedIntegerValue;
        BSG_Mach_Header_Info *image = bsg_mach_headers_image_at_address(address);
        struct dl_info dlinfo = {0}; dladdr(address, &dlinfo);
        if (dlinfo.dli_fbase) {
            // If dladdr was able to locate the image, so should bsg_mach_headers_image_at_address
            XCTAssertEqual(image->header, dlinfo.dli_fbase);
            XCTAssertEqual(image->imageVmAddr + image->slide, (uint64_t)dlinfo.dli_fbase);
            XCTAssertEqual(image->name, dlinfo.dli_fname);
            XCTAssertFalse(image->unloaded);
        } else {
            XCTAssertEqual(image, NULL);
        }
    }
    
    XCTAssertEqual(bsg_mach_headers_image_at_address(0x0000000000000000), NULL);
    XCTAssertEqual(bsg_mach_headers_image_at_address(0x0000000000001000), NULL);
    XCTAssertEqual(bsg_mach_headers_image_at_address(0x7FFFFFFFFFFFFFFF), NULL);
}

@end
