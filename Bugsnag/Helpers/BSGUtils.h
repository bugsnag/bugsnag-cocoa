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
/// A file that must stay accessible while the device is locked (e.g. one that is memory mapped) must therefore be opened after calling this function
/// and its descriptor kept open for as long as it is used; closing the descriptor, even while a mapping remains, gives up that guarantee.
BOOL BSGDisableNSFileProtectionComplete(NSString *path);

/// As BSGDisableNSFileProtectionComplete, and also reports in `changed` (if not NULL) whether the protection class was
/// actually changed, i.e. whether the file had NSFileProtectionComplete. `changed` is NO when an error is returned.
///
/// A file whose protection class cannot be read is treated as not having NSFileProtectionComplete, so it is left as it
/// is. If it really has NSFileProtectionComplete, a descriptor opened for it can stop working once the device is locked,
/// which callers handle like any other read or write failure.
BOOL BSGChangeNSFileProtectionComplete(NSString *path, BOOL *_Nullable changed);

/// Opens (or, with O_CREAT, creates) a file whose descriptor is kept open while the file is used, returning -1 on error
/// (with errno set).
///
/// The file is opened with O_CLOEXEC and O_NOFOLLOW, so a symbolic link at the path is refused (ELOOP), and new files
/// get mode 0600. Applies Bugsnag's backup policy to the file and changes NSFileProtectionComplete to
/// NSFileProtectionCompleteUnlessOpen (see BSGDisableNSFileProtectionComplete); if that fails, errno is EPERM. If the
/// protection class was changed, the file is reopened, so that the descriptor returned was opened after the change. If
/// the file is no longer at the path by then, -1 is returned with errno set to EAGAIN, so that the caller can try again;
/// if it cannot be reopened for another reason, the first descriptor is returned.
int BSGOpenFileWithoutCompleteProtection(NSString *path, int flags);

#if defined(DEBUG) && DEBUG
/// The functions that BSGChangeNSFileProtectionComplete uses to read and change a file's protection class (an
/// NSURLFileProtectionType). For unit tests only (debug builds): they replace them to simulate protection classes that
/// cannot be set on the host, e.g. NSFileProtectionComplete while the device is locked.
typedef struct {
    /// Returns the file's protection class, or nil if it has none or it cannot be read.
    NSString *_Nullable (*_Nullable getProtection)(NSString *path);
    /// Sets the file's protection class, returning NO and setting `error` on failure.
    BOOL (*_Nullable setProtection)(NSString *path, NSString *protection, NSError *_Nullable *_Nullable error);
} BSGFileProtectionFunctions;

/// Replaces the functions used to read and change protection classes and returns the ones that were in use. A NULL
/// member restores the default for that function. For unit tests only; not thread safe. Only in debug builds.
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
