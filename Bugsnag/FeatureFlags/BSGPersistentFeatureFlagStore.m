//
//  BSGPersistentFeatureFlagStore.m
//  Bugsnag
//
//  Created by Robert B on 25/11/2024.
//  Copyright © 2024 Bugsnag. All rights reserved.
//

#import "BSGPersistentFeatureFlagStore.h"
#import "BugsnagInternals.h"
#import "BSGFeatureFlagFileFormat.h"
#import "BSGLegacyFeatureFlags.h"
#import "BSGUtils.h"
#import "BugsnagLogger.h"
#import <Foundation/Foundation.h>

#import <errno.h>
#import <fcntl.h>
#import <stddef.h>
#import <sys/file.h>
#import <sys/stat.h>
#import <unistd.h>

//
// Feature flags are persisted so that they are accessible at next launch if an OOM
// or thermal kill is detected. They are stored in featureflag.bin, whose format is described in
// BSGFeatureFlagFileFormat.h.
//
// The header records which slot holds the log and how long it is. It is updated with a single
// 8-byte write after the bytes it refers to have been written, so the file always holds a complete
// set of flags even if the process is killed during an update:
//
// - Adding, changing or clearing a flag writes a record after the end of the log, then
//   writes the longer length.
// - Clearing all flags, or a log that has grown to more than twice the size of the flags it
//   describes, writes a log of just the current flags into the other slot, then switches to it.
// - A log that no longer fits is written to a new, larger file, which is renamed over the
//   current one. Large files are also replaced with smaller ones when most of the flags are
//   cleared.
//
// The flags are read from the file when the store is created. A store that takes the lock later reads
// the header again then (see openExistingFile), but not the flags, because the flags in
// memory are the ones it saves. The file is changed with pwrite() through a file descriptor that is
// kept open. Data written with pwrite() is kept by the kernel even if the process is killed
// immediately afterwards. By design the file is not synchronised to disk (no fsync), so a power
// loss can lose recent changes, and can even leave the header on disk ahead of the records it
// refers to (zeros then decode as a flag with an empty name). That is accepted
// because a reboot stops BSGRunContext reporting an OOM or thermal kill for the launch before it.
// Every write error (e.g. a full disk) is an ordinary error: the flags stay in memory, the log in
// the file is emptied so that it never holds stale flags, and writing is tried again later, with
// the delay doubling after each failure up to a maximum. The exception is a log that has outgrown
// the file when a larger file cannot be created (see writeSnapshot): the file is intact, so its log
// of earlier flags is kept until the larger file is created.
//
// Only one store writes to a directory: the one that holds an exclusive lock on featureflag.lock (see
// BSGPersistentFeatureFlagStore.h). Nothing is created in the directory until there are flags to save.
//
// featureflag.bin is opened with BSGOpenRegularFile, which makes no NSURL calls: the files that become featureflag.bin
// are created by BSGCreateFileWithoutCompleteProtection, which sets the backup policy and the protection class once,
// and rename() keeps them. They are created with NSFileProtectionCompleteUnlessOpen, so they can be created while the
// device is locked even if the app's default class is Complete, and the descriptors kept open stay usable while it is
// locked. featureflag.lock is opened the same way, and created with BSGOpenFileWithoutCompleteProtection. A launch
// while the device is locked (before the first unlock, or in the background for an app whose default class is
// Complete) may not be able to open the existing files: it then neither reads the previous launch's flags nor takes the
// lock, and the file is kept (see "Files that cannot be opened" below). Symbolic links at the paths are never followed,
// and anything other than a regular file (e.g. a FIFO) is refused without blocking.
//
// Files that cannot be opened. Only a file whose header was read and is invalid, or something that is not a regular
// file, is ever deleted. A file that cannot be opened (EMFILE, ENFILE, EINTR, EAGAIN, or EACCES or EPERM while
// protected data is unavailable) may hold good flags, so it is kept, and a retry is scheduled to open it again. Its
// flags are not available for an OOM or thermal kill report of the previous launch. If this launch has flags to
// save, a new file is renamed over it as usual; if it has none, it is emptied in place once it can be opened. If that
// never happens during this launch, the next launch can read the flags of the launch before this one. That is
// accepted: the usual cause is that protected data stays unavailable, and then BSGRunContext cannot open its file
// either, so this launch's run context is not saved and no OOM or thermal kill is reported for it; the other causes
// (running out of descriptors, or an interrupted open) clear quickly, so the retry succeeds.
//
// Reading without the lock. A store that does not hold the lock reads the file while the store that holds it may be
// writing to it. Records are only ever written past the end of the active log or into the inactive slot, and the
// header that makes them part of a log is written after them, but between reading the header and reading the log the
// writer can rewrite the slot (switching to the other slot and back, possibly to the same length). So the log is read
// as follows, at most BSGFeatureFlagMaxConsistentReadAttempts times: the file's size and modification time are noted,
// the header is read, then the log, then the header again; if it changed the attempt is abandoned. Otherwise the log is
// decoded, read again, and compared byte for byte with the first read, and the size and modification time are
// checked again. A byte inside the active log can only change while the header does not include it, so a log that is
// accepted was either not written to at all while it was read, or was rewritten with exactly the same bytes, and in
// both cases it is the log that the header named. If no attempt succeeds, the flags are treated as unavailable for this
// launch: they are not reported as corrupt and nothing is deleted.
//
// State. The main fields, what they mean, and how they change:
//
//   lockFd             -1, or the descriptor of featureflag.lock while this store holds the lock. Set once, by
//                      takeLockIfPossible (when the store is created if there are files to read or delete, otherwise
//                      before the first write); closed only in dealloc.
//   lockGivenUp        Set when the lock will never be taken: another live store holds it (EWOULDBLOCK), or
//                      featureflag.lock cannot be opened for a reason that does not clear (e.g. it is a symbolic link).
//                      Never cleared. Logged once, when it is set.
//   fd                 -1, or the descriptor of featureflag.bin open for writing (only while holding the lock). Set
//                      when the file is read or opened after taking the lock (openExistingFile) or replaced
//                      (replaceFileWithSnapshot); cleared by a write failure, or a failure to empty the log.
//   slotCapacity,      The file's slot capacity, and the active slot and log length, as last read or written by this
//   activeSlot,        store. Only meaningful while fd is not -1.
//   activeLength
//   fileIsCurrent      Replaying the file's log gives exactly the encodable flags, so records can be appended. Set by a
//                      successful write of a whole log, or when a valid file is read; cleared by any failure, by flags
//                      that are over the size limit, and when another store's file is taken over.
//   keepingEarlierLog  The file is not current but its log holds an earlier set of this store's flags, kept because the
//                      flags no longer fit and a larger file could not be created yet. Cleared by the next write that
//                      succeeds, or when the log is emptied.
//   staleFileMayExist  A file that this store does not have open may be at the path and hold flags that are not
//                      current (e.g. the previous launch's, read by a store without the lock, or a file that could not
//                      be opened). Cleared once it has been opened, replaced or removed.
//   pendingLegacyPaths JSON files whose flags were imported (or discarded) but which have not been deleted yet. They
//                      are deleted by the first write after the flags are imported, which is normally when Bugsnag
//                      starts, so that featureflag.bin and JSON files are not both kept.
//   tooLargeToPersist  The flags were last over BSGFeatureFlagMaxPersistedLength (so that is only logged once).
//   retryTime,         After a failure, the uptime before which the file is not replaced, the lock not tried and a
//   retryDelay,        file that could not be opened not opened again; the delay used (doubling up to the maximum);
//   retryGeneration    and which scheduled retry is current. Reset by a success; the delay is shortened by a change to
//                      the flags (flagsDidChange), and replaceAllFlags (Bugsnag starting) tries again at once.
//   waitingForProtectedData  The last failure was EACCES or EPERM, as while protected data is unavailable, so that
//                      UIApplicationProtectedDataDidBecomeAvailable tries again before the retry time.
//


