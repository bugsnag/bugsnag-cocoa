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
// could not otherwise be tested on a locked or headless host or in the simulator.
static BSGFileProtectionFunctions bsg_fileProtectionFunctions = {
    .getProtection = BSGGetFileProtection,
    .setProtection = BSGSetFileProtection,
    .createFile = BSGCreateFile,
};

BSGFileProtectionFunctions BSGSetFileProtectionFunctions(BSGFileProtectionFunctions functions) {
    const BSGFileProtectionFunctions previous = bsg_fileProtectionFunctions;
    bsg_fileProtectionFunctions.getProtection = functions.getProtection ?: BSGGetFileProtection;
    bsg_fileProtectionFunctions.setProtection = functions.setProtection ?: BSGSetFileProtection;
    bsg_fileProtectionFunctions.createFile = functions.createFile ?: BSGCreateFile;
    return previous;
}

static NSString *_Nullable BSGGetProtection(NSString *path) {
    return bsg_fileProtectionFunctions.getProtection(path);
}

static BOOL BSGSetProtection(NSString *path, NSString *protection, NSError **error) {
    return bsg_fileProtectionFunctions.setProtection(path, protection, error);
}

static BOOL BSGCreateNewFile(NSString *path) {
    return bsg_fileProtectionFunctions.createFile(path);
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
#if !TARGET_OS_OSX || defined(__MAC_11_0)
    if (@available(macOS 11.0, *)) {
        NSString *protection = BSGGetProtection(directory);
        return [protection isEqualToString:NSURLFileProtectionComplete] ? NSURLFileProtectionCompleteUnlessOpen : nil;
    }
#endif
    (void)directory;
    return nil;
}

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

int BSGOpenFileWithoutFollowingLinks(NSString *path, int flags) {
    // O_NOFOLLOW: a symbolic link at the path is refused rather than followed, so the descriptor always refers to the
    // file at the path itself
    return open(path.fileSystemRepresentation, flags | O_CLOEXEC | O_NOFOLLOW, 0600);
}

/// Changes NSFileProtectionComplete as BSGChangeNSFileProtectionComplete does, then returns a descriptor for the file
/// opened after the change if it was made (see BSGOpenFileWithoutCompleteProtection). Takes ownership of `fd`.
static int BSGReopenWithoutCompleteProtection(NSString *path, int fd, int flags, BOOL created) {
    BOOL changed = NO;
    if (!BSGChangeNSFileProtectionComplete(path, &changed)) {
        close(fd);
        if (created) {
            // The file was created here, so it must not be left behind
            unlink(path.fileSystemRepresentation);
        }
        errno = EPERM;
        return -1;
    }
    if (!changed) {
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
        // The first descriptor still refers to the file, whose protection class has been changed
        return fd;
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
