//
//  BSGUtils.m
//  Bugsnag
//
//  Created by Nick Dowell on 18/06/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "BSGUtils.h"

#import "BSGFilesystem.h"
#import "BugsnagLogger.h"

#import <fcntl.h>
#import <stdatomic.h>
#import <sys/stat.h>
#import <unistd.h>

void bsg_safe_strncpy(char *dst, const char *src, size_t length) {
    if (length > 0) {
        strncpy(dst, src, length);
        dst[length-1] = 0;
    }
}

char *_Nullable BSGCStringWithData(NSData *_Nullable data) {
    char *buffer;
    if (data.length && (buffer = calloc(1, data.length + 1))) {
        [data getBytes:buffer length:data.length];
        return buffer;
    }
    return NULL;
}

BOOL BSGDisableNSFileProtectionComplete(NSString *path) {
    return BSGChangeNSFileProtectionComplete(path, NULL);
}

#pragma mark - File protection

static NSString *_Nullable BSGGetFileProtection(NSString *path) {
    NSURLFileProtectionType protection = nil;
    [[NSURL fileURLWithPath:path] getResourceValue:&protection forKey:NSURLFileProtectionKey error:nil];
    return protection;
}

static BOOL BSGSetFileProtection(NSString *path, NSString *protection, NSError **error) {
    return [[NSURL fileURLWithPath:path] setResourceValue:protection forKey:NSURLFileProtectionKey error:error];
}

#if defined(DEBUG) && DEBUG
// Replaceable so tests can simulate NSFileProtectionComplete, which can only be set while the device is unlocked.
// Atomic because tests swap them while other threads (e.g. BSGCrashSentry) may call them.
typedef NSString *_Nullable (*BSGGetProtectionFunction)(NSString *path);
typedef BOOL (*BSGSetProtectionFunction)(NSString *path, NSString *protection, NSError **error);
static _Atomic(BSGGetProtectionFunction) bsg_getProtection = BSGGetFileProtection;
static _Atomic(BSGSetProtectionFunction) bsg_setProtection = BSGSetFileProtection;

BSGFileProtectionFunctions BSGSetFileProtectionFunctions(BSGFileProtectionFunctions functions) {
    return (BSGFileProtectionFunctions){
        .getProtection = atomic_exchange(&bsg_getProtection, functions.getProtection ?: BSGGetFileProtection),
        .setProtection = atomic_exchange(&bsg_setProtection, functions.setProtection ?: BSGSetFileProtection),
    };
}

static NSString *_Nullable BSGGetProtection(NSString *path) {
    return atomic_load(&bsg_getProtection)(path);
}

static BOOL BSGSetProtection(NSString *path, NSString *protection, NSError **error) {
    return atomic_load(&bsg_setProtection)(path, protection, error);
}
#else
static NSString *_Nullable BSGGetProtection(NSString *path) {
    return BSGGetFileProtection(path);
}

static BOOL BSGSetProtection(NSString *path, NSString *protection, NSError **error) {
    return BSGSetFileProtection(path, protection, error);
}
#endif

/// As BSGChangeNSFileProtectionComplete, but sets `error` instead of logging, for callers that log themselves.
static BOOL BSGChangeProtectionComplete(NSString *path, BOOL *_Nullable changed, NSError **error) {
    if (changed) {
        *changed = NO;
    }
    if (![BSGGetProtection(path) isEqualToString:NSURLFileProtectionComplete]) {
        return YES;
    }
    if (!BSGSetProtection(path, NSURLFileProtectionCompleteUnlessOpen, error)) {
        return NO;
    }
    bsg_log_debug(@"Set NSFileProtectionCompleteUnlessOpen for %@", path);
    if (changed) {
        *changed = YES;
    }
    return YES;
}

BOOL BSGChangeNSFileProtectionComplete(NSString *path, BOOL *changed) {
    NSError *error = nil;
    if (!BSGChangeProtectionComplete(path, changed, &error)) {
        bsg_log_warn(@"Could not change the protection class of %@: %@", path.lastPathComponent, error);
        return NO;
    }
    return YES;
}

/// The POSIX error in `error` or its underlying errors, otherwise EPERM (as for NSFileWriteNoPermissionError).
static int BSGErrnoForProtectionError(NSError *_Nullable error) {
    for (NSError *e = error; e; e = e.userInfo[NSUnderlyingErrorKey]) {
        if ([e.domain isEqualToString:NSPOSIXErrorDomain] && e.code > 0) {
            return (int)e.code;
        }
    }
    return EPERM;
}