// A log is rewritten once the records it no longer needs take up more than this, or than the
// records it needs, whichever is larger.
static const uint64_t BSGFeatureFlagMinimumCompactionSize = 4096;
// Files with slots at least this large are replaced with smaller ones when they are mostly empty.
static const uint64_t BSGFeatureFlagMinimumShrinkableCapacity = 256 * 1024;
// How long to wait before trying to write the file (or take the lock) again after it could not be done.
// The delay doubles after each consecutive failure, up to the maximum, so that a failure that never
// clears (e.g. a directory at the file's path, or a read-only volume) is not repeated every minute.
static const NSTimeInterval BSGFeatureFlagRetryInterval = 60;
static const NSTimeInterval BSGFeatureFlagMaximumRetryInterval = 60 * 60;
// How many times a store without the lock reads the log before giving up because it kept changing
static const NSUInteger BSGFeatureFlagMaxConsistentReadAttempts = 8;

static NSString * const BSGFeatureFlagFileName = @"featureflag.bin";
static NSString * const BSGFeatureFlagLockFileName = @"featureflag.lock";
// The name used by pre-release builds of this format, whose files are deleted (with their temporary files).
// No released version wrote it; it is only on test and development devices that ran those builds. This name, and
// its handling in isObsoleteFile:, can be removed one release after featureflag.bin is first released.
static NSString * const BSGFeatureFlagPrereleaseFileName = @"flags.bin";

// flock(), unless a unit test replaces it (see BSGSetFeatureFlagLockFunction)
static BSGFeatureFlagLockFunction bsg_featureFlagLockFunction = flock;

BSGFeatureFlagLockFunction BSGSetFeatureFlagLockFunction(BSGFeatureFlagLockFunction _Nullable function) {
    const BSGFeatureFlagLockFunction previous = bsg_featureFlagLockFunction;
    bsg_featureFlagLockFunction = function ?: flock;
    return previous;
}

// Called between reading the header and the log, if a unit test sets it (see BSGSetFeatureFlagReadHook)
static BSGFeatureFlagReadHook bsg_featureFlagReadHook;

BSGFeatureFlagReadHook BSGSetFeatureFlagReadHook(BSGFeatureFlagReadHook _Nullable hook) {
    const BSGFeatureFlagReadHook previous = bsg_featureFlagReadHook;
    bsg_featureFlagReadHook = hook;
    return previous;
}

/// Reads the header of an open featureflag.bin, returning whether it is valid and the file is large enough for it.
static BOOL BSGFeatureFlagFileReadHeader(int fd, struct bsg_feature_flag_file_header *header) {
    struct stat st;
    return (fstat(fd, &st) == 0 &&
            BSGFeatureFlagFileRead(fd, header, sizeof(*header), 0) &&
            header->magic == BSGFeatureFlagFileMagic &&
            header->version == BSGFeatureFlagFileVersion &&
            header->slotCapacity > 0 &&
            header->slotCapacity <= BSGFeatureFlagMaxReadableSlotCapacity &&
            (uint64_t)st.st_size >= BSGFeatureFlagFileSize(header->slotCapacity));
}

/// Reads `length` bytes into a new buffer, returning nil if they cannot all be read.
static NSData * BSGFeatureFlagFileReadData(int fd, uint64_t length, uint64_t offset) {
    void *bytes = malloc(MAX((size_t)length, 1));
    if (!bytes || !BSGFeatureFlagFileRead(fd, bytes, length, offset)) {
        free(bytes);
        return nil;
    }
    return [NSData dataWithBytesNoCopy:bytes length:(NSUInteger)length freeWhenDone:YES];
}

/// Whether the file is the same, and has not been written to, as far as fstat() can tell.
static BOOL BSGFeatureFlagFileIsUnchanged(const struct stat *before, const struct stat *after) {
    return (before->st_dev == after->st_dev && before->st_ino == after->st_ino && before->st_size == after->st_size &&
            before->st_mtimespec.tv_sec == after->st_mtimespec.tv_sec &&
            before->st_mtimespec.tv_nsec == after->st_mtimespec.tv_nsec);
}

typedef NS_ENUM(NSInteger, BSGFeatureFlagPathType) {
    BSGFeatureFlagPathMissing,  // Nothing is at the path
    BSGFeatureFlagPathFile,     // A regular file is at the path (or it could not be examined, so it may be)
    BSGFeatureFlagPathNotAFile, // Something other than a regular file, e.g. a directory, FIFO or symbolic link
};

/// What is at a path, without following a symbolic link. Something other than a regular file cannot hold flags.
static BSGFeatureFlagPathType BSGFeatureFlagPathTypeAt(NSString *path) {
    struct stat st;
    if (lstat(path.fileSystemRepresentation, &st) != 0) {
        return errno == ENOENT ? BSGFeatureFlagPathMissing : BSGFeatureFlagPathFile;
    }
    return S_ISREG(st.st_mode) ? BSGFeatureFlagPathFile : BSGFeatureFlagPathNotAFile;
}

/// Whether opening (or creating) featureflag.lock failed for a reason that can clear during this launch, such as
/// protected data being unavailable (EACCES, EPERM), too many open files, or a full disk. Other errors (e.g. ELOOP
/// for a symbolic link, EFTYPE for a FIFO, or a read-only volume) do not clear, so the lock is not tried again.
static BOOL BSGFeatureFlagIsTransientOpenError(int error) {
    switch (error) {
        case EACCES: case EPERM: case EMFILE: case ENFILE: case EINTR: case EAGAIN:
        case ENOSPC: case EDQUOT: case ENOMEM: case EIO: case ENOENT:
            return YES;
        default:
            return NO;
    }
}

#pragma mark -

typedef NS_ENUM(NSInteger, BSGFeatureFlagFileState) {
    BSGFeatureFlagFileMissing,     // There is no featureflag.bin
    BSGFeatureFlagFileNotAFile,    // Something other than a regular file is at the path
    BSGFeatureFlagFileUnavailable, // featureflag.bin could not be opened, or (without the lock) read consistently, now
    BSGFeatureFlagFileInvalid,     // Its header is invalid
    BSGFeatureFlagFileCorrupt,     // The header is valid but the log is not
    BSGFeatureFlagFileLoaded,      // The flags were read from the log
};

@interface BSGPersistentFeatureFlagStore ()

@property (nonatomic, strong) NSString *directoryPath;
@property (nonatomic, strong) NSString *filePath;

// The names of the flags in the order BSGMemoryFeatureFlagStore keeps them (the order they were first
// added since they were last cleared), which is also the order of their records in a rewritten log
@property (nonatomic, strong) NSMutableOrderedSet<NSString *> *names;
// The encoded record of each flag that can be persisted
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSData *> *recordsByName;
// Flags that cannot be encoded, which are kept in memory but not persisted
@property (nonatomic, strong) NSMutableDictionary<NSString *, BugsnagFeatureFlag *> *unencodableFlags;
// The total length of recordsByName, i.e. of a log holding just the current flags
@property (nonatomic) uint64_t liveLength;
// Set when a change cannot be appended to the log without changing the order of the flags when it
// is replayed, so that a new log must be written instead
@property (nonatomic) BOOL needsSnapshot;

