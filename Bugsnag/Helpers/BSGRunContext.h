//
//  BSGRunContext.h
//  Bugsnag
//
//  Copyright © 2022 Bugsnag Inc. All rights reserved.
//

#define BSGRUNCONTEXT_VERSION 1

struct BSGRunContext {
    long structVersion;
};

/// Information about the current run of the app / process.
///
/// This structure is mapped to a file so that changes will be persisted by the OS.
///
/// Guaranteed to be non-null once BSGRunContextInit() is called.
extern struct BSGRunContext *_Nonnull bsg_runContext;

/// Information about the last run of the app / process, if it could be loaded.
extern const struct BSGRunContext *_Nullable bsg_lastRunContext;

void BSGRunContextInit(const char *_Nonnull path);
