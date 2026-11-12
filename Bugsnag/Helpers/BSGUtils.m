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

BOOL BSGChangeNSFileProtectionComplete(NSString *path, BOOL *changed) {
    if (changed) {
        *changed = NO;
    }
    // Using NSFileProtection* causes run-time link errors on older versions of macOS.
    // NSURLFileProtectionKey is unavailable in macOS SDKs prior to 11.0
#if !TARGET_OS_OSX || defined(__MAC_11_0)
    if (@available(macOS 11.0, *)) {
        NSURL *url = [NSURL fileURLWithPath:path];
        
        NSURLFileProtectionType protection = nil;
        [url getResourceValue:&protection forKey:NSURLFileProtectionKey error:nil];
        
        if (protection != NSURLFileProtectionComplete) {
            return YES;
        }
        
        NSError *error = nil;
        if (![url setResourceValue:NSURLFileProtectionCompleteUnlessOpen
                            forKey:NSURLFileProtectionKey error:&error]) {
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
    // O_NOFOLLOW: a symbolic link at the path is refused rather than followed, so the descriptor always refers
    // to the file at the path itself.
    int fd = open(path.fileSystemRepresentation, flags | O_CLOEXEC | O_NOFOLLOW, 0600);
    if (fd == -1) {
        const int error = errno;
        bsg_log_warn(@"Could not open %@: %d", path.lastPathComponent, error);
        errno = error;
        return -1;
    }
    // Files opened with low-level APIs do not get Bugsnag's Apple backup policy from the JSON helpers
    [BSGFilesystem applyFileBackupSupportToPath:path];

    BOOL changed = NO;
    if (!BSGChangeNSFileProtectionComplete(path, &changed)) {
        close(fd);
        if (flags & O_EXCL) {
            // The file was created here, so it must not be left behind
            unlink(path.fileSystemRepresentation);
        }
        return -1;
    }
    if (!changed) {
        // The descriptor was not opened under NSFileProtectionComplete, so it is kept as it is
        return fd;
    }

    // Reopen so that the descriptor that is kept open was opened after the protection class was changed. The file
    // exists now, so it is not created or truncated again. The path is opened again, so the new descriptor is only
    // used if it refers to the same file as the first one (the path could have been replaced in between); otherwise
    // the open fails rather than returning a descriptor for a file whose protection class was not changed.
    int reopened = open(path.fileSystemRepresentation, (flags & ~(O_CREAT | O_EXCL | O_TRUNC)) | O_CLOEXEC | O_NOFOLLOW);
    if (reopened == -1) {
        // The first descriptor still refers to the file, whose protection class has been changed
        return fd;
    }
    struct stat original, current;
    if (fstat(fd, &original) != 0 || fstat(reopened, &current) != 0 ||
        original.st_dev != current.st_dev || original.st_ino != current.st_ino) {
        bsg_log_warn(@"Could not open %@: the file was replaced while it was being opened", path.lastPathComponent);
        close(reopened);
        close(fd);
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