// See the state table at the top of this file
@property (nonatomic) int lockFd;
@property (nonatomic) BOOL lockGivenUp;
@property (nonatomic) int fd;
@property (nonatomic) uint64_t slotCapacity;
@property (nonatomic) uint32_t activeSlot;
@property (nonatomic) uint64_t activeLength;
@property (nonatomic) BOOL fileIsCurrent;
@property (nonatomic) BOOL keepingEarlierLog;
@property (nonatomic) BOOL tooLargeToPersist;
@property (nonatomic) NSTimeInterval retryTime;
// The delay after the first failure, and the largest delay after consecutive failures
@property (nonatomic) NSTimeInterval retryInterval;
@property (nonatomic) NSTimeInterval maximumRetryInterval;
@property (nonatomic) NSTimeInterval retryDelay;
@property (nonatomic) NSUInteger retryGeneration;
@property (nonatomic) BOOL waitingForProtectedData;
@property (nonatomic) BOOL staleFileMayExist;
@property (nonatomic, strong) NSArray<NSString *> *pendingLegacyPaths;
// Observes UIApplicationProtectedDataDidBecomeAvailable
@property (nonatomic, strong, nullable) id protectedDataObserver;

@end


@implementation BSGPersistentFeatureFlagStore

- (nonnull instancetype)initWithStorageDirectory:(NSString *)directory {
    if ((self = [super init]) != nil) {
        _directoryPath = directory;
        _filePath = [directory stringByAppendingPathComponent:BSGFeatureFlagFileName];
        _retryInterval = BSGFeatureFlagRetryInterval;
        _maximumRetryInterval = BSGFeatureFlagMaximumRetryInterval;
        _names = [NSMutableOrderedSet orderedSet];
        _recordsByName = [NSMutableDictionary dictionary];
        _unencodableFlags = [NSMutableDictionary dictionary];
        _pendingLegacyPaths = @[];
        _fd = -1;
        _lockFd = -1;
        [self loadFlags];
        [self observeProtectedData];
    }
    return self;
}

- (void)dealloc {
    id observer = _protectedDataObserver;
    if (observer) {
        [NSNotificationCenter.defaultCenter removeObserver:observer];
    }
    if (_fd != -1) {
        close(_fd);
    }
    if (_lockFd != -1) {
        // Closing the descriptor releases the lock
        close(_lockFd);
    }
}

#pragma mark - BSGFeatureFlagStore

- (nonnull NSArray<BugsnagFeatureFlag *> *)allFlags {
    @synchronized (self) {
        NSMutableArray<BugsnagFeatureFlag *> *flags = [NSMutableArray arrayWithCapacity:self.names.count];
        for (NSString *name in self.names) {
            NSData *record = self.recordsByName[name];
            BugsnagFeatureFlag *flag = record ? BSGFeatureFlagDecodeRecord(record) : self.unencodableFlags[name];
            if (flag) {
                [flags addObject:flag];
            }
        }
        return flags;
    }
}

- (BOOL)isEmpty {
    @synchronized (self) {
        return self.names.count == 0;
    }
}

- (void)addFeatureFlag:(nonnull NSString *)name withVariant:(nullable NSString *)variant {
    @synchronized (self) {
        [self saveChange:[self setFlagNamed:name variant:variant]];
    }
}

- (void)addFeatureFlags:(nonnull NSArray<BugsnagFeatureFlag *> *)featureFlags {
    @synchronized (self) {
        NSMutableData *records = [NSMutableData data];
        for (BugsnagFeatureFlag *flag in featureFlags) {
            [records appendData:[self setFlagNamed:flag.name variant:flag.variant]];
        }
        [self saveChange:records];
    }
}

- (void)replaceAllFlags:(NSArray<BugsnagFeatureFlag *> *)featureFlags {
    @synchronized (self) {
        // The records whose log the file holds, if it is current
        NSArray<NSData *> *savedRecords = self.fd != -1 && self.fileIsCurrent ? [self orderedRecords] : nil;
        [self removeAllFlagsFromMemory];
        for (BugsnagFeatureFlag *flag in featureFlags) {
            [self setFlagNamed:flag.name variant:flag.variant];
        }
        self.needsSnapshot = NO;
        if (savedRecords && [savedRecords isEqualToArray:[self orderedRecords]] && ![self fileShouldShrink]) {
            // The file's log already gives these flags (as it does when Bugsnag starts with the flags it had when
            // the previous launch ended), so nothing is written. The flags in memory were re-encoded above, so the
            // log read when the store was created is no longer referenced. A file that should be shrunk is still
            // rewritten, so that it is shrunk when Bugsnag starts at the latest.
            [self removePendingLegacyFiles];
            return;
        }
        // This is called when Bugsnag starts, so it is not delayed by an earlier failure (e.g. when the
        // store was created). If it fails, a retry is scheduled. The lock is not tried again if it was given up.
        self.retryTime = 0;
        self.retryDelay = 0;
        // A single log is published so that the file never holds an empty or partial set
        [self writeSnapshot];
    }
}

- (void)clear:(nullable NSString *)name {
    if (name == nil) {
        [self clear];
        return;
    }
    @synchronized (self) {
        if ([self.names containsObject:(NSString *_Nonnull)name]) {
            BOOL persisted = self.recordsByName[(NSString *_Nonnull)name] != nil;
            [self.names removeObject:(NSString *_Nonnull)name];
            [self.unencodableFlags removeObjectForKey:(NSString *_Nonnull)name];
            [self setRecord:nil forName:(NSString *_Nonnull)name];
            [self flagsDidChange];
            if (persisted) {
                [self appendRecords:BSGFeatureFlagEncodeRemoval((NSString *_Nonnull)name) ?: [NSData data]];
            }
        }
    }
}

- (void)clear {
    @synchronized (self) {
        if (self.names.count) {
            [self flagsDidChange];
        }
        [self removeAllFlagsFromMemory];
        [self writeSnapshot];
    }
}

#pragma mark - Private methods

