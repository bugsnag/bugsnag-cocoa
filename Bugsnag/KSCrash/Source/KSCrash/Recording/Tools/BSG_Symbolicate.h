//
//  BSG_Symbolicate.h
//  Bugsnag
//
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#ifndef BSG_Symbolicate_h
#define BSG_Symbolicate_h

#include <stdint.h>
#include "BSG_KSMachHeaders.h"

struct mach_header;

#ifdef __cplusplus
extern "C" {
#endif

struct bsg_symbolicate_result {
    const struct mach_header *image_header;
    const char *image_name;
    uintptr_t function_address;
    const char *function_name;
    // Storage belongs to the result, not to dyld's image mapping.
    BSG_Mach_Header_Info image;
    char function_name_storage[4096];
};

void bsg_symbolicate(const uintptr_t address, struct bsg_symbolicate_result *result);

/** Symbolicate `address` using an image the caller has already resolved
 * (for example, one already recorded in this report's referenced-image
 * set), instead of asking bsg_mach_headers_image_at_address() to scan
 * dyld's image array again for an address that is likely to fall in the
 * same image as an earlier frame. The image must already have been
 * verified when it was resolved (its UUID is checked against the copy held
 * by the report), so it is not re-verified for every frame; all symbol-table
 * reads are still bounds-checked kernel reads, so a stale `image` degrades to
 * a missing symbol name rather than a crash. */
void bsg_symbolicate_with_image(const uintptr_t address, const BSG_Mach_Header_Info *image,
                                struct bsg_symbolicate_result *result);

#ifdef __cplusplus
}
#endif

#endif // BSG_Symbolicate_h
