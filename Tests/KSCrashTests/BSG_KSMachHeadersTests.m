//
//  BSG_KSMachHeadersTests.m
//  Tests
//
//  Created by Robin Macharg on 04/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "BSG_KSMachHeaders.h"
#import <Bugsnag/Bugsnag.h>
#import <XCTest/XCTest.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>

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
    .cmd = LC_SEGMENT,
    .cmdsize = 0,
    .segname = SEG_TEXT,
    .vmaddr = 111,
    .vmsize = 10,
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
    .cmd = LC_SEGMENT,
    .cmdsize = 0,
    .segname = SEG_TEXT,
    .vmaddr = 222,
    .vmsize = 10,
};

@interface BSG_KSMachHeadersTests : XCTestCase
@end

@implementation BSG_KSMachHeadersTests

- (void)setUp {
    [super setUp];
    bsg_mach_headers_initialize();
}

static BSG_Mach_Header_Info *get_tail(BSG_Mach_Header_Info *head) {
    BSG_Mach_Header_Info *current = head;
    for (; current->next != NULL; current = current->next) {
    }
    return current;
}

- (void)testAddRemove {
    bsg_test_support_mach_headers_reset();

    bsg_test_support_mach_headers_add_image(&header1, 0);
    
    BSG_Mach_Header_Info *listTail = get_tail(bsg_mach_headers_get_images());
    XCTAssertEqual(listTail->imageVmAddr, command1.vmaddr);
    XCTAssert(listTail->unloaded == FALSE);
    
    bsg_test_support_mach_headers_add_image(&header2, 0);
    
    XCTAssertEqual(listTail->imageVmAddr, command1.vmaddr);
    XCTAssert(listTail->unloaded == FALSE);
    XCTAssertEqual(listTail->next->imageVmAddr, command2.vmaddr);
    XCTAssert(listTail->next->unloaded == FALSE);
    
    bsg_test_support_mach_headers_remove_image(&header1, 0);
    
    XCTAssertEqual(listTail->imageVmAddr, command1.vmaddr);
    XCTAssert(listTail->unloaded == TRUE);
    XCTAssertEqual(listTail->next->imageVmAddr, command2.vmaddr);
    XCTAssert(listTail->next->unloaded == FALSE);
    
    bsg_test_support_mach_headers_remove_image(&header2, 0);
    
    XCTAssertEqual(listTail->imageVmAddr, command1.vmaddr);
    XCTAssert(listTail->unloaded == TRUE);
    XCTAssertEqual(listTail->next->imageVmAddr, command2.vmaddr);
    XCTAssert(listTail->next->unloaded == TRUE);
}

- (void)testFindImageAtAddress {
    bsg_test_support_mach_headers_reset();

    bsg_test_support_mach_headers_add_image(&header1, 0);
    bsg_test_support_mach_headers_add_image(&header2, 0);
    
    BSG_Mach_Header_Info *item;
    item = bsg_mach_headers_image_at_address((uintptr_t)&header1);
    XCTAssertEqual(item->imageVmAddr, command1.vmaddr);
    
    item = bsg_mach_headers_image_at_address((uintptr_t)&header2);
    XCTAssertEqual(item->imageVmAddr, command2.vmaddr);
}

- (void) testGetImageNameNULL
{
    BSG_Mach_Header_Info *img = bsg_mach_headers_image_named(NULL, false);
    XCTAssertTrue(img == NULL);
}

- (void)testGetSelfImage {
    XCTAssertEqualObjects(@(bsg_mach_headers_get_self_image()->name),
                          @(class_getImageName([Bugsnag class])));
}

- (void)testMainImage {
    XCTAssertEqualObjects(@(bsg_mach_headers_get_main_image()->name),
                          NSBundle.mainBundle.executablePath);
}

- (void)testImageAtAddress {
    for (NSNumber *number in NSThread.callStackReturnAddresses) {
        uintptr_t address = number.unsignedIntegerValue;
        BSG_Mach_Header_Info *image = bsg_mach_headers_image_at_address(address);
        struct dl_info dlinfo = {0};
        if (dladdr((const void*)address, &dlinfo) != 0) {
            // If dladdr was able to locate the image, so should bsg_mach_headers_image_at_address
            XCTAssertEqual(image->header, dlinfo.dli_fbase);
            XCTAssertEqual(image->imageVmAddr + image->slide, (uint64_t)dlinfo.dli_fbase);
            XCTAssertEqual(image->name, dlinfo.dli_fname);
            XCTAssertFalse(image->unloaded);
        }
    }
    
    XCTAssertEqual(bsg_mach_headers_image_at_address(0x0000000000000000), NULL);
    XCTAssertEqual(bsg_mach_headers_image_at_address(0x0000000000001000), NULL);
    XCTAssertEqual(bsg_mach_headers_image_at_address(0x7FFFFFFFFFFFFFFF), NULL);
}

@end