/// Takes the lock that allows this store to write to the directory, returning its descriptor or -1.
/// flock() locks belong to an open file description, so two stores in the same process conflict just as
/// two processes (e.g. two instances of a macOS app) do. The lock is on a separate file because featureflag.bin
/// is replaced by renaming another file over it.
///
/// If another store holds the lock (EWOULDBLOCK), it holds it until it is deallocated, which for a client is the
/// lifetime of the process, so that is logged once and the lock is never tried again (lockGivenUp). The same applies
/// if featureflag.lock cannot be opened for a reason that does not clear. Other failures (e.g. featureflag.lock
/// cannot be opened while protected data is unavailable) are tried again later.
///
/// A file system that does not support flock() (ENOTSUP or EOPNOTSUPP, e.g. an NFS volume without a lock daemon)
/// cannot tell two stores apart, so this store proceeds as the only writer, as the JSON files written by earlier
/// versions of the SDK did, rather than never saving the flags. That is logged once, and the descriptor is kept as
/// though it held the lock.
- (int)acquireLock {
    NSString *path = [self.directoryPath stringByAppendingPathComponent:BSGFeatureFlagLockFileName];
    // An existing lock file is opened without NSURL calls; one is only created (with the backup policy and protection
    // class applied) when it is missing
    int fd = BSGOpenRegularFile(path, O_RDONLY);
    if (fd == -1 && errno == ENOENT) {
        fd = BSGOpenFileWithoutCompleteProtection(path, O_RDONLY | O_CREAT);
    }
    if (fd == -1) {
        const int error = errno;
        if (BSGFeatureFlagIsTransientOpenError(error)) {
            bsg_log_warn(@"Could not open %@ (%d); persisting feature flags will be tried again later",
                         path.lastPathComponent, error);
            [self recordFailure:error];
        } else {
            bsg_log_warn(@"Could not open %@ (%d); feature flags will not be persisted", path.lastPathComponent, error);
            self.lockGivenUp = YES;
        }
        return -1;
    }
    if (bsg_featureFlagLockFunction(fd, LOCK_EX | LOCK_NB) != 0) {
        const int error = errno;
        if (error == ENOTSUP || error == EOPNOTSUPP) {
            bsg_log_warn(@"%@ cannot be locked on this volume (%d); persisting feature flags without a lock",
                         path.lastPathComponent, error);
            return fd;
        }
        if (error == EWOULDBLOCK) {
            bsg_log_info(@"Feature flags will not be persisted because another Bugsnag client is using %@",
                         self.directoryPath.lastPathComponent);
            self.lockGivenUp = YES;
        } else {
            bsg_log_warn(@"Could not lock %@: %d", path.lastPathComponent, error);
            [self recordFailure:error];
        }
        close(fd);
        return -1;
    }
    return fd;
}

/// Whether this store holds the lock, and so can write to the directory.
- (BOOL)canWrite {
    return self.lockFd != -1;
}

/// Takes the lock if this store does not hold it yet, trying at most once per retry interval after a failure
/// (e.g. while the device is locked), and never again once it has been given up. Returns whether the store holds it.
- (BOOL)takeLockIfPossible {
    if (self.canWrite) {
        return YES;
    }
    if (self.lockGivenUp || NSProcessInfo.processInfo.systemUptime < self.retryTime) {
        return NO;
    }
    self.lockFd = [self acquireLock];
    if (!self.canWrite) {
        if (!self.lockGivenUp) {
            [self retryLater];
        }
        return NO;
    }
    [self resetRetry];
    return YES;
}

/// Takes the lock before a write if this store does not hold it yet. A store that takes the lock after it
/// was created did not prepare the directory when it read it, and another store may have written to it since,
/// so the directory is examined again. The flags in memory are not changed: an OOM event for the previous
/// launch was built from them when Bugsnag started, and they are the flags this store saves.
- (BOOL)prepareToWrite {
    if (self.canWrite) {
        return YES;
    }
    if (![self takeLockIfPossible]) {
        return NO;
    }
    NSArray<NSString *> *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.directoryPath error:nil];
    for (NSString *file in files) {
        if ([self isObsoleteFile:file]) {
            unlink([self.directoryPath stringByAppendingPathComponent:file].fileSystemRepresentation);
        }
    }
    [self openExistingFile];
    return YES;
}

/// Opens featureflag.bin for writing while holding the lock, if it has a valid header, so that its log can be
/// replaced in place (by writeSnapshot, because the file is not current). This is done when the lock is taken after
/// the store was created, and to retry a file that could not be opened earlier.
///
/// A file whose header is invalid holds no flags that can be read, and is removed. Something other than a regular
/// file holds no flags either; it is left alone, and replaced when the flags are next saved. A file that cannot be
/// opened (e.g. while protected data is unavailable) may hold good flags, so it is kept (see "Files that cannot be
/// opened" at the top of this file).
- (void)openExistingFile {
    if (BSGFeatureFlagPathTypeAt(self.filePath) != BSGFeatureFlagPathFile) {
        self.staleFileMayExist = NO;
        return;
    }
    const int fd = BSGOpenRegularFile(self.filePath, O_RDWR);
    if (fd == -1) {
        const int error = errno;
        if (error == ENOENT || error == ELOOP || error == EFTYPE) {
            // It was removed, or replaced with something other than a regular file, after lstat()
            self.staleFileMayExist = NO;
            return;
        }
        bsg_log_warn(@"Could not open %@ (%d); it is kept and will be tried again later", self.filePath.lastPathComponent, error);
        [self recordFailure:error];
        self.staleFileMayExist = YES;
        return;
    }
    struct bsg_feature_flag_file_header header;
    if (!BSGFeatureFlagFileReadHeader(fd, &header)) {
        close(fd);
        self.staleFileMayExist = unlink(self.filePath.fileSystemRepresentation) != 0 && errno != ENOENT;
        return;
    }
    self.fd = fd;
    self.slotCapacity = header.slotCapacity;
    self.activeSlot = header.active & 1;
    self.activeLength = header.active >> 1;
    self.fileIsCurrent = NO;
    // The log holds another store's (or an earlier launch's) flags, which are never kept in place of this store's
    self.keepingEarlierLog = NO;
    self.staleFileMayExist = NO;
}

/// Whether a file in the directory is one that the store holding the lock deletes when it reads the directory.
- (BOOL)isObsoleteFile:(NSString *)file {
    NSString *temporaryFilePrefix = [BSGFeatureFlagFileName stringByAppendingString:@"."];
    NSString *prereleaseTemporaryFilePrefix = [BSGFeatureFlagPrereleaseFileName stringByAppendingString:@"."];
    // Temporary files are left behind by a process that was killed while replacing featureflag.bin. Only the
    // store that holds the lock writes them, so none of them is in use. Pre-release builds used a different
    // file name; the flags in their files are not read. (The pre-release files can stop being deleted one
    // release after featureflag.bin is first released; see BSGFeatureFlagPrereleaseFileName.)
    return (([file hasPrefix:temporaryFilePrefix] && [file.pathExtension isEqualToString:@"tmp"]) ||
            [file isEqualToString:BSGFeatureFlagPrereleaseFileName] ||
            ([file hasPrefix:prereleaseTemporaryFilePrefix] && [file.pathExtension isEqualToString:@"tmp"]));
}

/// Deletes the JSON files whose flags were imported or discarded.
///
/// Imported JSON files are deleted by the first write after they were imported, once the flags have been written
/// (normally when Bugsnag starts), rather than when the store is created, so that importing them does not write a
/// file that is replaced a few milliseconds later. They are deleted even if the flags could not be written, because
/// they would be stale if imported again at the next launch.
///
/// A JSON file that could not be deleted is found next to featureflag.bin at the next launch, and then both are
/// discarded, because that cannot be told apart from both kinds of file being left by a downgrade and an upgrade in
/// which one of them could not be deleted. Recording the import in the header is not safe: the reserved fields are
/// fixed when a file is created (see BSGFeatureFlagFileFormat.h), and a file is kept and written in place for many
/// launches, so a marker would still be set when a later downgrade and upgrade leaves newer JSON files next to it,
/// which would then be ignored in favour of stale flags. Modification times are not reliable either, because the
/// clock can change. Deleting the files is therefore tried again whenever a log is written, which makes the case
/// very unlikely.
- (void)removePendingLegacyFiles {
    if (self.pendingLegacyPaths.count && self.canWrite) {
        self.pendingLegacyPaths = BSGRemoveLegacyFeatureFlagFiles(self.pendingLegacyPaths);
    }
}

/// Tries again when protected data becomes available (the device is unlocked), because a store whose last attempt
/// failed while it was unavailable could not take the lock, open the file, or create a new one.
- (void)observeProtectedData {
#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION
    __weak typeof(self) weakSelf = self;
    self.protectedDataObserver =
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationProtectedDataDidBecomeAvailable
                                                    object:nil queue:nil usingBlock:^(__unused NSNotification *note) {
        // Posted on the main thread; the file is written in the background
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            [weakSelf protectedDataDidBecomeAvailable];
        });
    }];
