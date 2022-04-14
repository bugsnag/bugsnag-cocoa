//
//  BSGRunContext.m
//  Bugsnag
//
//  Copyright © 2022 Bugsnag Inc. All rights reserved.
//

#import "BSGRunContext.h"

#import "BSG_KSLogger.h"

#import <Foundation/Foundation.h>
#import <sys/mman.h>
#import <sys/stat.h>

#define SIZEOF_STRUCT sizeof(struct BSGRunContext)

struct BSGRunContext *bsg_runContext;

const struct BSGRunContext *bsg_lastRunContext;

/// Loads the contents of the state file into memory and sets the
/// `bsg_lastRunContext` pointer if the contents are valid.
static void BSGRunContextLoadLast(int fd) {
    struct stat sb;
    // Only expose previous state if size matches...
    if (fstat(fd, &sb) == 0 && sb.st_size == SIZEOF_STRUCT) {
        static struct BSGRunContext context;
        if (read(fd, &context, SIZEOF_STRUCT) == SIZEOF_STRUCT &&
            // ...and so does the structVersion
            context.structVersion == BSGRUNCONTEXT_VERSION) {
            bsg_lastRunContext = &context;
        }
    }
}

/// Truncates or extends the file to the size of struct BSGRunContext,
/// maps it into memory, and sets the `bsg_runContext` pointer.
static void BSGRunContextResizeAndMapFile(int fd) {
    static struct BSGRunContext fallback;
    
    // Note: ftruncate fills the file with zeros when extending.
    if (ftruncate(fd, SIZEOF_STRUCT) != 0) {
        bsg_log_warn(@"ftruncate failed: %d", errno);
        goto fail;
    }
    
    const int prot = PROT_READ | PROT_WRITE;
    const int flags = MAP_FILE | MAP_SHARED;
    void *ptr = mmap(0, SIZEOF_STRUCT, prot, flags, fd, 0);
    if (ptr == MAP_FAILED) {
        bsg_log_warn(@"mmap failed: %d", errno);
        goto fail;
    }
    
    memset(ptr, 0, SIZEOF_STRUCT);
    bsg_runContext = ptr;
    return;
    
fail:
    bsg_runContext = &fallback;
}

/// Populates `bsg_runContext`
static void BSGRunContextPopulate() {
    // Set `structVersion` last so that BSGRunContextLoadLast() will reject data
    // that is not fully initialised.
    bsg_runContext->structVersion = BSGRUNCONTEXT_VERSION;
}

void BSGRunContextInit(const char *path) {
    int fd = open(path, O_RDWR | O_CREAT, 0600);
    if (fd < 0) {
        bsg_log_warn(@"Could not open %s", path);
    }
    BSGRunContextLoadLast(fd);
    BSGRunContextResizeAndMapFile(fd);
    BSGRunContextPopulate();
    if (fd > 0) {
        close(fd);
    }
}
