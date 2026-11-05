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
#include <mach-o/loader.h>

// Older Apple SDK headers omit this flag. Its Mach-O bit value is unchanged;
// keep the compatibility definition shared by lookup, symbolication and tests.
#ifndef MH_DYLIB_IN_CACHE
#define MH_DYLIB_IN_CACHE 0x80000000
#endif

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

/** Whether startup-image initialization has already completed. Never
 * triggers it: a single atomic load, safe to call from a crash handler when
 * the caller would rather skip than risk running the (non-reentrant,
 * allocating) initializer inline during crash handling. Initialization
 * normally completes at SDK startup, well before any crash handler could
 * run, so this should read true in practice; it exists as a defensive guard
 * for callers that are reached only from crash-time code, not a normal way
 * to use this cache.
 */
bool bsg_mach_headers_ready(void);

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

/**
 * Cheap check that `image` -- previously returned by
 * bsg_mach_headers_image_at_address() -- is still the image dyld has loaded at
 * that address: the address-sorted snapshot it came from is still valid for
 * dyld's current list (timestamp, array pointer and count all unchanged) and
 * holds the same UUID and size. One kernel read, versus re-parsing the image's
 * load commands. Returns false if that cannot be established (no snapshot, a
 * busy snapshot, or dyld's list changed), in which case the caller should fall
 * back to a full re-verification with bsg_mach_headers_image_for_header().
 * Never waits.
 */
bool bsg_mach_headers_image_is_current(const BSG_Mach_Header_Info *image);

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

/** Maximum number of times get_images() re-reads dyld's image array while it
 * is being changed before giving up. Exposed so tests can assert against it. */
#define BSG_GET_IMAGES_MAX_ATTEMPTS 5

/** Test-only: `hook` is called with (attempt, 0) before each read attempt and
 * (attempt, 1) after the array/count reads but before the closing timestamp
 * read, allowing a test to mutate a fake dyld_all_image_infos at those points.
 * Pass NULL to remove. Callers must ensure no other readers are active. */
void bsg_test_support_mach_headers_set_get_images_hook(void (*hook)(int attempt, int stage));

#endif /* BSG_KSMachHeaders_h */
