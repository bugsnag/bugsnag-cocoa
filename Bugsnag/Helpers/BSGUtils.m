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

static BOOL BSGCreateFile(NSString *path) {
    // O_CREAT | O_EXCL: fails if anything, even a dangling symbolic link, is at the path
    NSDataWritingOptions options = NSDataWritingWithoutOverwriting;
#if TARGET_OS_IPHONE && !TARGET_OS_MACCATALYST
    // See BSGCreateFileWithoutCompleteProtection in BSGUtils.h. (open_dprotected_np would create and open the file in
    // one call, but its protection class constants are not public.)
    if (BSGProtectionClassForNewFileInDirectory(path.stringByDeletingLastPathComponent)) {
        options |= NSDataWritingFileProtectionCompleteUnlessOpen;
    }
#endif
    NSError *error = nil;
    if ([NSData.data writeToFile:path options:options error:&error]) {
        return YES;
    }
    NSError *underlying = error.userInfo[NSUnderlyingErrorKey];
    errno = [underlying.domain isEqualToString:NSPOSIXErrorDomain] ? (int)underlying.code : EIO;
    return NO;
}

#if defined(DEBUG) && DEBUG
// Replaceable so unit tests can stand in for the file system: NSFileProtectionComplete can only be set while the device
// (or the Mac's console) is unlocked, and the simulator ignores the class given at creation. Atomic, because a test
// replaces them while other threads (e.g. BSGCrashSentry setting up its directory) may call them.
typedef NSString *_Nullable (*BSGGetProtectionFunction)(NSString *path);
typedef BOOL (*BSGSetProtectionFunction)(NSString *path, NSString *protection, NSError **error);
typedef BOOL (*BSGCreateFileFunction)(NSString *path);
static _Atomic(BSGGetProtectionFunction) bsg_getProtection = BSGGetFileProtection;
static _Atomic(BSGSetProtectionFunction) bsg_setProtection = BSGSetFileProtection;
static _Atomic(BSGCreateFileFunction) bsg_createFile = BSGCreateFile;

BSGFileProtectionFunctions BSGSetFileProtectionFunctions(BSGFileProtectionFunctions functions) {
    return (BSGFileProtectionFunctions){
        .getProtection = atomic_exchange(&bsg_getProtection, functions.getProtection ?: BSGGetFileProtection),
        .setProtection = atomic_exchange(&bsg_setProtection, functions.setProtection ?: BSGSetFileProtection),
        .createFile = atomic_exchange(&bsg_createFile, functions.createFile ?: BSGCreateFile),
    };
}

static NSString *_Nullable BSGGetProtection(NSString *path) {
    return atomic_load(&bsg_getProtection)(path);
}

static BOOL BSGSetProtection(NSString *path, NSString *protection, NSError **error) {
    return atomic_load(&bsg_setProtection)(path, protection, error);
}

static BOOL BSGCreateNewFile(NSString *path) {
    return atomic_load(&bsg_createFile)(path);
}
#else
static NSString *_Nullable BSGGetProtection(NSString *path) {
    return BSGGetFileProtection(path);
}

static BOOL BSGSetProtection(NSString *path, NSString *protection, NSError **error) {
    return BSGSetFileProtection(path, protection, error);
}

static BOOL BSGCreateNewFile(NSString *path) {
    return BSGCreateFile(path);
}
#endif

NSString *_Nullable BSGProtectionClassForNewFileInDirectory(NSString *directory) {
    NSString *protection = BSGGetProtection(directory);
    return [protection isEqualToString:NSURLFileProtectionComplete] ? NSURLFileProtectionCompleteUnlessOpen : nil;
}

/// As BSGChangeNSFileProtectionComplete, but sets `error` instead of logging, so a caller that logs does not log twice.
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

/// The POSIX error in `error` or one it wraps, else EPERM (as for NSFileWriteNoPermissionError, 513, without one).
static int BSGErrnoForProtectionError(NSError *_Nullable error) {
    for (NSError *e = error; e; e = e.userInfo[NSUnderlyingErrorKey]) {
        if ([e.domain isEqualToString:NSPOSIXErrorDomain] && e.code > 0) {
            return (int)e.code;
        }
    }
    return EPERM;
}

int BSGOpenFileWithoutFollowingLinks(NSString *path, int flags) {
    // O_NOFOLLOW: the descriptor is always the file at the path itself. O_CLOEXEC: kept-open descriptors must not leak
    // into child processes.
    return open(path.fileSystemRepresentation, flags | O_CLOEXEC | O_NOFOLLOW, 0600);
}

