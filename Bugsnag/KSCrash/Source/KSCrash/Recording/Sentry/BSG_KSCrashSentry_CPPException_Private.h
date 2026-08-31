//
//  BSG_KSCrashSentry_CPPException_Private.h
//  Bugsnag
//
//  Created by Meiyalagan Ramadurai on 27/08/26.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#ifndef BSG_KSCrashSentry_CPPException_Private_h
#define BSG_KSCrashSentry_CPPException_Private_h

#include <stdint.h>

#ifdef __cplusplus

static constexpr int BSG_KSCPPExceptionStackTraceCapacity = 30;

struct BSG_KSCPPExceptionThreadState {
    uintptr_t stackTrace[BSG_KSCPPExceptionStackTraceCapacity] = {};
    int stackTraceCount = 0;
    bool isInspectingException = false;
};

struct BSG_KSCPPExceptionStackTraceView {
    uintptr_t *stackTrace;
    int stackTraceLength;
};

BSG_KSCPPExceptionThreadState &bsg_kscrashsentry_cppExceptionThreadState(void);

inline BSG_KSCPPExceptionStackTraceView bsg_kscrashsentry_cppExceptionStackTraceView(
    BSG_KSCPPExceptionThreadState &state, int framesToSkip) {
    if (framesToSkip < 0) {
        framesToSkip = 0;
    }
    const int stackTraceLength = state.stackTraceCount > framesToSkip
        ? state.stackTraceCount - framesToSkip : 0;
    return {
        stackTraceLength > 0 ? state.stackTrace + framesToSkip : nullptr,
        stackTraceLength,
    };
}

#endif  // __cplusplus

#endif // BSG_KSCrashSentry_CPPException_Private_h
