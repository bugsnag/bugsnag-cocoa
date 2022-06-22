//
//  BSGOS.h
//  Bugsnag
//
//  Created by Karl Stenerud on 22.06.22.
//  Copyright © 2022 Bugsnag Inc. All rights reserved.
//

#ifndef HDR_BSGOS_h
#define HDR_BSGOS_h

#ifdef __cplusplus
extern "C" {
#endif

#include <CoreFoundation/CoreFoundation.h>

typedef CF_ENUM(unsigned, BSGOS_Platform) {
    BSGOS_UNKNOWN_OS = 0,
    BSGOS_IOS = 1,
    BSGOS_TVOS = 2,
    BSGOS_MACOS = 3,
    BSGOS_WATCHOS = 4,
};

/**
 * Initialize the OS data. This function is idempotent.
 */
void bsgos_init(void);

/**
 * Async-safe alternative to __builtin_available to check if we are running the specified OS with a minimum version.
 *
 * To check for at least iOS 11: if (bsgos_available(BSGOS_IOS, 11, 0))
 * To check for at least macOS 10.14: if (bsgos_available(BSGOS_MACOS, 10, 14))
 */
bool bsgos_available(BSGOS_Platform wanted_platform, unsigned major_version, unsigned minor_version);


#ifdef __cplusplus
}
#endif

#endif // HDR_BSGOS_h