/// Changes NSFileProtectionComplete, then returns a descriptor opened after the change, if one was made (see
/// BSGOpenFileWithoutCompleteProtection). Takes ownership of `fd`. The class is changed by path but the file is used by
/// descriptor, so the checks below ensure both are the same file: another instance of a macOS app, or the app itself
/// (e.g. clearing its data), can replace it, and the kept descriptor could then be a file still Complete, which stops
/// working once the device is locked.
static int BSGReopenWithoutCompleteProtection(NSString *path, int fd, int flags, BOOL created) {
    const char *fileSystemPath = path.fileSystemRepresentation;
    BOOL changed = NO;
    NSError *protectionError = nil;
    if (!BSGChangeProtectionComplete(path, &changed, &protectionError)) {
        close(fd);
        if (created) {
            // The file was created here, so it must not be left behind
            unlink(fileSystemPath);
        }
        // The caller logs the failure
        errno = BSGErrnoForProtectionError(protectionError);
        return -1;
    }
    if (!changed) {
        // The class checked is that of the file at the path, so it applies only if the descriptor is still that file
        struct stat byDescriptor, byPath;
        if (fstat(fd, &byDescriptor) != 0 || lstat(fileSystemPath, &byPath) != 0 ||
            byDescriptor.st_dev != byPath.st_dev || byDescriptor.st_ino != byPath.st_ino) {
            close(fd);
            // A created file renamed away cannot be safely unlinked by path; the feature flag store deletes leftover
            // featureflag.bin.*.tmp files when it reads the directory or takes the lock
            errno = EAGAIN;
            return -1;
        }
        // Not opened under NSFileProtectionComplete, so it is kept
        return fd;
    }
    // Reopen after the change; the file exists, so it is not created or truncated again
    const int reopened = BSGOpenFileWithoutFollowingLinks(path, flags & ~(O_CREAT | O_EXCL | O_TRUNC));
    if (reopened == -1) {
        if (errno == ENOENT) {
            // Removed or renamed away since the first open: the caller can try again. A file created here is gone.
            close(fd);
            errno = EAGAIN;
            return -1;
        }
        // The first descriptor was opened under NSFileProtectionComplete and may stop working once the device locks (a
        // mapping would then SIGBUS), so it is not used: the caller goes without the file rather than risk a crash.
        const int reopenError = errno;
        close(fd);
        if (created) {
            // The file was created here, so it must not be left behind
            unlink(fileSystemPath);
        }
        errno = reopenError;
        return -1;
    }
    // Another file, with an unchecked class, may have been put at the path between the opens
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

int BSGOpenFileWithoutCompleteProtection(NSString *path, int flags) {
    const int fd = BSGOpenFileWithoutFollowingLinks(path, flags);
    if (fd == -1) {
        return -1;
    }
    // Files opened with low-level APIs do not get Bugsnag's Apple backup policy from the JSON helpers
    [BSGFilesystem applyFileBackupSupportToPath:path];
    return BSGReopenWithoutCompleteProtection(path, fd, flags, (flags & O_EXCL) != 0);
}

int BSGCreateFileWithoutCompleteProtection(NSString *path, int flags) {
    const char *fileSystemPath = path.fileSystemRepresentation;
    if (!BSGCreateNewFile(path)) {
        return -1;
    }
    // The file exists now, so it is opened without O_CREAT; O_NOFOLLOW refuses a symbolic link put in its place
    flags &= ~(O_CREAT | O_EXCL | O_TRUNC);
    const int fd = BSGOpenFileWithoutFollowingLinks(path, flags);
    if (fd == -1) {
        // ENOENT: the file was removed (or renamed away) since it was created, so the caller can try again
        const int error = errno == ENOENT ? EAGAIN : errno;
        unlink(fileSystemPath);
        errno = error;
        return -1;
    }
    // NSData creates files with mode 0666 less the umask, so the mode is set as open() would have set it
    if (fchmod(fd, 0600) != 0) {
        const int error = errno;
        close(fd);
        unlink(fileSystemPath);
        errno = error;
        return -1;
    }
    // Set once, here (see BSGUtils.h). On iOS, tvOS, watchOS and visionOS the class was chosen at creation, so this
    // only reads it; on macOS the default class is changed if it is NSFileProtectionComplete.
    [BSGFilesystem applyFileBackupSupportToPath:path];
    return BSGReopenWithoutCompleteProtection(path, fd, flags, YES);
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
