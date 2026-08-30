//
//  BSG_Symbolicate.h
//  Bugsnag
//
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#ifndef BSG_Symbolicate_h
#define BSG_Symbolicate_h

#include <stdint.h>

struct mach_header;

#ifdef __cplusplus
extern "C" {
#endif

struct bsg_symbolicate_result {
    const struct mach_header *image_header;
    const char *image_name;
    uintptr_t function_address;
    const char *function_name;
};

void bsg_symbolicate(const uintptr_t address, struct bsg_symbolicate_result *result);

#ifdef __cplusplus
}
#endif

#endif // BSG_Symbolicate_h
