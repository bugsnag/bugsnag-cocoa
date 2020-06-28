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

// Private methods
void bsg_add_mach_binary_image(BSG_Mach_Binary_Image_Info element);
void bsg_remove_mach_binary_image(uint64_t imageVmAddr);

const struct mach_header mh = {
    .magic = 1,
    .cputype = 42,
    .cpusubtype = 27,
    .filetype = 1,
    .ncmds = 1,
    .sizeofcmds = 1,
    .flags = 1
};

const BSG_Mach_Binary_Image_Info info1 = {.header = &mh, .imageVmAddr = 12345, .imageSize = 6789, .uuid = (uint8_t *)123, .name = "header the first",  .slide = 123 };
const BSG_Mach_Binary_Image_Info info2 = {.header = &mh, .imageVmAddr = 23456, .imageSize = 6789, .uuid = (uint8_t *)123, .name = "header the second", .slide = 1234 };
const BSG_Mach_Binary_Image_Info info3 = {.header = &mh, .imageVmAddr = 34567, .imageSize = 6789, .uuid = (uint8_t *)123, .name = "header the third",  .slide = 12345 };
const BSG_Mach_Binary_Image_Info info4 = {.header = &mh, .imageVmAddr = 45678, .imageSize = 6789, .uuid = (uint8_t *)123, .name = "header the fourth", .slide = 123456 };

@interface KSMachHeader_Tests : XCTestCase
@end

@implementation KSMachHeader_Tests

- (void)testDynamicArray {

    bsg_initialise_mach_binary_headers(2);
    XCTAssertEqual(bsg_dyld_image_count(), 0);
    
    // Add
    bsg_add_mach_binary_image(info1);
    XCTAssertEqual(bsg_dyld_image_count(), 1);
    
    bsg_add_mach_binary_image(info2);
    XCTAssertEqual(bsg_dyld_image_count(), 2);

    // Expand - double size
    bsg_add_mach_binary_image(info3);
    XCTAssertEqual(bsg_dyld_image_count(), 3);
    
    // Delete - third will be copied
    bsg_remove_mach_binary_image(12345);
    XCTAssertEqual(bsg_dyld_image_count(), 2);

    XCTAssertEqual(strcmp(bsg_dyld_get_image_info(0)->name, "header the third"), 0);
    XCTAssertEqual(strcmp(bsg_dyld_get_image_info(1)->name, "header the second"), 0);
    
    // Nothing happens
    bsg_remove_mach_binary_image(12345);
    XCTAssertEqual(bsg_dyld_image_count(), 2);

    bsg_remove_mach_binary_image(23456);
    XCTAssertEqual(bsg_dyld_image_count(), 1);
    XCTAssertEqual(strcmp(bsg_dyld_get_image_info(0)->name, "header the third"), 0);
    
    bsg_remove_mach_binary_image(34567);
    XCTAssertEqual(bsg_dyld_image_count(), 0);
    
    bsg_remove_mach_binary_image(34567);
    XCTAssertEqual(bsg_dyld_image_count(), 0);
    
    // Readd
    bsg_add_mach_binary_image(info1);
    XCTAssertEqual(bsg_dyld_image_count(), 1);
}

- (void)testRemoveLast1 {
    bsg_initialise_mach_binary_headers(2);
    bsg_add_mach_binary_image(info1);
    XCTAssertEqual(bsg_dyld_image_count(), 1);

    bsg_remove_mach_binary_image(12345);
    XCTAssertEqual(bsg_dyld_image_count(), 0);
}

- (void)testRemoveLast2 {
    bsg_initialise_mach_binary_headers(2);
    bsg_add_mach_binary_image(info1);
    bsg_add_mach_binary_image(info2);
    XCTAssertEqual(bsg_dyld_image_count(), 2);

    bsg_remove_mach_binary_image(23456);
    XCTAssertEqual(bsg_dyld_image_count(), 1);

    bsg_remove_mach_binary_image(12345);
    XCTAssertEqual(bsg_dyld_image_count(), 0);
}

- (void)testRemoveLast3 {
    bsg_initialise_mach_binary_headers(2);
    
    bsg_add_mach_binary_image(info1);
    bsg_add_mach_binary_image(info2);
    bsg_add_mach_binary_image(info3);
    bsg_add_mach_binary_image(info4);
    XCTAssertEqual(bsg_dyld_image_count(), 4);

    bsg_remove_mach_binary_image(45678);
    XCTAssertEqual(bsg_dyld_image_count(), 3);

    bsg_remove_mach_binary_image(12345);
    XCTAssertEqual(bsg_dyld_image_count(), 2);

    bsg_remove_mach_binary_image(12345);
    XCTAssertEqual(bsg_dyld_image_count(), 2);

    bsg_remove_mach_binary_image(34567);
    XCTAssertEqual(bsg_dyld_image_count(), 1);
}

// Test out-of-bounds behaviour of the replicated dyld API
- (void)testBSGDYLDAPI {
    bsg_initialise_mach_binary_headers(2);
    
    bsg_add_mach_binary_image(info1);
    bsg_add_mach_binary_image(info2);
    XCTAssertEqual(bsg_dyld_image_count(), 2);
    
    XCTAssertTrue(bsg_dyld_get_image_info(2) == NULL);
    XCTAssertTrue(bsg_dyld_get_image_info(999) == NULL);
    
    XCTAssertEqual(bsg_dyld_get_image_info(0)->slide, 123);
    XCTAssertEqual(bsg_dyld_get_image_info(1)->slide, 1234);
    
    XCTAssertEqualObjects([NSString stringWithUTF8String:bsg_dyld_get_image_info(0)->name], @"header the first");
    XCTAssertEqualObjects([NSString stringWithUTF8String:bsg_dyld_get_image_info(1)->name], @"header the second");

    XCTAssertEqual(bsg_dyld_get_image_info(0)->header->filetype, 1);
    XCTAssertEqual(bsg_dyld_get_image_info(1)->header->filetype, 1);
    
    XCTAssertEqualObjects([NSString stringWithUTF8String:bsg_dyld_get_image_info(0)->name],  @"header the first");
    XCTAssertEqualObjects([NSString stringWithUTF8String:bsg_dyld_get_image_info(1)->name],  @"header the second");
}

- (void) testGetImageNameNULL
{
    BSG_Mach_Binary_Image_Info *img = bsg_mach_image_named(NULL, false);
    XCTAssertTrue(img == NULL);
}

@end
