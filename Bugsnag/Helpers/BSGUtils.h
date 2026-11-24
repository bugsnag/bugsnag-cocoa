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
/// A file that must stay accessible while the device is locked (e.g. memory mapped) must be opened after this call,
/// and its descriptor kept open while it is used; closing it, even with a mapping left, gives that up.
BOOL BSGDisableNSFileProtectionComplete(NSString *path);

/// As BSGDisableNSFileProtectionComplete (failures are logged), also setting `changed` (if not NULL) to whether the
/// file had NSFileProtectionComplete and was changed; NO on error. A class that cannot be read counts as not Complete,
/// so the file is left as is; if it really is Complete, its descriptors can stop working once the device locks, which
/// callers handle as any other read or write failure.
BOOL BSGChangeNSFileProtectionComplete(NSString *path, BOOL *_Nullable changed);

/// Opens (or, with O_CREAT, creates with mode 0600) a file with O_CLOEXEC and O_NOFOLLOW (a symbolic link fails with
/// ELOOP), returning -1 with errno set on error. Makes no NSURL calls: the backup policy and protection class are
/// neither read nor changed.
int BSGOpenFileWithoutFollowingLinks(NSString *path, int flags);

/// Opens (or, with O_CREAT, creates) a file whose descriptor is kept open while it is used, as
/// BSGOpenFileWithoutFollowingLinks does (ELOOP for a symbolic link). Applies Bugsnag's backup policy and changes
/// NSFileProtectionComplete to NSFileProtectionCompleteUnlessOpen. Returns -1 with errno set on error; nothing is
/// logged (callers log). Files are compared by device and inode number.
/// - Class not changed: the descriptor is returned only if it is still the file at the path, else EAGAIN.
/// - Class changed: the file is reopened, so the descriptor was opened after the change. If the file has left the path
///   or a different file is there by then, EAGAIN, so the caller can try again. Any other reopen error (e.g. the device
///   locked between the opens) is returned as is: the first descriptor may stop working (or make a mapping fault) once
///   the device locks.
/// - Class cannot be changed: errno is the underlying POSIX error, or EPERM.
/// A file created here with O_EXCL is deleted if it cannot be set up.
int BSGOpenFileWithoutCompleteProtection(NSString *path, int flags);

/// The class BSGCreateFileWithoutCompleteProtection requests for a new file in `directory`:
/// NSFileProtectionCompleteUnlessOpen if the directory's class is NSFileProtectionComplete, else nil (inherited).
NSString *_Nullable BSGProtectionClassForNewFileInDirectory(NSString *directory);

/// Creates a new, empty file (mode 0600) and opens it with `flags` (e.g. O_RDWR; O_CREAT, O_EXCL and O_TRUNC are
/// implied and ignored). Returns -1 with errno set on error; nothing is logged. Fails if anything, even a symbolic
/// link, is at the path. The file is deleted if it cannot be opened or set up; EAGAIN if it is removed or renamed away
/// meanwhile.
///
/// Only NSFileProtectionComplete is avoided, so the descriptor (kept open by callers) works while the device is locked:
/// - iOS, tvOS, watchOS, visionOS: in a NSFileProtectionComplete directory the file is created with
///   NSFileProtectionCompleteUnlessOpen, never Complete even briefly. Elsewhere it keeps its inherited class (e.g.
///   NSFileProtectionCompleteUntilFirstUserAuthentication): CompleteUnlessOpen is stricter, as a closed file with it
///   cannot be reopened while the device is locked.
/// - macOS: created with the default class, changed (and reopened) as BSGOpenFileWithoutCompleteProtection does.
/// The file is created, closed and reopened, so in a NSFileProtectionComplete directory this fails while the device is
/// locked (e.g. EPERM) and the file is deleted; callers retry after the unlock. With the default class it works while
/// locked after the first unlock.
///
/// The backup policy and protection class are set once, here. rename() keeps them, so a file renamed into place can
/// later be opened with BSGOpenFileWithoutFollowingLinks.
int BSGCreateFileWithoutCompleteProtection(NSString *path, int flags);

#if defined(DEBUG) && DEBUG
/// The functions used to read and change a protection class (an NSURLFileProtectionType) and to create a file in
/// BSGCreateFileWithoutCompleteProtection. Unit tests replace them to simulate what the host cannot, e.g.
/// NSFileProtectionComplete while the device is locked, or a file that cannot be created while it is locked.
typedef struct {
    /// Returns the protection class of a file or directory, or nil if it has none or it cannot be read.
    NSString *_Nullable (*_Nullable getProtection)(NSString *path);
    /// Sets the file's protection class, returning NO and setting `error` on failure.
    BOOL (*_Nullable setProtection)(NSString *path, NSString *protection, NSError *_Nullable *_Nullable error);
    /// Creates a new, empty file, failing if anything is at the path. Returns NO with errno set on failure (e.g. EPERM
    /// while the device is locked).
    BOOL (*_Nullable createFile)(NSString *path);
} BSGFileProtectionFunctions;

/// Replaces the functions (a NULL member restores that default) and returns the previous ones. Each is replaced
/// atomically, so other threads may call them meanwhile. For unit tests only.
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
