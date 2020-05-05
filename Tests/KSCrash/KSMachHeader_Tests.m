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
void bsg_initialize_binary_images_array(size_t initialSize);
void bsg_add_mach_binary_image(BSG_Mach_Binary_Image_Info element);
void bsg_remove_mach_binary_image(const char *element_name);
BSG_Mach_Binary_Images *bsg_get_mach_binary_images(void);

const struct mach_header mh = {
    .magic = 1,
    .cputype = 1,
    .cpusubtype = 1,
    .filetype = 1,
    .ncmds = 1,
    .sizeofcmds = 1,
    .flags = 1
};

const BSG_Mach_Binary_Image_Info info1 = {.mh = &mh, .imageVmAddr = 12345, .imageSize = 6789, .uuid = (uint8_t *)123, .name = "header the first", .cputype = 42, .cpusubtype = 27 };
const BSG_Mach_Binary_Image_Info info2 = {.mh = &mh, .imageVmAddr = 12345, .imageSize = 6789, .uuid = (uint8_t *)123, .name = "header the second", .cputype = 42, .cpusubtype = 27 };
const BSG_Mach_Binary_Image_Info info3 = {.mh = &mh, .imageVmAddr = 12345, .imageSize = 6789, .uuid = (uint8_t *)123, .name = "header the third", .cputype = 42, .cpusubtype = 27 };
const BSG_Mach_Binary_Image_Info info4 = {.mh = &mh, .imageVmAddr = 12345, .imageSize = 6789, .uuid = (uint8_t *)123, .name = "header the fourth", .cputype = 42, .cpusubtype = 27 };

@interface KSMachHeader_Tests : XCTestCase
@end

@implementation KSMachHeader_Tests

- (void)testDynamicArray {

    bsg_initialise_mach_binary_headers(2);
    BSG_Mach_Binary_Images *headers = bsg_get_mach_binary_images();
    XCTAssertEqual(headers->size, 2);
    XCTAssertEqual(headers->used, 0);
    
    // Add
    bsg_add_mach_binary_image(info1);
    XCTAssertEqual(headers->size, 2);
    XCTAssertEqual(headers->used, 1);
    
    bsg_add_mach_binary_image(info2);
    XCTAssertEqual(headers->size, 2);
    XCTAssertEqual(headers->used, 2);

    // Expand - double size
    bsg_add_mach_binary_image(info3);
    XCTAssertEqual(headers->size, 4);
    XCTAssertEqual(headers->used, 3);
    
    // Delete - third will be copied
    bsg_remove_mach_binary_image("header the first");
    XCTAssertEqual(headers->size, 4);
    XCTAssertEqual(headers->used, 2);

    XCTAssertEqual(strcmp(headers->contents[0].name, "header the third"), 0);
    XCTAssertEqual(strcmp(headers->contents[1].name, "header the second"), 0);
    XCTAssertEqual(headers->size, 4);
    
    // Nothing happens
    bsg_remove_mach_binary_image("header the first");
    XCTAssertEqual(headers->size, 4);
    XCTAssertEqual(headers->used, 2);

    bsg_remove_mach_binary_image("header the second");
    XCTAssertEqual(headers->size, 4);
    XCTAssertEqual(headers->used, 1);
    XCTAssertEqual(strcmp(headers->contents[0].name, "header the third"), 0);
    
    bsg_remove_mach_binary_image("header the third");
    XCTAssertEqual(headers->size, 4);
    XCTAssertEqual(headers->used, 0);
    
    bsg_remove_mach_binary_image("header the third");
    XCTAssertEqual(headers->size, 4);
    XCTAssertEqual(headers->used, 0);
    
    // Readd
    bsg_add_mach_binary_image(info1);
    XCTAssertEqual(headers->size, 4);
    XCTAssertEqual(headers->used, 1);
}

- (void)testRemoveLast1 {
    bsg_initialise_mach_binary_headers(2);
    BSG_Mach_Binary_Images *headers = bsg_get_mach_binary_images();
    bsg_add_mach_binary_image(info1);
    XCTAssertEqual(headers->size, 2);
    XCTAssertEqual(headers->used, 1);

    bsg_remove_mach_binary_image("header the first");
    XCTAssertEqual(headers->size, 2);
    XCTAssertEqual(headers->used, 0);
}

- (void)testRemoveLast2 {
    bsg_initialise_mach_binary_headers(2);
    BSG_Mach_Binary_Images *headers = bsg_get_mach_binary_images();
    bsg_add_mach_binary_image(info1);
    bsg_add_mach_binary_image(info2);
    XCTAssertEqual(headers->size, 2);
    XCTAssertEqual(headers->used, 2);

    bsg_remove_mach_binary_image("header the second");
    XCTAssertEqual(headers->size, 2);
    XCTAssertEqual(headers->used, 1);

    bsg_remove_mach_binary_image("header the first");
    XCTAssertEqual(headers->size, 2);
    XCTAssertEqual(headers->used, 0);
}

- (void)testRemoveLast3 {
    bsg_initialise_mach_binary_headers(2);
    BSG_Mach_Binary_Images *headers = bsg_get_mach_binary_images();
    
    bsg_add_mach_binary_image(info1);
    bsg_add_mach_binary_image(info2);
    bsg_add_mach_binary_image(info3);
    bsg_add_mach_binary_image(info4);
    XCTAssertEqual(headers->size, 4);
    XCTAssertEqual(headers->used, 4);

    bsg_remove_mach_binary_image("header the fourth");
    XCTAssertEqual(headers->size, 4);
    XCTAssertEqual(headers->used, 3);

    bsg_remove_mach_binary_image("header the first");
    XCTAssertEqual(headers->size, 4);
    XCTAssertEqual(headers->used, 2);

    bsg_remove_mach_binary_image("header the first");
    XCTAssertEqual(headers->size, 4);
    XCTAssertEqual(headers->used, 2);

    bsg_remove_mach_binary_image("header the third");
    XCTAssertEqual(headers->size, 4);
    XCTAssertEqual(headers->used, 1);
}

@end
