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

/// Opens (or, with O_CREAT, creates) a file, returning -1 on error (with errno set).
///
/// The file is opened with O_CLOEXEC, so that the descriptor does not leak into child processes, and O_NOFOLLOW, so that
/// a symbolic link at the path is refused (ELOOP). New files are created with mode 0600. Nothing else is done: unlike
/// BSGOpenFileWithoutCompleteProtection, it neither reads nor changes the file's backup policy or protection class, so
/// it makes no NSURL calls.
int BSGOpenFileWithoutFollowingLinks(NSString *path, int flags);

/// Opens (or, with O_CREAT, creates) a file whose descriptor is kept open while the file is used, returning -1 on error
/// (with errno set).
///
/// Applies Bugsnag's backup policy to the file and changes NSFileProtectionComplete to NSFileProtectionCompleteUnlessOpen
/// (see BSGDisableNSFileProtectionComplete). If the protection class was not changed, the descriptor is returned only if
/// it still refers to the file at the path (compared by device and inode number); otherwise -1 is returned with errno set
/// to EAGAIN. If the protection class was changed, the file is reopened, so that the descriptor returned is normally one
/// opened after the change rather than under NSFileProtectionComplete. If the file is no longer at the path by then (it
/// was removed or renamed away after the first open), or a different file is at the path (the two descriptors are
/// compared by device and inode number), the descriptors are closed and -1 is returned with errno set to EAGAIN, so that
/// the caller can try again rather than use a file that is no longer at the path or whose protection class was not
/// checked. If it cannot be reopened for another reason (for example because the device locked between the two opens),
/// the first descriptor is returned instead, and a warning is logged: it was opened under NSFileProtectionComplete, so
/// reads and writes through it can start failing once the device is locked, and callers must handle a later read or
/// write failure. The file is opened as BSGOpenFileWithoutFollowingLinks opens it, so a symbolic link at the path is
/// refused (ELOOP). A file created here with O_EXCL is deleted if it cannot be set up. If the protection class cannot be
/// changed, errno is the POSIX error that caused it, or EPERM if there is none. Other failures are not logged here;
/// callers log them.
int BSGOpenFileWithoutCompleteProtection(NSString *path, int flags);

/// The protection class that BSGCreateFileWithoutCompleteProtection asks for when it creates a file in `directory`:
/// NSFileProtectionCompleteUnlessOpen if the directory's class is NSFileProtectionComplete, otherwise nil, meaning that
/// the file is created with the class it inherits from the directory (normally the app's default class).
NSString *_Nullable BSGProtectionClassForNewFileInDirectory(NSString *directory);

/// Creates a new, empty file and opens it, returning -1 on error (with errno set). Fails if anything, including a
/// symbolic link, is already at the path.
///
/// Only NSFileProtectionComplete is avoided, so that the descriptor returned, which callers keep open, stays usable
/// while the device is locked. On iOS, tvOS, watchOS and visionOS, a file in a directory whose class is
/// NSFileProtectionComplete is created with NSFileProtectionCompleteUnlessOpen (see
/// BSGProtectionClassForNewFileInDirectory), so that it never has NSFileProtectionComplete, even briefly. In any other
/// directory the file is created with the class it inherits (e.g. the default
/// NSFileProtectionCompleteUntilFirstUserAuthentication), which is kept: NSFileProtectionCompleteUnlessOpen is stricter
/// than that, because a file that has it cannot be opened again while the device is locked once it has been closed. On
/// macOS the file is created with the default class, which is then changed (and the file reopened) as
/// BSGOpenFileWithoutCompleteProtection does if it is NSFileProtectionComplete.
///
/// Creating a file while the device is locked. The file is created and closed, then opened again. In a directory whose
/// class is NSFileProtectionComplete, that second open fails while the device is locked (a closed
/// NSFileProtectionCompleteUnlessOpen file cannot be opened again until it is unlocked), so the file is deleted and -1
/// is returned (e.g. with EPERM): such a file can only be created once the device has been unlocked, and callers try
/// again then. In a directory with the default class, files can be created while the device is locked after the first
/// unlock.
///
/// Bugsnag's backup policy and the protection class are set here, once, when the file is created. They are attributes
/// of the file, which rename() keeps, so a file created here and renamed into place can later be opened with
/// BSGOpenFileWithoutFollowingLinks without setting them again.
///
/// `flags` are the flags to open the file with once it has been created (e.g. O_RDWR); O_CREAT, O_EXCL and O_TRUNC are
/// implied and ignored. The file has mode 0600, and it is deleted if it cannot be opened or set up. If it is removed
/// or renamed away while it is being set up, -1 is returned with errno set to EAGAIN (see
/// BSGOpenFileWithoutCompleteProtection). Nothing is logged here; callers log failures.
int BSGCreateFileWithoutCompleteProtection(NSString *path, int flags);

#if defined(DEBUG) && DEBUG
/// The functions that BSGChangeNSFileProtectionComplete (and so BSGOpenFileWithoutCompleteProtection) and
/// BSGProtectionClassForNewFileInDirectory use to read and change a protection class (an NSURLFileProtectionType), and
/// that BSGCreateFileWithoutCompleteProtection uses to create a file. For unit tests only (debug builds): they replace
/// them to simulate protection classes that cannot be set on the host, e.g. NSFileProtectionComplete while the device
/// is locked, or a file that cannot be created while it is locked.
typedef struct {
    /// Returns the protection class of a file or directory, or nil if it has none or it cannot be read.
    NSString *_Nullable (*_Nullable getProtection)(NSString *path);
    /// Sets the file's protection class, returning NO and setting `error` on failure.
    BOOL (*_Nullable setProtection)(NSString *path, NSString *protection, NSError *_Nullable *_Nullable error);
    /// Creates a new, empty file as BSGCreateFileWithoutCompleteProtection describes, failing if anything is at the
    /// path. Returns NO and sets errno on failure, e.g. EPERM when a file cannot be created because the device is locked.
    BOOL (*_Nullable createFile)(NSString *path);
} BSGFileProtectionFunctions;

/// Replaces the functions used to read and change protection classes (and to create files) and returns the ones that
/// were in use. A NULL member restores the default for that function. Each function is replaced atomically, so other
/// threads may call them meanwhile. For unit tests only. Only in debug builds.
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
