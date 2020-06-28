//
//  BSG_KSMachHeaders.h
//  Bugsnag
//
//  Created by Robin Macharg on 04/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#ifndef BSG_KSMachHeaders_h
#define BSG_KSMachHeaders_h

#import <mach/machine.h>
#import <os/lock.h>
#import <libkern/OSAtomic.h>

/**
 * An encapsulation of the Mach header - either 64 or 32 bit, along with some additional information required for
 * detailing a crash report's binary images.
 */
typedef struct {
    const struct mach_header *header; /* The mach_header - 32 or 64 bit */
    uint64_t imageVmAddr;
    uint64_t imageSize;
    uint8_t *uuid;
    const char* name;
    intptr_t slide;
} BSG_Mach_Binary_Image_Info;

// MARK: - Replicate the DYLD API

/**
 * Returns the current number of images mapped in by dyld.
 */
uint32_t bsg_dyld_image_count(void);

/**
* Returns the binary image information at the specified index.
*/
BSG_Mach_Binary_Image_Info *bsg_dyld_get_image_info(uint32_t imageIndex);

/**
 * Called when a binary image is loaded.
 */
void bsg_mach_binary_image_added(const struct mach_header *mh, intptr_t slide);

/**
 * Called when a binary image is unloaded.
 */
void bsg_mach_binary_image_removed(const struct mach_header *mh, intptr_t slide);

/**
 * Create an empty array with initial capacity to hold Mach header info.
 */
void bsg_initialise_mach_binary_headers(uint32_t initialSize);

/** Get the image index that the specified address is part of.
*
* @param address The address to examine.
* @return The index of the image it is part of, or UINT_MAX if none was found.
*/
BSG_Mach_Binary_Image_Info *bsg_mach_image_at_address(const uintptr_t address);


/** Find a loaded binary image with the specified name.
 *
 * @param imageName The image name to look for.
 *
 * @param exactMatch If true, look for an exact match instead of a partial one.
 *
 * @return the index of the matched image, or UINT32_MAX if not found.
 */
BSG_Mach_Binary_Image_Info *bsg_mach_image_named(const char *const imageName, bool exactMatch);

/** Get the address of the first command following a header (which will be of
 * type struct load_command).
 *
 * @param header The header to get commands for.
 *
 * @return The address of the first command, or NULL if none was found (which
 *         should not happen unless the header or image is corrupt).
 */
uintptr_t bsg_mach_image_first_cmd_after_header(const struct mach_header *header);

/** Get the segment base address of the specified image.
 *
 * This is required for any symtab command offsets.
 *
 * @param header The header to get commands for.
 * @return The image's base address, or 0 if none was found.
 */
uintptr_t bsg_mach_image_base_of_image_index(const struct mach_header *header);

#endif /* BSG_KSMachHeaders_h */