int BSGOpenFileWithoutCompleteProtection(NSString *path, int flags) {
    const char *fileSystemPath = path.fileSystemRepresentation;
    // O_NOFOLLOW: refuse symbolic links. O_CLOEXEC: a long-lived descriptor must not leak into child processes.
    const int fd = open(fileSystemPath, flags | O_CLOEXEC | O_NOFOLLOW, 0600);
    if (fd == -1) {
        return -1;
    }
    // Protection is changed by path but the file is used by descriptor, so the checks below ensure both are the same
    // file. Another app instance (macOS) or the app itself can replace it; otherwise the descriptor could refer to a
    // file still under NSFileProtectionComplete, which stops working once the device locks.

    // Low-level files do not get the backup policy from the JSON helpers
    [BSGFilesystem applyFileBackupSupportToPath:path];
    BOOL changed = NO;
    NSError *protectionError = nil;
    if (!BSGChangeProtectionComplete(path, &changed, &protectionError)) {
        close(fd);
        // The caller logs
        errno = BSGErrnoForProtectionError(protectionError);
        return -1;
    }
    if (!changed) {
        // The protection class read by path only applies if the descriptor still refers to the file at the path
        struct stat byDescriptor, byPath;
        if (fstat(fd, &byDescriptor) != 0 || lstat(fileSystemPath, &byPath) != 0 ||
            byDescriptor.st_dev != byPath.st_dev || byDescriptor.st_ino != byPath.st_ino) {
            close(fd);
            errno = EAGAIN;
            return -1;
        }
        // Not opened under NSFileProtectionComplete, so no reopen is needed
        return fd;
    }
    // Reopen so the kept descriptor postdates the protection change; without O_CREAT/O_EXCL/O_TRUNC this time.
    const int reopened = open(fileSystemPath, (flags & ~(O_CREAT | O_EXCL | O_TRUNC)) | O_CLOEXEC | O_NOFOLLOW);
    if (reopened == -1) {
        if (errno == ENOENT) {
            // Removed or renamed away since the first open
            close(fd);
            errno = EAGAIN;
            return -1;
        }
        // Not falling back to the first descriptor: opened under NSFileProtectionComplete, a mapping of it would fault
        // (SIGBUS) once the device locks. The caller goes without the file instead.
        const int reopenError = errno;
        close(fd);
        errno = reopenError;
        return -1;
    }
    // The file may have been replaced between the two opens; both descriptors must refer to the same file
    struct stat first, second;
    if (fstat(fd, &first) != 0 || fstat(reopened, &second) != 0 ||
        first.st_dev != second.st_dev || first.st_ino != second.st_ino) {
        close(fd);
        close(reopened);
        errno = EAGAIN;
        return -1;
    }
    close(fd);
    return reopened;
}

dispatch_queue_t BSGGetFileSystemQueue(void) {
    static dispatch_once_t onceToken;
    static dispatch_queue_t queue;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.bugsnag.filesystem", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

#if TARGET_OS_IOS

NSString *_Nullable BSGStringFromDeviceOrientation(UIDeviceOrientation orientation) {
    switch (orientation) {
        case UIDeviceOrientationPortraitUpsideDown: return @"portraitupsidedown";
        case UIDeviceOrientationPortrait:           return @"portrait";
        case UIDeviceOrientationLandscapeRight:     return @"landscaperight";
        case UIDeviceOrientationLandscapeLeft:      return @"landscapeleft";
        case UIDeviceOrientationFaceUp:             return @"faceup";
        case UIDeviceOrientationFaceDown:           return @"facedown";
        case UIDeviceOrientationUnknown:            break;
    }
    return nil;
}

#endif

NSString *_Nullable BSGStringFromThermalState(NSProcessInfoThermalState thermalState) {
    switch (thermalState) {
        case NSProcessInfoThermalStateNominal:  return @"nominal";
        case NSProcessInfoThermalStateFair:     return @"fair";
        case NSProcessInfoThermalStateSerious:  return @"serious";
        case NSProcessInfoThermalStateCritical: return @"critical";
    }
    return nil;
}

void BSGPreventInlining(NSString * _Nullable tag) {
    __asm__ __volatile__("" : : "r"(tag) : "memory");
}
