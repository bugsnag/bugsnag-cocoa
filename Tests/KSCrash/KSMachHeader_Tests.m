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

const struct mach_header mh = {
    .magic = 1,
    .cputype = 1,
    .cpusubtype = 1,
    .filetype = 1,
    .ncmds = 1,
    .sizeofcmds = 1,
    .flags = 1
};

const BSG_Mach_Binary_Image_Info info1 = {
    .mh = &mh,
    .imageVmAddr = 12345,
    .imageSize = 6789,
    .uuid = (uint8_t *)123,
    .name = "header the first",
    .cputype = 42,
    .cpusubtype = 27
};

const BSG_Mach_Binary_Image_Info info2 = {
    .mh = &mh,
    .imageVmAddr = 12345,
    .imageSize = 6789,
    .uuid = (uint8_t *)123,
    .name = "header the second",
    .cputype = 42,
    .cpusubtype = 27
};

const BSG_Mach_Binary_Image_Info info3 = {
    .mh = &mh,
    .imageVmAddr = 12345,
    .imageSize = 6789,
    .uuid = (uint8_t *)123,
    .name = "header the third",
    .cputype = 42,
    .cpusubtype = 27
};

@interface KSMachHeader_Tests : XCTestCase
@end

@implementation KSMachHeader_Tests

- (void)testDynamicArray {
    BSG_Mach_Binary_Images headers;
    bsg_initialize_binary_images_array(&headers, 2);
    XCTAssertEqual(headers.size, 2);
    XCTAssertEqual(headers.used, 0);
    
    // Add
    bsg_add_mach_binary_image(&headers, info1);
    XCTAssertEqual(headers.size, 2);
    XCTAssertEqual(headers.used, 1);
    
    bsg_add_mach_binary_image(&headers, info2);
    XCTAssertEqual(headers.size, 2);
    XCTAssertEqual(headers.used, 2);

    // Expand - double size
    bsg_add_mach_binary_image(&headers, info3);
    XCTAssertEqual(headers.size, 4);
    XCTAssertEqual(headers.used, 3);
    
    // Delete - third will be copied
    bsg_remove_mach_binary_image(&headers, "header the first");
    XCTAssertEqual(headers.size, 4);
    XCTAssertEqual(headers.used, 2);

    XCTAssertEqual(strcmp(headers.contents[0].name, "header the third"), 0);
    XCTAssertEqual(strcmp(headers.contents[1].name, "header the second"), 0);
    XCTAssertEqual(headers.size, 4);
    
    // Nothing happens
    bsg_remove_mach_binary_image(&headers, "header the first");
    XCTAssertEqual(headers.size, 4);
    XCTAssertEqual(headers.used, 2);

    bsg_remove_mach_binary_image(&headers, "header the second");
    XCTAssertEqual(headers.size, 4);
    XCTAssertEqual(headers.used, 1);
    XCTAssertEqual(strcmp(headers.contents[0].name, "header the third"), 0);
    
    bsg_remove_mach_binary_image(&headers, "header the third");
    XCTAssertEqual(headers.size, 4);
    XCTAssertEqual(headers.used, 0);
    
    bsg_remove_mach_binary_image(&headers, "header the third");
    XCTAssertEqual(headers.size, 4);
    XCTAssertEqual(headers.used, 0);
    
    // Readd
    bsg_add_mach_binary_image(&headers, info1);
    XCTAssertEqual(headers.size, 4);
    XCTAssertEqual(headers.used, 1);
}

@end
