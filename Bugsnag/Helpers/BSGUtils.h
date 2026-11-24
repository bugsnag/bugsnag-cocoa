//
//  BSGUtils.h
//  Bugsnag
//
//  Created by Nick Dowell on 18/06/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "BSGDefines.h"
#import "BSGUIKit.h"

__BEGIN_DECLS

NS_ASSUME_NONNULL_BEGIN

/// Returns a heap allocated null-terminated C string with the contents of `data`, or NULL if `data` is nil or empty.
char *_Nullable BSGCStringWithData(NSData *_Nullable data);

/// Changes the NSFileProtectionKey attribute of the specified file or directory from NSFileProtectionComplete to NSFileProtectionCompleteUnlessOpen.
/// Has no effect if the specified file or directory does not have NSFileProtectionComplete.
///
/// Files with NSFileProtectionComplete cannot be read from or written to while the device is locked or booting.
///
/// Files with NSFileProtectionCompleteUnlessOpen can be created while the device is locked, but once closed, cannot be opened again until the device is unlocked.
/// So a file that must stay accessible while locked (e.g. memory mapped) must be opened after this call, and its
/// descriptor kept open while it is used, even while a mapping remains.
BOOL BSGDisableNSFileProtectionComplete(NSString *path);

/// As BSGDisableNSFileProtectionComplete; also sets `changed` (if not NULL) to whether the file had
/// NSFileProtectionComplete. `changed` is NO on error.
///
/// An unreadable protection class is treated as not NSFileProtectionComplete; if it really is, I/O on the file can
/// fail once the device locks, which callers handle like any other I/O failure.
BOOL BSGChangeNSFileProtectionComplete(NSString *path, BOOL *_Nullable changed);

/// Opens (or, with O_CREAT, creates) a file to keep open while it is used, changing NSFileProtectionComplete to
/// NSFileProtectionCompleteUnlessOpen and applying Bugsnag's backup policy. Uses O_CLOEXEC | O_NOFOLLOW; new files get
/// mode 0600. Does not log; the caller logs failures.
///
/// Returns the descriptor, or -1 with errno:
/// - ELOOP: a symbolic link is at the path.
/// - EAGAIN: the file at the path was removed or replaced while opening (checked by device and inode); retry.
/// - The POSIX error from changing the protection class, or EPERM if there is none.
/// - The reopen error, if the file cannot be reopened after its protection class changed. The first descriptor was
///   opened under NSFileProtectionComplete and could fail (or make a mapping fault) once the device locks.
int BSGOpenFileWithoutCompleteProtection(NSString *path, int flags);

#if defined(DEBUG) && DEBUG
/// The functions BSGChangeNSFileProtectionComplete uses to read and set a protection class. Unit tests replace them
/// to simulate classes the host cannot set, e.g. NSFileProtectionComplete while locked.
typedef struct {
    /// Returns the file's protection class, or nil if it has none or it cannot be read.
    NSString *_Nullable (*_Nullable getProtection)(NSString *path);
    /// Sets the file's protection class, returning NO and setting `error` on failure.
    BOOL (*_Nullable setProtection)(NSString *path, NSString *protection, NSError *_Nullable *_Nullable error);
} BSGFileProtectionFunctions;

/// Unit tests only: atomically replaces the protection functions, returning the previous ones. NULL restores a default.
BSGFileProtectionFunctions BSGSetFileProtectionFunctions(BSGFileProtectionFunctions functions);
#endif

dispatch_queue_t BSGGetFileSystemQueue(void);

#if TARGET_OS_IOS
NSString *_Nullable BSGStringFromDeviceOrientation(UIDeviceOrientation orientation);
#endif

API_AVAILABLE(ios(11.0), tvos(11.0))
NSString *_Nullable BSGStringFromThermalState(NSProcessInfoThermalState thermalState);

static inline NSString * _Nullable BSGStringFromClass(Class _Nullable cls) {
    return cls ? NSStringFromClass((Class _Nonnull)cls) : nil;
}

/**
 * Copy characters from src to dst, up to a maximum of length bytes (including the NUL terminator).
 * Unlike strncpy, this function always ensures that dst is NUL terminated (if length > 0).
 */
void bsg_safe_strncpy(char *dst, const char *src, size_t length);

/**
 * Prevent compiler optimisations from combining public notify API methods.
 * The implementation is intentionally free of shared mutable state because
 * these APIs may be called concurrently.
 */
#if __has_attribute(not_tail_called)
#define BSG_NOT_TAIL_CALLED __attribute__((not_tail_called))
#else
#define BSG_NOT_TAIL_CALLED
#endif

void BSGPreventInlining(NSString * _Nullable tag)
    __attribute__((noinline)) BSG_NOT_TAIL_CALLED;

#if __has_attribute(disable_tail_calls)
#define BSG_KEEP_FUNCTION_IN_STACKTRACE __attribute__((disable_tail_calls))
#else
#define BSG_KEEP_FUNCTION_IN_STACKTRACE
#endif

#define BSG_THWART_TAIL_CALL_OPTIMISATION __asm__ __volatile__("");

NS_ASSUME_NONNULL_END

__END_DECLS
