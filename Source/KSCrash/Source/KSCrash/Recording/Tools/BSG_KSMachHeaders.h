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
    intptr_t slide;
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

/**
 * An OS-version-specific lock, used to synchronise access to the array of binary image info.
 *
 * os_unfair_lock is available from specific OS versions onwards:
 *     https://developer.apple.com/documentation/os/os_unfair_lock
 *
 * It deprecates OSSpinLock:
 *     https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/spinlock.3.html
 */
#if defined(__IPHONE_10_0) || defined(__MAC_10_12) || defined(__TVOS_10_0) || defined(__WATCHOS_3_0)
    #import <os/lock.h>
    static os_unfair_lock bsg_mach_binary_images_access_lock = OS_UNFAIR_LOCK_INIT;
    #define bsg_lock_mach_binary_image_access os_unfair_lock_lock
    #define bsg_unlock_mach_binary_image_access os_unfair_lock_unlock
#else
    #import <libkern/OSAtomic.h>
    static OSSpinLock bsg_mach_binary_images_access_lock = OS_SPINLOCK_INIT;
    #define bsg_lock_mach_binary_image_access OSSpinLockLock
    #define bsg_unlock_mach_binary_image_access OSSpinLockUnlock
#endif

/**
 * Provide external access to the array of binary image info
 */
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
 * Create an empty array with initial capacity to hold Mach header info.
 */
void bsg_initialise_mach_binary_headers(size_t initialSize);

#endif /* BSG_KSMachHeaders_h */