#endif
}

/// Only does anything if there is something to save and the last attempt failed in a way that protected data
/// becoming available can resolve. The lock is never tried again once it has been given up, and the retry delay is
/// not reset, so it keeps doubling if this attempt fails too.
- (void)protectedDataDidBecomeAvailable {
    @synchronized (self) {
        if (self.waitingForProtectedData && [self hasPendingWork]) {
            self.retryTime = 0;
            [self writeSnapshot];
        }
    }
}

/// Whether the file does not hold the current flags and a write could change that: there are flags to save (within
/// the size limit), a file this store has open whose log is not current, a file that may hold stale flags, or JSON
/// files to delete. False once the lock has been given up, because this store can then never write.
- (BOOL)hasPendingWork {
    if (self.lockGivenUp || self.fileIsCurrent) {
        return NO;
    }
    if (self.staleFileMayExist || self.pendingLegacyPaths.count) {
        return YES;
    }
    if (self.liveLength > BSGFeatureFlagMaxPersistedLength) {
        // Nothing a retry can save; the log of a file this store has open was emptied when they went over the limit
        return NO;
    }
    return self.liveLength > 0 || (self.fd != -1 && self.activeLength > 0);
}

/// Reads the flags saved by the previous launch, or imports them from JSON files. Nothing is written: the flags are
/// written by the next change, normally replaceAllFlags when Bugsnag starts. Files that hold no flags that can be
/// used are removed. A store that does not hold the lock reads the flags but changes nothing in the directory.
- (void)loadFlags {
    const BOOL fileExists = BSGFeatureFlagPathTypeAt(self.filePath) != BSGFeatureFlagPathMissing;
    NSArray<NSString *> *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.directoryPath error:nil];
    NSMutableArray<NSString *> *obsoletePaths = [NSMutableArray array];
    NSMutableArray<NSString *> *legacyPaths = [NSMutableArray array];
    for (NSString *file in files) {
        NSString *path = [self.directoryPath stringByAppendingPathComponent:file];
        if ([self isObsoleteFile:file]) {
            [obsoletePaths addObject:path];
        } else if (BSGIsLegacyFeatureFlagFile(file)) {
            [legacyPaths addObject:path];
        }
    }

    if (fileExists || obsoletePaths.count || legacyPaths.count) {
        // There are files to read or delete, so the lock is taken now. Otherwise it is taken before the first
        // write, so that nothing is created in the directory of an app that never has flags to save.
        [self takeLockIfPossible];
    }
    if (self.canWrite) {
        for (NSString *path in obsoletePaths) {
            unlink(path.fileSystemRepresentation);
        }
    } else if (fileExists) {
        // The file holds the previous launch's flags, which this store may later need to replace
        self.staleFileMayExist = YES;
    }

    const BSGFeatureFlagFileState state = fileExists ? [self readExistingFile] : BSGFeatureFlagFileMissing;
    // Both kinds of file are only left together when one of them could not be deleted after the SDK was downgraded
    // and upgraded again, or after the JSON files were imported (see removePendingLegacyFiles). It is not known which
    // of them is current, so neither is used. (Something other than a file at the path, such as a directory or a
    // symbolic link, cannot hold flags, so the JSON files next to it are imported.)
    const BOOL foundBoth = legacyPaths.count && state != BSGFeatureFlagFileMissing && state != BSGFeatureFlagFileNotAFile;
    if (foundBoth) {
        bsg_log_info(@"Discarding persisted feature flags because both featureflag.bin and JSON files were found");
    }
    BOOL imported = NO;
    switch (state) {
        case BSGFeatureFlagFileLoaded:
        case BSGFeatureFlagFileCorrupt:
            if (foundBoth || state == BSGFeatureFlagFileCorrupt) {
                if (!foundBoth) {
                    bsg_log_err(@"Persisted feature flags are corrupt; discarding them");
                }
                [self removeAllFlagsFromMemory];
                // Publish an empty log so that the discarded flags are not reported later, and new records are not
                // appended to a corrupt log
                [self writeSnapshot];
            } else {
                // This file can be older than the previous launch: SDK versions before 6.31.0 never touch this
                // directory, so it survives a downgrade to one of them and an upgrade again. Its flags are not
                // reported for that launch, because an app upgrade changes the Mach-O UUID and BSGRunContext
                // then does not report an OOM or thermal kill. They are replaced when Bugsnag starts.
                self.fileIsCurrent = self.fd != -1;
            }
            break;
        case BSGFeatureFlagFileInvalid:
            // No flags can be read from it, and it is removed rather than replaced: it holds the flags of an earlier
            // launch, which must not be reported later
            if (self.canWrite && unlink(self.filePath.fileSystemRepresentation) != 0 && errno != ENOENT) {
                self.staleFileMayExist = YES;
            }
            break;
        case BSGFeatureFlagFileUnavailable:
            // Kept, because it may hold good flags (see "Files that cannot be opened" at the top of this file)
            self.staleFileMayExist = YES;
            if (self.canWrite) {
                [self retryLater];
            }
            break;
        case BSGFeatureFlagFileMissing:
        case BSGFeatureFlagFileNotAFile:
            // Flags written as individual files by earlier versions of the SDK are imported so that they can be
            // included in an OOM event (see BSGLegacyFeatureFlags.h). They are written, and the JSON files deleted,
            // by the next write (see removePendingLegacyFiles).
            for (BugsnagFeatureFlag *flag in BSGLegacyFeatureFlags(legacyPaths)) {
                [self setFlagNamed:flag.name variant:flag.variant];
                imported = YES;
            }
            self.needsSnapshot = NO;
            break;
    }
    // Files that cannot be deleted now (or by a store that does not hold the lock yet) are deleted by a later write
    self.pendingLegacyPaths = legacyPaths;
    if (!imported) {
        [self removePendingLegacyFiles];
    }
}

/// Reads the log in featureflag.bin into memory. A store that holds the lock keeps the file open for writing
/// if its header is valid. Failing to open the file is logged separately from a corrupt file.
- (BSGFeatureFlagFileState)readExistingFile {
    switch (BSGFeatureFlagPathTypeAt(self.filePath)) {
        case BSGFeatureFlagPathMissing: return BSGFeatureFlagFileMissing;
        case BSGFeatureFlagPathNotAFile: return BSGFeatureFlagFileNotAFile;
        case BSGFeatureFlagPathFile: break;
    }
    const int fd = BSGOpenRegularFile(self.filePath, self.canWrite ? O_RDWR : O_RDONLY);
    if (fd == -1) {
        const int error = errno;
        if (error == ENOENT) {
            return BSGFeatureFlagFileMissing;
        }
        if (error == ELOOP || error == EFTYPE) {
            return BSGFeatureFlagFileNotAFile;
        }
        bsg_log_warn(@"Could not open %@ (%d); the persisted feature flags are not available for this launch",
                     self.filePath.lastPathComponent, error);
        [self recordFailure:error];
        return BSGFeatureFlagFileUnavailable;
    }
    struct bsg_feature_flag_file_header header;
    const BSGFeatureFlagFileState state = [self readLogInFile:fd header:&header];
    if (state == BSGFeatureFlagFileInvalid) {
        bsg_log_err(@"Persisted feature flags are corrupt or in an unknown format; discarding them");
    } else if (state == BSGFeatureFlagFileUnavailable) {
        bsg_log_info(@"Persisted feature flags are not available for this launch because another Bugsnag client "
                     "kept changing them while they were being read");
    }
    if (self.canWrite && (state == BSGFeatureFlagFileLoaded || state == BSGFeatureFlagFileCorrupt)) {
        self.fd = fd;
        self.slotCapacity = header.slotCapacity;
        self.activeSlot = header.active & 1;
        self.activeLength = header.active >> 1;
    } else {
        close(fd);
    }
    return state;
}

