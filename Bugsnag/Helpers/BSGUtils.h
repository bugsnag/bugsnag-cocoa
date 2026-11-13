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
BOOL BSGChangeNSFileProtectionComplete(NSString *path, BOOL *_Nullable changed);

/// Opens (or, with O_CREAT, creates) a file whose descriptor is kept open while the file is used, returning -1 on error.
///
/// Applies Bugsnag's backup policy to the file and changes NSFileProtectionComplete to NSFileProtectionCompleteUnlessOpen
/// (see BSGDisableNSFileProtectionComplete). If the protection class was changed, the file is reopened, so that the
/// descriptor returned is normally one opened after the change rather than under NSFileProtectionComplete; the reopened
/// descriptor is only returned if it refers to the same file (device and inode) as the first one, and -1 is returned if
/// the path was replaced in between. If the file cannot be reopened (for example because the device locked between the
/// two opens), the first descriptor is returned instead: it was opened under NSFileProtectionComplete, so reads and
/// writes through it can start failing once the device is locked. Callers must therefore handle a later read or write
/// failure; BSGPersistentFeatureFlagStore does so by closing the descriptor and retrying through its usual retry. If
/// the class was not changed, the first descriptor is returned without reopening the file. Otherwise the file stays
/// accessible while the device is locked for as long as the descriptor stays open. Descriptors are opened with
/// O_CLOEXEC so that they do not leak into child processes, and with O_NOFOLLOW so that a symbolic link at the path is
/// refused. New files are created with mode 0600. A file created here with O_EXCL is deleted if it cannot be set up.
int BSGOpenFileWithoutCompleteProtection(NSString *path, int flags);

/// Creates a new, empty file and opens it as BSGOpenFileWithoutCompleteProtection does, returning -1 on error (with errno
/// set). Fails if anything, including a symbolic link, is already at the path.
///
/// On iOS, tvOS, watchOS and visionOS the file is created with NSFileProtectionCompleteUnlessOpen, so that it never has
/// NSFileProtectionComplete, even briefly. A file created with open() takes the app's default protection class, and if
/// that is NSFileProtectionComplete it cannot be created at all while the device is locked; a file created with
/// NSFileProtectionCompleteUnlessOpen can be. On macOS the file is created with the default class, which
/// BSGOpenFileWithoutCompleteProtection then changes if it is NSFileProtectionComplete.
///
/// `flags` are the flags to open the file with once it has been created (e.g. O_RDWR); O_CREAT, O_EXCL and O_TRUNC are
/// implied and ignored. The descriptor is only returned if it refers to the file that was created (same device and
/// inode, empty, with one link). The file has mode 0600, and it is deleted if it cannot be opened or set up.
int BSGCreateFileWithoutCompleteProtection(NSString *path, int flags);

/// The functions that BSGChangeNSFileProtectionComplete (and so BSGOpenFileWithoutCompleteProtection) uses to read and
/// change a file's protection class (an NSURLFileProtectionType), and that BSGCreateFileWithoutCompleteProtection uses to
/// create a file. For unit tests only: they replace them to simulate protection classes that cannot be set on the host,
/// e.g. NSFileProtectionComplete while the device is locked, or a file that cannot be created while it is locked.
typedef struct {
    /// Returns the file's protection class, or nil if it has none or it cannot be read.
    NSString *_Nullable (*_Nullable getProtection)(NSString *path);
    /// Sets the file's protection class, returning NO and setting `error` on failure.
    BOOL (*_Nullable setProtection)(NSString *path, NSString *protection, NSError *_Nullable *_Nullable error);
    /// Creates a new, empty file with NSFileProtectionCompleteUnlessOpen where the platform supports setting it at
    /// creation (see BSGCreateFileWithoutCompleteProtection), failing if anything is at the path. Returns NO and sets
    /// errno on failure, e.g. EPERM when a file cannot be created because the device is locked.
    BOOL (*_Nullable createFile)(NSString *path);
} BSGFileProtectionFunctions;

/// Replaces the functions used to read and change protection classes (and to create files) and returns the ones that were in use. A NULL
/// member restores the default for that function. For unit tests only; not thread safe.
BSGFileProtectionFunctions BSGSetFileProtectionFunctions(BSGFileProtectionFunctions functions);

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
