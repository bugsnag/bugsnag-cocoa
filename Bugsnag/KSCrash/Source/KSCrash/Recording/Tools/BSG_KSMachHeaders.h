//
//  BSG_KSMachHeaders.h
//  Bugsnag
//
//  Created by Robin Macharg on 04/05/2020.
//  Current implementation created by Alex Cohen on 30/08/2026.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#ifndef BSG_KSMachHeaders_h
#define BSG_KSMachHeaders_h

#include <stdbool.h>
#include <stdint.h>

struct dyld_image_info;
struct mach_header;

/** An image entry supplied by dyld. */
typedef struct dyld_image_info BSG_Dyld_Image_Info;

/** Information required to symbolicate an address and describe its binary
 * image. */
typedef struct bsg_mach_image {
    /// The mach_header or mach_header_64.
    ///
    /// This is also the address where the __TEXT segment was loaded by dyld,
    /// including its slide.
    const struct mach_header *header;

    /// The vmaddr specified for the __TEXT segment.
    uint64_t imageVmAddr;

    /// The vmsize of the __TEXT segment.
    uint64_t imageSize;

    /// The image UUID used to identify its associated dSYM.
    const uint8_t *uuid;

    /// The pathname of the image.
    const char *name;

    /// The virtual memory address slide of the image.
    intptr_t slide;
} BSG_Mach_Header_Info;

// MARK: - Operations

/**
 * Initialize Mach image access and the bounded address lookup cache.
 * This MUST be called before calling anything else.
 */
void bsg_mach_headers_initialize(void);

/**
 * Return dyld's live array of loaded images and place its current count in
 * `count`. dyld itself is not included in this array.
 */
const BSG_Dyld_Image_Info *bsg_mach_headers_get_images(uint32_t *count);

/** Copy information about the process's main image into `image`. */
bool bsg_mach_headers_get_main_image(BSG_Mach_Header_Info *image);

/** Copy information about the image that contains Bugsnag into `image`. */
bool bsg_mach_headers_get_self_image(BSG_Mach_Header_Info *image);

/** Copy information about dyld into `image`. */
bool bsg_mach_headers_get_dyld_image(BSG_Mach_Header_Info *image);

/**
 * Populate `image` for a known header and path. This does not add the image to
 * the address lookup cache.
 */
bool bsg_mach_headers_image_for_header(const struct mach_header *header,
                                       const char *name,
                                       BSG_Mach_Header_Info *image);

/** Find the loaded binary image containing `address` and copy it into `image`.
 */
bool bsg_mach_headers_image_at_address(uintptr_t address,
                                       BSG_Mach_Header_Info *image);

/** Find a loaded image whose path matches `imageName`. */
bool bsg_mach_headers_image_named(const char *imageName, bool exactMatch,
                                  BSG_Mach_Header_Info *image);

/** Get the address of the first load command following a Mach header. */
uintptr_t bsg_mach_headers_first_cmd_after_header(const struct mach_header *header);

/** Get the __crash_info message of the specified image. */
const char *bsg_mach_headers_get_crash_info_message(const BSG_Mach_Header_Info *header);

/** Reset Mach header data for unit tests. */
void bsg_test_support_mach_headers_reset(void);

/** Return the number of address ranges currently cached, for unit tests. */
uint32_t bsg_test_support_mach_headers_cached_image_count(void);

#endif /* BSG_KSMachHeaders_h */