/// Reads and decodes the active log, and on success replaces the flags in memory with its flags. A store that does
/// not hold the lock checks that the log did not change while it was read (see "Reading without the lock" at the
/// top of this file), and returns BSGFeatureFlagFileUnavailable if it kept changing.
- (BSGFeatureFlagFileState)readLogInFile:(int)fd header:(struct bsg_feature_flag_file_header *)header {
    const BOOL verify = !self.canWrite;
    const NSUInteger attempts = verify ? BSGFeatureFlagMaxConsistentReadAttempts : 1;
    for (NSUInteger attempt = 0; attempt < attempts; attempt++) {
        struct stat before;
        if (verify && fstat(fd, &before) != 0) {
            return BSGFeatureFlagFileUnavailable;
        }
        if (!BSGFeatureFlagFileReadHeader(fd, header)) {
            return BSGFeatureFlagFileInvalid;
        }
        const uint64_t length = header->active >> 1;
        const uint64_t offset = BSGFeatureFlagSlotOffset(header->slotCapacity, header->active & 1);
        if (length > header->slotCapacity) {
            // The header is written with a single write, so this is not a value read part way through a change
            return BSGFeatureFlagFileCorrupt;
        }
        if (bsg_featureFlagReadHook) {
            bsg_featureFlagReadHook();
        }
        // Only the active log is read; its length is limited by the slot capacity, which was checked above
        NSData *log = BSGFeatureFlagFileReadData(fd, length, offset);
        if (verify) {
            struct bsg_feature_flag_file_header again;
            if (!log || !BSGFeatureFlagFileReadHeader(fd, &again) || again.active != header->active) {
                continue;
            }
        }
        NSMutableOrderedSet<NSString *> *names = [NSMutableOrderedSet orderedSet];
        NSMutableDictionary<NSString *, NSData *> *records = [NSMutableDictionary dictionary];
        const BOOL decoded = log && BSGFeatureFlagsDecode(log, ^(NSString *name, __unused NSString *variant, BOOL removed, NSData *record) {
            if (removed) {
                [names removeObject:name];
                records[name] = nil;
            } else {
                // As in BSGMemoryFeatureFlagStore, a flag that is already present keeps its position
                if (!records[name]) {
                    [names addObject:name];
                }
                records[name] = record;
            }
        });
        if (verify) {
            @autoreleasepool {
                NSData *second = BSGFeatureFlagFileReadData(fd, length, offset);
                struct stat after;
                if (!second || ![second isEqualToData:log] || fstat(fd, &after) != 0 ||
                    !BSGFeatureFlagFileIsUnchanged(&before, &after)) {
                    continue;
                }
            }
        }
        if (!decoded) {
            return BSGFeatureFlagFileCorrupt;
        }
        uint64_t liveLength = 0;
        for (NSString *name in names) {
            liveLength += records[name].length;
        }
        if (log.length > 2 * liveLength) {
            // The records refer to the log's bytes, so most of the log would stay allocated for nothing; they are
            // copied instead, and the log is freed
            for (NSString *name in names) {
                records[name] = [NSData dataWithBytes:records[name].bytes length:records[name].length];
            }
        }
        self.names = names;
        self.recordsByName = records;
        self.liveLength = liveLength;
        return BSGFeatureFlagFileLoaded;
    }
    return BSGFeatureFlagFileUnavailable;
}

/// A new path for a file that will replace featureflag.bin. Each replacement uses its own file.
- (NSString *)newTemporaryFilePath {
    return [NSString stringWithFormat:@"%@.%@.tmp", self.filePath, NSUUID.UUID.UUIDString];
}

- (void)setRecord:(nullable NSData *)record forName:(NSString *)name {
    self.liveLength -= self.recordsByName[name].length;
    self.liveLength += record.length;
    self.recordsByName[name] = record;
}

- (void)removeAllFlagsFromMemory {
    [self.names removeAllObjects];
    [self.recordsByName removeAllObjects];
    [self.unencodableFlags removeAllObjects];
    self.liveLength = 0;
}

/// The records of the flags that are persisted, in order: a log holding just the current flags.
- (NSArray<NSData *> *)orderedRecords {
    NSMutableArray<NSData *> *records = [NSMutableArray arrayWithCapacity:self.recordsByName.count];
    for (NSString *name in self.names) {
        NSData *record = self.recordsByName[name];
        if (record) {
            [records addObject:record];
        }
    }
    return records;
}

/// Adds a flag, or replaces the variant of a flag that is present, keeping its position (as
/// BSGMemoryFeatureFlagStore does). Returns the records to append to the log, which are empty if
/// nothing that is persisted changed.
- (NSData *)setFlagNamed:(NSString *)name variant:(nullable NSString *)variant {
    // A mutable name changed by the caller would no longer match its entry in names
    name = [name copy];
    NSData *previous = self.recordsByName[name];
    BugsnagFeatureFlag *unencodable = self.unencodableFlags[name];
    NSData *record = BSGFeatureFlagEncode(name, variant);
    if (record) {
        if ([previous isEqualToData:record]) {
            return [NSData data];
        }
        if (unencodable) {
            // The flag is present but has no record in the log, so a record appended to the log would
            // add it at the end when replayed. Unless it is the last flag, the log must be rewritten.
            [self.unencodableFlags removeObjectForKey:name];
            if (![self.names.lastObject isEqualToString:name]) {
                self.needsSnapshot = YES;
            }
        } else if (!previous) {
            [self.names addObject:name];
        }
        [self setRecord:record forName:name];
        return record;
    }
    // A flag that cannot be encoded is kept in memory but not persisted, so the persisted
    // record for its previous variant must be removed.
    if (!previous && !unencodable) {
        [self.names addObject:name];
    }
    self.unencodableFlags[name] = [BugsnagFeatureFlag flagWithName:name variant:variant];
    [self setRecord:nil forName:name];
    return (previous ? BSGFeatureFlagEncodeRemoval(name) : nil) ?: [NSData data];
}

/// Saves the changes made by setFlagNamed:variant:.
- (void)saveChange:(NSData *)records {
    if (self.needsSnapshot || records.length) {
        [self flagsDidChange];
    }
    if (self.needsSnapshot) {
        self.needsSnapshot = NO;
        [self writeSnapshot];
    } else if (records.length) {
        [self appendRecords:records];
    }
}

/// Writes the active slot and log length to the header.
- (BOOL)writeActiveLength:(uint64_t)length slot:(uint32_t)slot {
    const uint64_t active = BSGFeatureFlagFileActiveValue(length, slot);
    if (!BSGFeatureFlagFileWrite(self.fd, &active, sizeof(active), offsetof(struct bsg_feature_flag_file_header, active))) {
        return NO;
    }
    self.activeSlot = slot;
    self.activeLength = length;
    return YES;
}

