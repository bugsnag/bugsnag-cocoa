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
    // NSDataWritingWithoutOverwriting creates the file with O_CREAT | O_EXCL, so it fails if anything (including a
    // symbolic link, even a dangling one) is at the path.
    NSDataWritingOptions options = NSDataWritingWithoutOverwriting;
#if TARGET_OS_IPHONE && !TARGET_OS_MACCATALYST
    // In a directory whose class is NSFileProtectionComplete, the class is given when the file is created, so the file
    // never has NSFileProtectionComplete, even briefly. (The file is closed once it has been written, so while the
    // device is locked BSGCreateFileWithoutCompleteProtection cannot open it again; see BSGUtils.h.) In any other
    // directory the file keeps the class it inherits, because NSFileProtectionCompleteUnlessOpen is stricter than the
    // default class. (open_dprotected_np would create and open the file in one call, but the protection class constants
    // it takes are not in the public headers.)
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
// In debug builds the protection class is read and changed, and files created, through these functions so that unit
// tests can stand in for the file system: NSFileProtectionComplete can only be set while the device (or the Mac's
// console) is unlocked, and the simulator ignores the class given when a file is created, so the code that handles them
// could not otherwise be tested on a locked or headless host or in the simulator. They are atomic because a test
// replaces them while other threads (e.g. BSGCrashSentry setting up its directory) may be calling them.
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

/// Changes NSFileProtectionComplete as BSGChangeNSFileProtectionComplete does, but does not log a failure: `error` is
/// set instead, so that a caller that logs the failure itself does not log it twice.
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
        bsg_log_warn(@"BSGDisableFileProtection: %@", error);
        return NO;
    }
    return YES;
}

/// The errno for a failure to change a protection class: the POSIX error that caused it, if the error (or one that it
/// wraps) has one, otherwise EPERM, as for NSCocoaErrorDomain 513 (NSFileWriteNoPermissionError) without one.
static int BSGErrnoForProtectionError(NSError *_Nullable error) {
    for (NSError *e = error; e; e = e.userInfo[NSUnderlyingErrorKey]) {
        if ([e.domain isEqualToString:NSPOSIXErrorDomain] && e.code > 0) {
            return (int)e.code;
        }
    }
    return EPERM;
}

int BSGOpenFileWithoutFollowingLinks(NSString *path, int flags) {
    // O_NOFOLLOW: a symbolic link at the path is refused rather than followed, so the descriptor always refers to the
    // file at the path itself. O_CLOEXEC: a descriptor that is kept open must not leak into child processes.
    return open(path.fileSystemRepresentation, flags | O_CLOEXEC | O_NOFOLLOW, 0600);
}

/// Changes NSFileProtectionComplete as BSGChangeNSFileProtectionComplete does, then returns a descriptor for the file
/// opened after the change if it was made (see BSGOpenFileWithoutCompleteProtection). Takes ownership of `fd`.
///
/// The protection class is read and changed by path, but the file is used through the descriptor, so the checks below
/// make sure that both refer to the same file. The file is in the app's own container, but it is not only this process
/// that can replace it: another instance of a macOS app shares the container, and the app itself can delete or replace
/// files in it (e.g. while clearing its data). Without the checks the descriptor kept open could refer to a file whose
/// NSFileProtectionComplete was never changed, which stops working once the device is locked.
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
        // Not logged here: the caller logs the failure, with its own context
        errno = BSGErrnoForProtectionError(protectionError);
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
    const int reopened = BSGOpenFileWithoutFollowingLinks(path, flags & ~(O_CREAT | O_EXCL | O_TRUNC));
    if (reopened == -1) {
        if (errno == ENOENT) {
            // The file was removed (or renamed away) after it was opened, so the first descriptor refers to a file that
            // is no longer at the path; the caller can try again. A file created here is already gone.
            close(fd);
            errno = EAGAIN;
            return -1;
        }
        // The first descriptor still refers to the file, whose protection class has been changed, but it was opened
        // under NSFileProtectionComplete and so may stop working once the device is locked. It is still kept: without
        // it the file could not be used at all for this launch. Logged as a warning so that release builds show it.
        const int reopenError __unused = errno; // Unused when logging is compiled out
        bsg_log_warn(@"Could not reopen %@ after changing its protection class (errno %d); it may become inaccessible "
                     @"while the device is locked", path, reopenError);
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
    // The backup policy and the protection class are set once, here: they are attributes of the file, which
    // rename() keeps, so a file created here and renamed into place does not need them set again when it is
    // opened later. (On iOS, tvOS, watchOS and visionOS the class was chosen when the file was created, so this only
    // reads it; on macOS the file has the default class, which is changed if it is NSFileProtectionComplete.)
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
