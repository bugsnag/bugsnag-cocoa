//
//  BSG_Symbolicate.h
//  Bugsnag
//
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#ifndef BSG_Symbolicate_h
#define BSG_Symbolicate_h

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdint.h>

struct bsg_symbolicate_result {
    const struct bsg_mach_image *image;
    uintptr_t function_address;
    const char *function_name;
};

bool bsg_symbolicate(const uintptr_t address, struct bsg_symbolicate_result *result);

#ifdef __cplusplus
}
#endif

#endif // BSG_Symbolicate_h
