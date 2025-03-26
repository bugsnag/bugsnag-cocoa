//
//  BSG_KSCrashNames.h
//  Bugsnag
//
//  Created by Karl Stenerud on 28.09.21.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#ifndef BSG_KSCrashNames_h
#define BSG_KSCrashNames_h

#include <mach/machine/vm_types.h>

#ifdef __cplusplus
extern "C" {
#endif

const char *bsg_kscrashthread_state_name(integer_t state);

#ifdef __cplusplus
}
#endif

#endif /* BSG_KSCrashNames_h */
