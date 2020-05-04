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

/**
 * An encapsulation of the Mach header - either 64 or 32 bit, along with some additional information required for
 * detailing a crash report's binary images.
 */
typedef struct {
    const struct mach_header *mh;      /* The mach_header - 32 or 64 bit */
    uint64_t imageVmAddr;
    uint64_t imageSize;
    uint8_t *uuid;
    const char* name;
    cpu_type_t cputype;          /* cpu specifier */
    cpu_subtype_t cpusubtype;    /* machine specifier */
} BSG_Mach_Binary_Image_Info;

/**
 * MARK: - A Dynamic array container
 * See: https://stackoverflow.com/a/3536261/2431627
 */
typedef struct {
    size_t used;
    size_t size;
    BSG_Mach_Binary_Image_Info *contents;
} BSG_Mach_Binary_Images;

static BSG_Mach_Binary_Images bsg_mach_binary_images;

static os_unfair_lock bsg_mach_binary_images_access_lock = OS_UNFAIR_LOCK_INIT;

void bsg_initialize_binary_images_array(BSG_Mach_Binary_Images *array, size_t initialSize);
void bsg_add_mach_binary_image(BSG_Mach_Binary_Images *array, BSG_Mach_Binary_Image_Info element);
void bsg_remove_mach_binary_image(BSG_Mach_Binary_Images *array, const char *element_name);
void bsg_free_binary_images_array(BSG_Mach_Binary_Images *array);
BSG_Mach_Binary_Images *bsg_get_mach_binary_images(void);

/**
 * Called when a binary image is loaded.
 */
void bsg_mach_binary_image_added(const struct mach_header *mh, intptr_t slide);

/**
 * Called when a binary image is unloaded.
 */
void bsg_mach_binary_image_removed(const struct mach_header *mh, intptr_t slide);

/**
 * Create an empty, mutable NSArray to hold Mach header info
 */
void bsg_initialise_mach_binary_headers(void);

#endif /* BSG_KSMachHeaders_h */