/// Appends records to the end of the log, or rewrites it if they don't fit or it has grown too large.
- (BOOL)appendRecords:(NSData *)records {
    if (records.length == 0) {
        return self.fileIsCurrent;
    }
    if (self.fd == -1 || !self.fileIsCurrent) {
        return [self writeSnapshot];
    }
    const uint32_t slot = self.activeSlot;
    const uint64_t length = self.activeLength;
    // Slots have room for twice the most flags that are persisted, so flags over that limit can still fit;
    // writeSnapshot empties the log instead
    if (length + records.length > self.slotCapacity || self.liveLength > BSGFeatureFlagMaxPersistedLength) {
        return [self writeSnapshot];
    }
    // The records are written before the length that makes them part of the log
    if (!BSGFeatureFlagFileWrite(self.fd, records.bytes, records.length,
                                 BSGFeatureFlagSlotOffset(self.slotCapacity, slot) + length) ||
        ![self writeActiveLength:length + records.length slot:slot]) {
        [self handleWriteFailure];
        return NO;
    }
    if (length + records.length > self.liveLength + MAX(self.liveLength, BSGFeatureFlagMinimumCompactionSize)) {
        // Rewriting the log only after it has doubled keeps the cost of each change constant on average
        return [self writeSnapshot];
    }
    return YES;
}

/// Whether the open file is large and mostly empty, so that it is replaced with a smaller one when its log is next
/// rewritten. Both the current flags and the log they replace must take up very little of it, so that clearing flags
/// and then adding them again does not replace it twice. After the flags are cleared it is therefore shrunk by the
/// next rewrite, which at the latest is when Bugsnag next starts.
- (BOOL)fileShouldShrink {
    const uint64_t capacity = self.fd != -1 ? self.slotCapacity : 0;
    return (capacity >= BSGFeatureFlagMinimumShrinkableCapacity &&
            self.liveLength < capacity / 8 && self.activeLength < capacity / 8);
}

/// Writes a log of the current flags into the inactive slot and makes it active. The file is replaced
/// with a larger one once the current flags take up more than half of a slot, so that the log can double
/// before it is rewritten, and with a smaller one when they take up very little of a large slot.
///
/// Flags over the size limit are checked first, so that while they stay over it each change costs no more than
/// encoding it: the lock is not taken and the directory is not examined unless an earlier file or JSON files must
/// still be removed.
- (BOOL)writeSnapshot {
    const BOOL overLimit = self.liveLength > BSGFeatureFlagMaxPersistedLength;
    if (overLimit) {
        // The flags remain in memory, and are saved by a later change that makes them small enough. Unlike a
        // file that could not be grown (below), this is not a failure that a retry resolves, so the earlier
        // flags are not kept: they would stay stale for as long as the flags stay over the limit.
        if (!self.tooLargeToPersist) {
            bsg_log_err(@"Feature flags are too large to persist");
            self.tooLargeToPersist = YES;
        }
        // Empties the log of a file this store has open; once it is empty this does nothing
        [self discardSnapshot];
        self.fileIsCurrent = NO;
        if (self.fd != -1 || (!self.staleFileMayExist && !self.pendingLegacyPaths.count)) {
            return NO;
        }
        // Otherwise an earlier file, or JSON files, must still be removed, as when there are no flags to save
    } else {
        self.tooLargeToPersist = NO;
    }
    if (self.fd == -1 && (self.liveLength == 0 || overLimit) && !self.staleFileMayExist && !self.pendingLegacyPaths.count) {
        // There is no file and nothing to save, so no file is created (and the lock is not taken): a missing file
        // means there are no flags. Every path that leaves a file at the path while fd is -1 has emptied or removed
        // it, or set staleFileMayExist.
        self.fileIsCurrent = NO;
        return YES;
    }
    if (![self prepareToWrite]) {
        self.fileIsCurrent = NO;
        return NO;
    }
    const BOOL written = [self writeSnapshotHoldingTheLock:overLimit];
    // Only once the flags have been written (or could not be) are the JSON files deleted
    [self removePendingLegacyFiles];
    return written;
}

- (BOOL)writeSnapshotHoldingTheLock:(BOOL)overLimit {
    const BOOL canRetryNow = NSProcessInfo.processInfo.systemUptime >= self.retryTime;
    if (self.fd == -1 && self.staleFileMayExist && canRetryNow) {
        // A file that could not be opened earlier is opened, so that its log is emptied or replaced in place
        [self openExistingFile];
    }
    if (overLimit) {
        [self discardSnapshot];
        self.fileIsCurrent = NO;
        if (self.fd == -1 && self.staleFileMayExist && canRetryNow) {
            [self retryLater];
        }
        return NO;
    }
    if (self.fd == -1 && self.liveLength == 0) {
        self.fileIsCurrent = NO;
        if (!self.staleFileMayExist) {
            return YES;
        }
        // A file that may still hold earlier flags could not be opened. It is kept rather than deleted (see "Files
        // that cannot be opened" at the top of this file), and tried again later.
        if (canRetryNow) {
            [self retryLater];
        }
        return NO;
    }
    const BOOL hasFile = self.fd != -1;
    const uint64_t capacity = hasFile ? self.slotCapacity : 0;
    if (!canRetryNow && (!hasFile || self.liveLength > capacity)) {
        // The flags remain in memory, and are saved by a later change or by the scheduled retry
        [self keepEarlierLogUntilTheFileIsReplaced];
        return NO;
    }
    NSMutableData *snapshot = [NSMutableData dataWithCapacity:(NSUInteger)self.liveLength];
    for (NSData *record in [self orderedRecords]) {
        [snapshot appendData:record];
    }
    const BOOL fits = hasFile && snapshot.length <= capacity;
    // The largest slot holds twice the most flags that are persisted (see BSGFeatureFlagFileFormat.h), so once a
    // file has the largest slots, a log of flags at the limit can still double before it is rewritten.
    const BOOL tooSmall = !hasFile || ((uint64_t)snapshot.length * 2 > capacity && capacity < BSGFeatureFlagMaxSlotCapacity);
    // Failures to replace the file are file system errors (e.g. no space, or something other than a
    // file at the path) that are unlikely to resolve themselves immediately, so the file is not
    // replaced again until the retry interval has passed.
    if ((tooSmall || [self fileShouldShrink]) && canRetryNow) {
        if ([self replaceFileWithSnapshot:snapshot]) {
            self.fileIsCurrent = YES;
            self.keepingEarlierLog = NO;
            self.staleFileMayExist = NO;
            [self resetRetry];
            return YES;
        }
        [self retryLater];
    }
    if (!fits) {
        // The flags remain in memory, and are saved by a later change or by the scheduled retry
        [self keepEarlierLogUntilTheFileIsReplaced];
        return NO;
    }
    // The log is written before the header that makes it active
    const uint32_t slot = self.activeSlot ^ 1;
    if ((snapshot.length &&
         !BSGFeatureFlagFileWrite(self.fd, snapshot.bytes, snapshot.length, BSGFeatureFlagSlotOffset(self.slotCapacity, slot))) ||
        ![self writeActiveLength:snapshot.length slot:slot]) {
        [self handleWriteFailure];
        return NO;
    }
    self.fileIsCurrent = YES;
    self.keepingEarlierLog = NO;
    self.waitingForProtectedData = NO;
    return YES;
}

