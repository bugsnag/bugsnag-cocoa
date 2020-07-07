//
//  KSMachHeader_Tests.m
//  Tests
//
//  Created by Robin Macharg on 04/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "BSG_KSMachHeaders.h"
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

@interface KSMachHeader_Tests : XCTestCase
@end

@implementation KSMachHeader_Tests

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
    item = bsg_mach_headers_image_at_address(111);
    XCTAssertEqual(item->imageVmAddr, 111);
    
    item = bsg_mach_headers_image_at_address(222);
    XCTAssertEqual(item->imageVmAddr, 222);
}

- (void) testGetImageNameNULL
{
    BSG_Mach_Header_Info *img = bsg_mach_headers_image_named(NULL, false);
    XCTAssertTrue(img == NULL);
}

@end
