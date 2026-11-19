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
#if !TARGET_OS_OSX || defined(__MAC_11_0)
    if (@available(macOS 11.0, *)) {
        NSURLFileProtectionType protection = nil;
        [[NSURL fileURLWithPath:path] getResourceValue:&protection forKey:NSURLFileProtectionKey error:nil];
        return protection;
    }
#endif
    (void)path;
    return nil;
}

static BOOL BSGSetFileProtection(NSString *path, NSString *protection, NSError **error) {
#if !TARGET_OS_OSX || defined(__MAC_11_0)
    if (@available(macOS 11.0, *)) {
        return [[NSURL fileURLWithPath:path] setResourceValue:protection forKey:NSURLFileProtectionKey error:error];
    }
#endif
    (void)path;
    (void)protection;
    (void)error;
    return YES;
}

#if defined(DEBUG) && DEBUG
// In debug builds the protection class is read and changed through these functions so that unit tests can stand in for
// the file system: NSFileProtectionComplete can only be set while the device (or the Mac's console) is unlocked, so the
// code that handles it could not otherwise be tested on a locked or headless host or in the simulator.
static BSGFileProtectionFunctions bsg_fileProtectionFunctions = {
    .getProtection = BSGGetFileProtection,
    .setProtection = BSGSetFileProtection,
};

BSGFileProtectionFunctions BSGSetFileProtectionFunctions(BSGFileProtectionFunctions functions) {
    const BSGFileProtectionFunctions previous = bsg_fileProtectionFunctions;
    bsg_fileProtectionFunctions.getProtection = functions.getProtection ?: BSGGetFileProtection;
    bsg_fileProtectionFunctions.setProtection = functions.setProtection ?: BSGSetFileProtection;
    return previous;
}

static NSString *_Nullable BSGGetProtection(NSString *path) {
    return bsg_fileProtectionFunctions.getProtection(path);
}

static BOOL BSGSetProtection(NSString *path, NSString *protection, NSError **error) {
    return bsg_fileProtectionFunctions.setProtection(path, protection, error);
}
#else
static NSString *_Nullable BSGGetProtection(NSString *path) {
    return BSGGetFileProtection(path);
}

static BOOL BSGSetProtection(NSString *path, NSString *protection, NSError **error) {
    return BSGSetFileProtection(path, protection, error);
}
#endif

BOOL BSGChangeNSFileProtectionComplete(NSString *path, BOOL *changed) {
    if (changed) {
        *changed = NO;
    }
    // Using NSFileProtection* causes run-time link errors on older versions of macOS.
    // NSURLFileProtectionKey is unavailable in macOS SDKs prior to 11.0
#if !TARGET_OS_OSX || defined(__MAC_11_0)
    if (@available(macOS 11.0, *)) {
        NSString *protection = BSGGetProtection(path);
        if (![protection isEqualToString:NSURLFileProtectionComplete]) {
            return YES;
        }
        
        NSError *error = nil;
        if (!BSGSetProtection(path, NSURLFileProtectionCompleteUnlessOpen, &error)) {
            bsg_log_warn(@"BSGDisableFileProtection: %@", error);
            return NO;
        }
        bsg_log_debug(@"Set NSFileProtectionCompleteUnlessOpen for %@", path);
        if (changed) {
            *changed = YES;
        }
    }
#else
    (void)(path);
#endif
    return YES;
}

int BSGOpenFileWithoutCompleteProtection(NSString *path, int flags) {
    const char *fileSystemPath = path.fileSystemRepresentation;
    // O_NOFOLLOW: a symbolic link at the path is refused rather than followed, so the descriptor always refers to the
    // file at the path itself. O_CLOEXEC: a descriptor that is kept open must not leak into child processes.
    const int fd = open(fileSystemPath, flags | O_CLOEXEC | O_NOFOLLOW, 0600);
    if (fd == -1) {
        return -1;
    }
    // Files opened with low-level APIs do not get Bugsnag's Apple backup policy from the JSON helpers
    [BSGFilesystem applyFileBackupSupportToPath:path];
    BOOL changed = NO;
    if (!BSGChangeNSFileProtectionComplete(path, &changed)) {
        close(fd);
        errno = EPERM;
        return -1;
    }
    if (!changed) {
        // The protection class was read from the file at the path, so it only applies to the descriptor if that is
        // still the file it refers to. If the file was removed or replaced after it was opened, the descriptor refers to
        // a file whose protection class was never checked.
        struct stat byDescriptor, byPath;
        if (fstat(fd, &byDescriptor) != 0 || lstat(fileSystemPath, &byPath) != 0 ||
            byDescriptor.st_dev != byPath.st_dev || byDescriptor.st_ino != byPath.st_ino) {
            close(fd);
            errno = EAGAIN;
            return -1;
        }
        // The descriptor was not opened under NSFileProtectionComplete, so it is kept as it is
        return fd;
    }
    // Reopen so that the descriptor that is kept open was opened after the protection class was changed. The file
    // exists now, so it is not created or truncated again.
    const int reopened = open(fileSystemPath, (flags & ~(O_CREAT | O_EXCL | O_TRUNC)) | O_CLOEXEC | O_NOFOLLOW);
    if (reopened == -1) {
        if (errno == ENOENT) {
            // The file was removed (or renamed away) after it was opened, so the first descriptor refers to a file that
            // is no longer at the path
            close(fd);
            errno = EAGAIN;
            return -1;
        }
        // The first descriptor still refers to the file, whose protection class has been changed, but it was opened
        // under NSFileProtectionComplete and so may stop working once the device is locked
        const int reopenError __unused = errno; // Unused when debug logging is compiled out
        bsg_log_debug(@"Could not reopen %@ after changing its protection class (errno %d); keeping the first descriptor",
                      path, reopenError);
        return fd;
    }
    // A different file could have been put at the path between the two opens, in which case the reopened descriptor
    // refers to a file whose protection class was never checked, so both descriptors must refer to the same file
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