/// Called when the current flags no longer fit in the file and a larger file cannot be created now, e.g. while the
/// device is locked, or because the disk is full. A retry has been scheduled (or is pending) to create it.
///
/// The file itself is intact, so its log, which holds the flags as they were when they last fitted, is kept rather
/// than emptied: an OOM or thermal kill before the retry succeeds is then reported with slightly stale flags rather
/// than with none. While the flags grow they are mostly added or changed, and the flags they
/// replace describe the app's state more closely than an empty set. Records are never appended to the kept
/// log (the file is not current), so it is replaced whole by the next write that succeeds.
///
/// A log that does not hold this store's flags (one written by another store, which this store took over when it
/// took the lock) is emptied as before, because those flags may belong to an earlier launch.
- (void)keepEarlierLogUntilTheFileIsReplaced {
    if (self.fd != -1 && (self.fileIsCurrent || self.keepingEarlierLog)) {
        self.keepingEarlierLog = YES;
    } else {
        [self discardSnapshot];
    }
    self.fileIsCurrent = NO;
}

/// Called when writing to the open file failed (e.g. because the disk is full). The log is emptied so
/// that the file does not hold flags that have since changed, the file is closed, and it is replaced
/// once the retry interval has passed.
- (void)handleWriteFailure {
    const int error = errno;
    bsg_log_err(@"Unable to save feature flags: %d", error);
    [self recordFailure:error];
    [self discardSnapshot];
    if (self.fd != -1) {
        close(self.fd);
        self.fd = -1;
    }
    self.fileIsCurrent = NO;
    [self retryLater];
}

/// Records the error of a failure, so that UIApplicationProtectedDataDidBecomeAvailable tries again if it was one
/// that protected data becoming available can resolve.
- (void)recordFailure:(int)error {
    self.waitingForProtectedData = error == EACCES || error == EPERM;
}

/// Called after a success: the next failure waits for the retry interval again.
- (void)resetRetry {
    self.retryTime = 0;
    self.retryDelay = 0;
    self.waitingForProtectedData = NO;
}

/// Called after the file could not be written or the lock could not be taken. The file is not replaced (nor the
/// lock tried) again until the retry delay has passed, and a retry is scheduled then. The delay is the retry
/// interval after the first failure and doubles after each consecutive failure, up to the maximum retry
/// interval; it starts again from the retry interval after a success or a change to the flags.
- (void)retryLater {
    const NSTimeInterval maximum = MAX(self.maximumRetryInterval, self.retryInterval);
    const NSTimeInterval delay = self.retryDelay > 0 ? MIN(self.retryDelay * 2, maximum) : self.retryInterval;
    self.retryDelay = delay;
    self.retryTime = NSProcessInfo.processInfo.systemUptime + delay;
    [self scheduleRetry];
}

/// Called when the flags change. A change is new work to save, so a long delay after repeated failures is
/// shortened to the retry interval.
- (void)flagsDidChange {
    if (self.retryDelay <= self.retryInterval) {
        return;
    }
    self.retryDelay = 0;
    const NSTimeInterval retryTime = NSProcessInfo.processInfo.systemUptime + self.retryInterval;
    if (self.retryTime > retryTime) {
        self.retryTime = retryTime;
        [self scheduleRetry];
    }
}

/// Writes the flags again at the retry time if they still have not been saved. Only the most recently
/// scheduled retry does anything, and it does not keep the store alive.
- (void)scheduleRetry {
    if (self.retryInterval <= 0) {
        return;
    }
    const NSUInteger generation = ++self.retryGeneration;
    const NSTimeInterval delay = MAX(self.retryTime - NSProcessInfo.processInfo.systemUptime, 0);
    __weak typeof(self) weakSelf = self;
    dispatch_block_t retry = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        @synchronized (strongSelf) {
            if (generation != strongSelf.retryGeneration) {
                return;
            }
            if ([strongSelf hasPendingWork]) {
                strongSelf.retryTime = 0;
                [strongSelf writeSnapshot];
            }
        }
    };
    BSGFeatureFlagRetryScheduler scheduler = self.retryScheduler;
    if (scheduler) {
        scheduler(delay, retry);
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), retry);
}

/// Empties the log in the file this store has open (if any) after the flags could not be written, so
/// that it does not contain flags that have since been changed or cleared. A file this store has not
/// opened is never deleted here.
- (void)discardSnapshot {
    self.keepingEarlierLog = NO;
    if (self.fd == -1 || self.activeLength == 0) {
        return;
    }
    if (![self writeActiveLength:0 slot:self.activeSlot]) {
        // This store holds the lock and has the file open, so the file is its own. It is deleted rather
        // than left holding stale flags.
        bsg_log_err(@"Unable to discard persisted feature flags: %d", errno);
        if (unlink(self.filePath.fileSystemRepresentation) != 0 && errno != ENOENT) {
            self.staleFileMayExist = YES;
        }
        close(self.fd);
        self.fd = -1;
    }
}

/// Writes a new file with room for the log to grow and atomically replaces the current one. A file is
/// shrunk to no less than a quarter of its size at a time, so that flags being cleared and then added
/// again do not repeatedly replace it.
///
/// The file's blocks are not preallocated: with pwrite() a full disk is reported as an error and handled
/// like any other failure, so preallocation would only use disk space for slots that may never be filled.
- (BOOL)replaceFileWithSnapshot:(NSData *)snapshot {
    const uint64_t headerSize = sizeof(struct bsg_feature_flag_file_header);
    const uint64_t pageSize = (uint64_t)getpagesize();
    const uint64_t minimumCapacity = MAX(MAX((uint64_t)snapshot.length * 2, (pageSize - headerSize) / 2),
                                         self.fd != -1 ? self.slotCapacity / 4 : 0);
    const uint64_t pageAlignedSize = (headerSize + 2 * minimumCapacity + pageSize - 1) / pageSize * pageSize;
    const uint64_t slotCapacity = MIN((pageAlignedSize - headerSize) / 2, BSGFeatureFlagMaxSlotCapacity);
    if (snapshot.length > slotCapacity) {
        bsg_log_err(@"Feature flags are too large to persist");
        return NO;
    }

    struct bsg_feature_flag_file_header header = {
        .magic = BSGFeatureFlagFileMagic,
        .version = BSGFeatureFlagFileVersion,
        .slotCapacity = (uint32_t)slotCapacity,
        .active = BSGFeatureFlagFileActiveValue(snapshot.length, 0),
    };

    NSString *tempPath = [self newTemporaryFilePath];
    // Created with NSFileProtectionCompleteUnlessOpen, so that it can be created while the device is locked, and
    // with the backup policy; rename() keeps both, so they are not set again when featureflag.bin is opened later
    int fd = BSGCreateFileWithoutCompleteProtection(tempPath, O_RDWR);
    if (fd == -1) {
        [self recordFailure:errno];
        return NO;
    }
    const BOOL written = (ftruncate(fd, (off_t)BSGFeatureFlagFileSize(slotCapacity)) == 0 &&
                          BSGFeatureFlagFileWrite(fd, &header, sizeof(header), 0) &&
                          BSGFeatureFlagFileWrite(fd, snapshot.bytes, snapshot.length, headerSize) &&
                          rename(tempPath.fileSystemRepresentation, self.filePath.fileSystemRepresentation) == 0);
    if (!written) {
        const int error = errno;
        bsg_log_err(@"Unable to save feature flags: %d", error);
        [self recordFailure:error];
        close(fd);
        unlink(tempPath.fileSystemRepresentation);
        return NO;
    }
    if (self.fd != -1) {
        close(self.fd);
    }
    self.fd = fd;
    self.slotCapacity = slotCapacity;
    self.activeSlot = 0;
    self.activeLength = snapshot.length;
    return YES;
}

@end
