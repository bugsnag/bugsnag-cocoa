//
//  BSG_KSMachHeaders.h
//  Bugsnag
//
//  Created by Robin Macharg on 04/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#ifndef BSG_KSMachHeaders_h
#define BSG_KSMachHeaders_h

#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

struct dyld_image_info;
struct mach_header;
struct dyld_all_image_infos;

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

    // Caller-owned metadata: never return UUID/name pointers into an unloadable
    // image. Copy this structure using the helper below to rebase its pointers.
    uint32_t flags;
    int32_t cpuType;
    int32_t cpuSubtype;
    uint8_t uuidStorage[16];
    char nameStorage[1024];
} BSG_Mach_Header_Info;

void bsg_mach_headers_copy_image(BSG_Mach_Header_Info *destination,
                                const BSG_Mach_Header_Info *source);

/** Copy a dyld array entry without dereferencing potentially unmapped memory. */
bool bsg_mach_headers_read_image_entry(const BSG_Dyld_Image_Info *images,
                                      uint32_t index, BSG_Dyld_Image_Info *entry);

// MARK: - Operations

/**
 * Initialize the three startup images. Readers never wait for an initializer
 * interrupted by a crash; lookups may fail until initialization completes.
 * System shared-cache images are cached on demand in a fixed-size cache.
 */
void bsg_mach_headers_initialize(void);

/**
 * Return dyld's live array of loaded images and place its current count in
 * `count`. dyld itself is not included in this array. An unavailable array is
 * returned as NULL with count zero. The array is owned by dyld, not a snapshot.
 */
const BSG_Dyld_Image_Info *bsg_mach_headers_get_images(uint32_t *count);

/** Copy information about the process's main image into `image`. */
bool bsg_mach_headers_get_main_image(BSG_Mach_Header_Info *image);

/** Copy information about the image that contains Bugsnag into `image`. */
bool bsg_mach_headers_get_self_image(BSG_Mach_Header_Info *image);

/** Copy information about dyld into `image`. */
bool bsg_mach_headers_get_dyld_image(BSG_Mach_Header_Info *image);

/** Copy a cached image by index, without waiting for a busy shared cache.
 * Enumerates unique startup images followed by shared-cache images. Returns
 * false at the end or if initialization/cache access is unavailable.
 * This is a best-effort fallback, not a complete list of loaded images.
 */
bool bsg_mach_headers_get_cached_image(uint32_t index, BSG_Mach_Header_Info *image);

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

/** Copy the __crash_info message; fail if unreadable or larger than capacity. */
bool bsg_mach_headers_get_crash_info_message(const BSG_Mach_Header_Info *image,
                                             char *message, size_t capacity);

/** Reset Mach header data for unit tests. */
void bsg_test_support_mach_headers_reset(void);

/** Return the number of startup images cached, excluding the shared-image cache. */
uint32_t bsg_test_support_mach_headers_cached_image_count(void);

/** Test hooks; callers must ensure no other readers or initializer are active. */
void bsg_test_support_mach_headers_set_initialization_hook(void (*hook)(void));
void bsg_test_support_mach_headers_set_dyld_info(const struct dyld_all_image_infos *info);

#endif /* BSG_KSMachHeaders_h */
