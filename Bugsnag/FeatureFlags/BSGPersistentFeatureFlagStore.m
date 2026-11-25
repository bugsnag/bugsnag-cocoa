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
#import "BSGFilesystem.h"
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
// Feature flags are persisted in featureflag.bin so that an OOM or thermal kill detected at the next launch can report
// them. Layout: BSGFeatureFlagFileFormat.h. Locking and contract: BSGPersistentFeatureFlagStore.h.
//
// Crash safety: the header's 8-byte active value (slot and log length) is written with one pwrite(), after the bytes
// it refers to, so the file always holds a complete set of flags even if the process is killed mid-update.
// - Adding, changing or clearing one flag: append a record after the log, then write the longer length.
// - Clearing all flags, or a log over twice the size of its flags: write just the current flags into the other slot,
//   then switch to it.
// - A log that no longer fits: write a larger file and rename() it over featureflag.bin. Large, mostly empty files are
//   replaced with smaller ones the same way.
//
// Flags are read only at creation; a store that takes the lock later reads just the header (openExistingFile), since
// the flags in memory are the ones it saves. pwrite() data on the descriptor kept open survives the process being
// killed. No fsync, by design: a power loss can lose recent changes or leave the header ahead of its records (zeros
// then decode as a flag with an empty name); after a reboot BSGRunContext reports no kill for the launch before it.
//
// Write failures (e.g. a full disk, or no larger file yet for a log that has outgrown the file; see writeSnapshot):
// the flags stay in memory, the file's log is emptied so it never holds stale flags, and the write is retried with the
// delay doubling up to a maximum. A kill before then reports no flags rather than flags the app has since changed.
//
// File protection: featureflag.bin is opened with BSGOpenFileWithoutFollowingLinks (no NSURL calls, no symbolic links
// followed). BSGCreateFileWithoutCompleteProtection creates the files that become it, setting the backup policy and
// protection class once; rename() keeps them. featureflag.lock is opened the same way and created with
// BSGOpenFileWithoutCompleteProtection.
// - In a NSFileProtectionComplete directory (app default class Complete), files get NSFileProtectionCompleteUnlessOpen
//   so open descriptors keep working while the device is locked; but a new file cannot be created while locked. Writes
//   then go to the open file; a new file (the first, or larger slots) waits for the unlock, the open file's log is
//   emptied meanwhile, and UIApplicationProtectedDataDidBecomeAvailable retries.
// - Elsewhere files inherit the directory's class, normally NSFileProtectionCompleteUntilFirstUserAuthentication, so a
//   background launch after the first unlock can open them.
// - A launch while locked (before the first unlock, or in the background with class Complete) may not open the files:
//   it then neither reads the previous flags nor takes the lock, and the file is kept.
//
// Files that cannot be opened. Only a file whose header was read and is invalid is ever deleted.
// - Something else at the path is replaced at the next save. A directory is removed with rmdir() only if empty; while
//   a non-empty one is there, nothing is saved this launch (logged once, not retried; see removeDirectoryAtFilePath).
// - A file that cannot be opened (EMFILE, ENFILE, EINTR, EAGAIN, or EACCES/EPERM while protected data is unavailable)
//   may hold good flags: it is kept, its flags are not reported, and a retry tries to reopen it. If there are flags to
//   save, a new file is renamed over it as usual (or, once reopened, its log is rewritten in place); if there are none,
//   it is emptied in place once it opens. If it never opens this launch, the next launch can read the flags of the
//   launch before. Accepted: usually protected data stays unavailable, so BSGRunContext cannot save this launch's run
//   context either; the other causes clear quickly.
//
// State:
//   lockFd             featureflag.lock's descriptor while holding the lock, else -1. Set once by takeLockIfPossible;
//                      closed in dealloc.
//   lockGivenUp        The lock will never be taken: EWOULDBLOCK, or an open error that does not clear (e.g. a symbolic
//                      link, or a missing directory that cannot be created). Never cleared; logged once.
//   fd                 featureflag.bin open for writing (only with the lock), else -1. Set by readExistingFile (at
//                      creation), openExistingFile (lock taken later, or a file that could not be opened retried) or
//                      replaceFileWithSnapshot; cleared by a write failure or a failure to empty the log.
//   slotCapacity, activeSlot, activeLength  As last read or written; meaningful only while fd is not -1.
//   fileIsCurrent      Replaying the log gives exactly the encodable flags, so records can be appended. Set by reading
//                      a valid file or writing a whole log; cleared by any failure, flags over the size limit, or
//                      taking over another store's file.
//   directoryAtFilePath  A non-empty directory is at the file's path. Never cleared or retried; logged once.
//   staleFileMayExist  A file not open in this store may be at the path with non-current flags (e.g. left unread
//                      without the lock, or not openable). Cleared once it is opened, replaced or removed.
//   pendingLegacyPaths JSON files imported, discarded or left unread, not yet deleted (see removePendingLegacyFiles).
//   tooLargeToPersist  The flags were last over BSGFeatureFlagMaxPersistedLength (so that is logged once).
//   retryTime,         After a failure: the uptime before which the file is not replaced, the lock not tried and an
//   retryDelay,        unopenable file not reopened; the delay (doubling to the maximum); the current scheduled retry.
//   retryGeneration    Reset when the file is replaced or the lock taken, not by a write in place (a larger file may
//                      still be needed). flagsDidChange shortens the delay; replaceAllFlags retries at once.
//   waitingForProtectedData  The last failure was EACCES or EPERM, so UIApplicationProtectedDataDidBecomeAvailable
//                      retries before the retry time.
//


// A log is rewritten once the records it no longer needs take up more than this, or than the
// records it needs, whichever is larger.
static const uint64_t BSGFeatureFlagMinimumCompactionSize = 4096;
// Files with slots at least this large are replaced with smaller ones when they are mostly empty.
static const uint64_t BSGFeatureFlagMinimumShrinkableCapacity = 256 * 1024;
// Retry delay after a failure to write the file or take the lock. It doubles after each consecutive failure, up to the
// maximum, so a failure that never clears (e.g. a read-only volume) is not repeated every minute.
static const NSTimeInterval BSGFeatureFlagRetryInterval = 60;
static const NSTimeInterval BSGFeatureFlagMaximumRetryInterval = 60 * 60;

static NSString * const BSGFeatureFlagFileName = @"featureflag.bin";
static NSString * const BSGFeatureFlagLockFileName = @"featureflag.lock";

#if defined(DEBUG) && DEBUG
// flock(), unless a unit test replaces it (see BSGSetFeatureFlagLockFunction)
static BSGFeatureFlagLockFunction bsg_featureFlagLockFunction = flock;

BSGFeatureFlagLockFunction BSGSetFeatureFlagLockFunction(BSGFeatureFlagLockFunction _Nullable function) {
    const BSGFeatureFlagLockFunction previous = bsg_featureFlagLockFunction;
    bsg_featureFlagLockFunction = function ?: flock;
    return previous;
}

static int BSGFeatureFlagLock(int fd, int operation) {
    return bsg_featureFlagLockFunction(fd, operation);
}
#else
static int BSGFeatureFlagLock(int fd, int operation) {
    return flock(fd, operation);
}
#endif

/// Reads the header, returning whether it is valid and the file is large enough for it. On failure `readError` is 0 if
/// the header is invalid (or the file too short for one), else the read error (e.g. EIO): the file may then still be
/// valid and must not be deleted.
static BOOL BSGFeatureFlagFileReadHeader(int fd, struct bsg_feature_flag_file_header *header, int *readError) {
    struct stat st;
    *readError = 0;
    errno = 0;
    if (fstat(fd, &st) != 0 || !BSGFeatureFlagFileRead(fd, header, sizeof(*header), 0)) {
        // A short read leaves errno at 0; captured at once, so later code can't change it
        *readError = errno;
        return NO;
    }
    return (header->magic == BSGFeatureFlagFileMagic &&
            header->version == BSGFeatureFlagFileVersion &&
            header->slotCapacity > 0 &&
            header->slotCapacity <= BSGFeatureFlagMaxReadableSlotCapacity &&
            (uint64_t)st.st_size >= BSGFeatureFlagFileSize(header->slotCapacity));
}

/// Reads `length` bytes into a new buffer, returning nil if they cannot all be read. `readError` is then 0 if the file
/// is too short, or the error if it could not be read.
static NSData * BSGFeatureFlagFileReadData(int fd, uint64_t length, uint64_t offset, int *readError) {
    *readError = 0;
    void *bytes = malloc(MAX((size_t)length, 1));
    if (!bytes) {
        *readError = ENOMEM;
        return nil;
    }
    errno = 0;
    if (!BSGFeatureFlagFileRead(fd, bytes, length, offset)) {
        // A short read leaves errno at 0; captured at once, so later code can't change it
        *readError = errno;
        free(bytes);
        return nil;
    }
    return [NSData dataWithBytesNoCopy:bytes length:(NSUInteger)length freeWhenDone:YES];
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

/// Whether an error opening or creating featureflag.lock can clear during this launch (e.g. protected data unavailable,
/// too many open files, a full disk). Others (e.g. ELOOP for a symbolic link, a read-only volume, ENOENT for a
/// directory that could not be created) do not, so the lock is not tried again.
static BOOL BSGFeatureFlagIsTransientOpenError(int error) {
    switch (error) {
        case EACCES: case EPERM: case EMFILE: case ENFILE: case EINTR: case EAGAIN:
        case ENOSPC: case EDQUOT: case ENOMEM: case EIO:
            return YES;
        default:
            return NO;
    }
}

#pragma mark -

typedef NS_ENUM(NSInteger, BSGFeatureFlagFileState) {
    BSGFeatureFlagFileMissing,     // There is no featureflag.bin
    BSGFeatureFlagFileNotAFile,    // Something other than a regular file is at the path
    BSGFeatureFlagFileUnavailable, // featureflag.bin could not be opened now
    BSGFeatureFlagFileInvalid,     // Its header is invalid
    BSGFeatureFlagFileCorrupt,     // The header is valid but the log is not
    BSGFeatureFlagFileLoaded,      // The flags were read from the log
};

@interface BSGPersistentFeatureFlagStore ()

@property (nonatomic, strong) NSString *directoryPath;
@property (nonatomic, strong) NSString *filePath;

// Flag names in BSGMemoryFeatureFlagStore's order (first added since last cleared): the record order of a rewritten log
@property (nonatomic, strong) NSMutableOrderedSet<NSString *> *names;
// The encoded record of each flag that can be persisted
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSData *> *recordsByName;
// Flags that cannot be encoded: kept in memory, not persisted
@property (nonatomic, strong) NSMutableDictionary<NSString *, BugsnagFeatureFlag *> *unencodableFlags;
// Total length of recordsByName, i.e. of a log of just the current flags
@property (nonatomic) uint64_t liveLength;
// Set when appending a change would reorder the flags on replay, so a new log must be written
@property (nonatomic) BOOL needsSnapshot;

// See the state table at the top of this file
@property (nonatomic) int lockFd;
@property (nonatomic) BOOL lockGivenUp;
@property (nonatomic) int fd;
@property (nonatomic) uint64_t slotCapacity;
@property (nonatomic) uint32_t activeSlot;
@property (nonatomic) uint64_t activeLength;
@property (nonatomic) BOOL fileIsCurrent;
/// Set while a complete, current log is rewritten only to shrink it, so a failure keeps it rather than emptying it.
@property (nonatomic) BOOL compactingCurrentLog;
/// Compaction is not tried again before this uptime, and the delay that set it (see deferCompaction).
@property (nonatomic) NSTimeInterval compactionRetryTime;
@property (nonatomic) NSTimeInterval compactionRetryDelay;
@property (nonatomic) BOOL tooLargeToPersist;
@property (nonatomic) NSTimeInterval retryTime;
// The delay after the first failure, and the largest delay after consecutive failures
@property (nonatomic) NSTimeInterval retryInterval;
@property (nonatomic) NSTimeInterval maximumRetryInterval;
@property (nonatomic) NSTimeInterval retryDelay;
@property (nonatomic) NSUInteger retryGeneration;
@property (nonatomic) BOOL waitingForProtectedData;
@property (nonatomic) BOOL staleFileMayExist;
@property (nonatomic) BOOL directoryAtFilePath;
@property (nonatomic, strong) NSArray<NSString *> *pendingLegacyPaths;
// See BSGPreviousLaunchFeatureFlagStore
@property (nonatomic, copy) NSArray<BugsnagFeatureFlag *> *loadedFlags;
// Flags imported from JSON files, kept by replaceAllFlags (see BSGLegacyFeatureFlags.h). Flags the app clears before
// Bugsnag starts are removed; empty once Bugsnag has started.
@property (nonatomic, copy) NSArray<BugsnagFeatureFlag *> *importedLegacyFlags;
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
        _importedLegacyFlags = @[];
        _fd = -1;
        _lockFd = -1;
        [self loadFlags];
        // The previous launch's flags, before the app can change the flags in memory (empty without the lock)
        _loadedFlags = [[self allFlags] copy];
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

#pragma mark - BSGPreviousLaunchFeatureFlagStore

- (nonnull NSArray<BugsnagFeatureFlag *> *)previousLaunchFlags {
    @synchronized (self) {
        return self.loadedFlags;
    }
}

#pragma mark - BSGFeatureFlagStore

/// Decodes every record, so it is O(flags). Called once, at creation, for the previous launch's flags; events get their
/// flags from the memory store.
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
        // Called when Bugsnag starts, after the event for the previous launch was built, so its flags are not needed
        self.loadedFlags = @[];
        // The records whose log the file holds, if it is current
        NSArray<NSData *> *savedRecords = self.fd != -1 && self.fileIsCurrent ? [self orderedRecords] : nil;
        [self removeAllFlagsFromMemory];
        // Imported JSON flags come first; a flag the app also sets keeps its position and takes the app's variant
        for (BugsnagFeatureFlag *flag in self.importedLegacyFlags) {
            [self setFlagNamed:flag.name variant:flag.variant];
        }
        self.importedLegacyFlags = @[];
        for (BugsnagFeatureFlag *flag in featureFlags) {
            [self setFlagNamed:flag.name variant:flag.variant];
        }
        self.needsSnapshot = NO;
        if (savedRecords && [savedRecords isEqualToArray:[self orderedRecords]] && ![self fileShouldShrink]) {
            // The file already holds these flags (e.g. Bugsnag starts with the previous launch's flags), so nothing
            // is written. Re-encoding above released the log read at creation. A file that should shrink is still
            // rewritten, so it shrinks by the time Bugsnag starts.
            [self removePendingLegacyFiles];
            return;
        }
        // Not delayed by an earlier failure (e.g. at creation); a failure schedules a retry. A given-up lock is not
        // tried again.
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
        if (self.importedLegacyFlags.count) {
            self.importedLegacyFlags = [self.importedLegacyFlags filteredArrayUsingPredicate:
                                        [NSPredicate predicateWithBlock:^BOOL(BugsnagFeatureFlag *flag, __unused id bindings) {
                return ![flag.name isEqualToString:(NSString *_Nonnull)name];
            }]];
        }
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
        self.importedLegacyFlags = @[];
        if (!self.names.count && self.fileIsCurrent && self.activeLength == 0 && !self.pendingLegacyPaths.count) {
            // The file already holds no flags, so there is nothing to write (apps may clear flags often)
            return;
        }
        if (self.names.count) {
            [self flagsDidChange];
        }
        [self removeAllFlagsFromMemory];
        [self writeSnapshot];
    }
}

#pragma mark - Private methods

/// Takes the lock that lets this store write to the directory, returning its descriptor or -1. The lock is on a
/// separate file because featureflag.bin is replaced by rename(). Outcomes (rules: BSGPersistentFeatureFlagStore.h):
/// - EWOULDBLOCK (held until the other store is deallocated, i.e. for the process lifetime), or an open error that
///   does not clear: lockGivenUp, logged once.
/// - Other failures: retried later.
/// - ENOTSUP or EOPNOTSUPP: logged once; the descriptor is kept as though it held the lock.
/// - EAGAIN (featureflag.lock removed or renamed while being created; see BSGOpenFileWithoutCompleteProtection) or
///   EINTR: opened once more at once, so the lock is never taken on a file no longer at the path.
- (int)acquireLock {
    NSString *path = [self.directoryPath stringByAppendingPathComponent:BSGFeatureFlagLockFileName];
    int fd = [self openLockFile:path];
    if (fd == -1 && (errno == EAGAIN || errno == EINTR)) {
        fd = [self openLockFile:path];
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
    if (BSGFeatureFlagLock(fd, LOCK_EX | LOCK_NB) != 0) {
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

/// Opens featureflag.lock, creating it (and the directory) if it is missing. Returns -1 on error, with errno set.
- (int)openLockFile:(NSString *)path {
    // NSURL calls (backup policy, protection class) are only made when the file must be created
    int fd = BSGOpenFileWithoutFollowingLinks(path, O_RDONLY);
    if (fd == -1 && errno == ENOENT) {
        fd = BSGOpenFileWithoutCompleteProtection(path, O_RDONLY | O_CREAT);
        if (fd == -1 && errno == ENOENT && [self createDirectory]) {
            fd = BSGOpenFileWithoutCompleteProtection(path, O_RDONLY | O_CREAT);
        }
    }
    return fd;
}

/// Creates the missing directory as BSGFileLocations would (it can be removed while the app runs, or not exist yet), as
/// it will not reappear by itself. On failure errno is ENOENT, which counts as a failure that does not clear.
- (BOOL)createDirectory {
    NSError *error = [BSGFilesystem ensurePathExists:self.directoryPath];
    if (error) {
        bsg_log_warn(@"Could not create the feature flag directory: %@", error);
        errno = ENOENT;
        return NO;
    }
    return YES;
}

/// Whether this store holds the lock, and so can write to the directory.
- (BOOL)canWrite {
    return self.lockFd != -1;
}

/// Returns whether this store holds the lock, trying to take it at most once per retry interval after a failure, and
/// never once it has been given up.
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

/// Takes the lock before a write if needed, then examines the directory again, as another store may have written to
/// it. The flags in memory are kept: they are the ones this store saves.
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

/// Opens featureflag.bin for writing while holding the lock, if its header is valid, so that writeSnapshot replaces its
/// log in place (the file is not current). Used when the lock is taken after creation, and to retry a file that could
/// not be opened. Invalid header: removed. Not a regular file: left, and replaced at the next save. Cannot be opened or
/// read: kept (see "Files that cannot be opened" at the top).
- (void)openExistingFile {
    if (BSGFeatureFlagPathTypeAt(self.filePath) != BSGFeatureFlagPathFile) {
        self.staleFileMayExist = NO;
        return;
    }
    const int fd = BSGOpenFileWithoutFollowingLinks(self.filePath, O_RDWR);
    if (fd == -1) {
        const int error = errno;
        if (error == ENOENT || error == ELOOP || error == EISDIR) {
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
    int readError = 0;
    if (!BSGFeatureFlagFileReadHeader(fd, &header, &readError)) {
        const int error = readError;
        close(fd);
        if (error) {
            // A read error (e.g. EIO): it may hold good flags, so it is kept and retried
            bsg_log_warn(@"Could not read %@ (%d); it is kept and will be tried again later",
                         self.filePath.lastPathComponent, error);
            [self recordFailure:error];
            self.staleFileMayExist = YES;
            return;
        }
        self.staleFileMayExist = unlink(self.filePath.fileSystemRepresentation) != 0 && errno != ENOENT;
        return;
    }
    self.fd = fd;
    self.slotCapacity = header.slotCapacity;
    self.activeSlot = header.active & 1;
    self.activeLength = header.active >> 1;
    self.fileIsCurrent = NO;
    self.staleFileMayExist = NO;
}

/// Whether the lock holder deletes this file when it reads the directory.
- (BOOL)isObsoleteFile:(NSString *)file {
    NSString *temporaryFilePrefix = [BSGFeatureFlagFileName stringByAppendingString:@"."];
    // Left by a process killed while replacing featureflag.bin; only the lock holder writes them, so none is in use
    return [file hasPrefix:temporaryFilePrefix] && [file.pathExtension isEqualToString:@"tmp"];
}

/// Deletes the JSON files whose flags were imported or discarded, so featureflag.bin and JSON files are not both kept.
/// - Done by the first write after the import (normally when Bugsnag starts), not at creation, so importing does not
///   write a file replaced milliseconds later; done even if that write failed, as the files would then be stale.
/// - Failures are retried by every write holding the lock (a whole log or an appended record) and by a scheduled
///   retry (see hasPendingWork). A JSON file found next to featureflag.bin at the next launch discards both: that
///   cannot be told from a downgrade and upgrade that left one undeletable.
/// - Not recorded in the header: its reserved fields are fixed at creation (see BSGFeatureFlagFileFormat.h) and a
///   file lives for many launches, so newer JSON files from a later downgrade would be ignored for stale flags.
///   Modification times are unreliable because the clock can change.
- (void)removePendingLegacyFiles {
    if (self.pendingLegacyPaths.count && self.canWrite) {
        self.pendingLegacyPaths = BSGRemoveLegacyFeatureFlagFiles(self.pendingLegacyPaths);
    }
}

/// Retries when protected data becomes available, as taking the lock, opening the file or creating one can fail while
/// the device is locked.
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

/// Acts only if there is pending work and the last failure was one an unlock can resolve. The retry delay is not
/// reset, so it keeps doubling if this attempt fails too.
- (void)protectedDataDidBecomeAvailable {
    @synchronized (self) {
        if (self.waitingForProtectedData && [self hasPendingWork]) {
            self.retryTime = 0;
            [self writeSnapshot];
        }
    }
}

/// Whether a write could change something: JSON files to delete (even while the file is current), or a non-current
/// file with flags to save (within the size limit), an open file whose log is not current, or a possibly stale file.
/// NO once the lock is given up, and (JSON files aside) while a non-empty directory is at the file's path.
- (BOOL)hasPendingWork {
    if (self.lockGivenUp) {
        return NO;
    }
    if (self.pendingLegacyPaths.count) {
        return YES;
    }
    if (self.fileIsCurrent || self.directoryAtFilePath) {
        return NO;
    }
    if (self.staleFileMayExist) {
        return YES;
    }
    if (self.liveLength > BSGFeatureFlagMaxPersistedLength) {
        // A retry cannot save them; the open file's log was emptied when they went over the limit
        return NO;
    }
    return self.liveLength > 0 || (self.fd != -1 && self.activeLength > 0);
}

/// Reads the previous launch's flags, or imports them from JSON files, without writing (the next change, normally
/// replaceAllFlags, writes them). Files with no usable flags are removed. Without the lock nothing is read or changed.
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
        // Otherwise the lock waits for the first write, so nothing is created for an app that never saves flags
        [self takeLockIfPossible];
    }
    if (!self.canWrite) {
        // Not reported; replaced or deleted if this store takes the lock later
        self.staleFileMayExist = fileExists;
        self.pendingLegacyPaths = legacyPaths;
        return;
    }
    for (NSString *path in obsoletePaths) {
        unlink(path.fileSystemRepresentation);
    }

    const BSGFeatureFlagFileState state = fileExists ? [self readExistingFile] : BSGFeatureFlagFileMissing;
    // Which of the two is current is unknown (see removePendingLegacyFiles), so neither is used. Something other than a
    // file at the path cannot hold flags, so JSON files next to it are imported.
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
                // An empty log, so the discarded flags are never reported and nothing is appended to a corrupt log
                [self writeSnapshot];
            } else {
                // May predate the previous launch (SDKs before 6.31.0 leave this directory alone across a downgrade
                // and upgrade); the app upgrade changes the Mach-O UUID, so no kill is reported then. Replaced when
                // Bugsnag starts.
                self.fileIsCurrent = self.fd != -1;
            }
            break;
        case BSGFeatureFlagFileInvalid:
            // Removed, not replaced: it holds an earlier launch's flags, which must never be reported
            if (unlink(self.filePath.fileSystemRepresentation) != 0 && errno != ENOENT) {
                self.staleFileMayExist = YES;
            }
            break;
        case BSGFeatureFlagFileUnavailable:
            // Kept: it may hold good flags (see "Files that cannot be opened" at the top)
            self.staleFileMayExist = YES;
            [self retryLater];
            break;
        case BSGFeatureFlagFileMissing:
        case BSGFeatureFlagFileNotAFile:
            // Imported for an OOM event; the next write saves them and deletes the JSON files (see
            // BSGLegacyFeatureFlags.h and removePendingLegacyFiles)
            self.importedLegacyFlags = BSGLegacyFeatureFlags(legacyPaths);
            for (BugsnagFeatureFlag *flag in self.importedLegacyFlags) {
                [self setFlagNamed:flag.name variant:flag.variant];
                imported = YES;
            }
            self.needsSnapshot = NO;
            break;
    }
    // Files that cannot be deleted now are deleted by a later write
    self.pendingLegacyPaths = legacyPaths;
    if (!imported) {
        [self removePendingLegacyFiles];
    }
}

/// Reads featureflag.bin's log into memory, keeping the file open for writing if its header is valid. Lock holder only.
/// Open failures are logged apart from corruption.
- (BSGFeatureFlagFileState)readExistingFile {
    switch (BSGFeatureFlagPathTypeAt(self.filePath)) {
        case BSGFeatureFlagPathMissing: return BSGFeatureFlagFileMissing;
        case BSGFeatureFlagPathNotAFile: return BSGFeatureFlagFileNotAFile;
        case BSGFeatureFlagPathFile: break;
    }
    const int fd = BSGOpenFileWithoutFollowingLinks(self.filePath, O_RDWR);
    if (fd == -1) {
        const int error = errno;
        if (error == ENOENT) {
            return BSGFeatureFlagFileMissing;
        }
        if (error == ELOOP || error == EISDIR) {
            // Replaced with something other than a regular file after lstat()
            return BSGFeatureFlagFileNotAFile;
        }
        bsg_log_warn(@"Could not open %@ (%d); the persisted feature flags are not available for this launch",
                     self.filePath.lastPathComponent, error);
        [self recordFailure:error];
        return BSGFeatureFlagFileUnavailable;
    }
    struct bsg_feature_flag_file_header header;
    int readError = 0;
    const BSGFeatureFlagFileState state = [self readLogInFile:fd header:&header readError:&readError];
    if (state == BSGFeatureFlagFileUnavailable) {
        const int error = readError;
        bsg_log_warn(@"Could not read %@ (%d); the persisted feature flags are not available for this launch",
                     self.filePath.lastPathComponent, error);
        [self recordFailure:error];
    }
    if (state == BSGFeatureFlagFileInvalid) {
        bsg_log_err(@"Persisted feature flags are corrupt or in an unknown format; discarding them");
    }
    if (state == BSGFeatureFlagFileLoaded || state == BSGFeatureFlagFileCorrupt) {
        self.fd = fd;
        self.slotCapacity = header.slotCapacity;
        self.activeSlot = header.active & 1;
        self.activeLength = header.active >> 1;
    } else {
        close(fd);
    }
    return state;
}

/// Reads and decodes the active log, and on success replaces the flags in memory with its flags. When it returns
/// BSGFeatureFlagFileUnavailable, `readError` is the error that stopped the file being read.
- (BSGFeatureFlagFileState)readLogInFile:(int)fd header:(struct bsg_feature_flag_file_header *)header
                               readError:(int *)readError {
    *readError = 0;
    if (!BSGFeatureFlagFileReadHeader(fd, header, readError)) {
        // A file that could not be read may still hold good flags, so only an invalid header makes it Invalid
        return *readError ? BSGFeatureFlagFileUnavailable : BSGFeatureFlagFileInvalid;
    }
    const uint64_t length = header->active >> 1;
    const uint64_t offset = BSGFeatureFlagSlotOffset(header->slotCapacity, header->active & 1);
    if (length > header->slotCapacity) {
        // The header is written in one write, so this is not a torn read
        return BSGFeatureFlagFileCorrupt;
    }
    // Only the active log is read; its length was checked against the slot capacity above
    NSData *log = BSGFeatureFlagFileReadData(fd, length, offset, readError);
    if (!log && *readError) {
        return BSGFeatureFlagFileUnavailable;
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
    if (!decoded) {
        return BSGFeatureFlagFileCorrupt;
    }
    uint64_t liveLength = 0;
    for (NSString *name in names) {
        liveLength += records[name].length;
    }
    self.names = names;
    self.recordsByName = records;
    self.liveLength = liveLength;
    return BSGFeatureFlagFileLoaded;
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

/// Adds a flag or replaces its variant in place (as BSGMemoryFeatureFlagStore does). Returns the records to append,
/// empty if nothing persisted changed.
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
            // Present but with no record, so an appended record would move it to the end on replay; unless it is
            // last, the log must be rewritten
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
    // Unencodable: kept in memory only, so any persisted record of its previous variant is removed
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
    // Flags over the limit can still fit (slots hold twice the limit); writeSnapshot empties the log instead
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
    if (length + records.length > self.liveLength + MAX(self.liveLength, BSGFeatureFlagMinimumCompactionSize) &&
        NSProcessInfo.processInfo.systemUptime >= self.compactionRetryTime) {
        // Rewriting only after the log has doubled keeps each change's cost constant on average. The log is already
        // current, so a failed rewrite (e.g. disk full) keeps it, and a later change retries after the retry interval.
        self.compactingCurrentLog = YES;
        if ([self writeSnapshot]) {
            self.compactionRetryDelay = 0;
        }
        self.compactingCurrentLog = NO;
        return self.fileIsCurrent;
    }
    // Retry deleting JSON files (writeSnapshot does this too)
    [self removePendingLegacyFiles];
    return YES;
}

/// Whether the open file is large and mostly empty, so its next rewrite (at the latest when Bugsnag next starts)
/// shrinks it. Both the flags and the current log must be small, so clearing and re-adding flags does not replace it
/// twice.
- (BOOL)fileShouldShrink {
    const uint64_t capacity = self.fd != -1 ? self.slotCapacity : 0;
    return (capacity >= BSGFeatureFlagMinimumShrinkableCapacity &&
            self.liveLength < capacity / 8 && self.activeLength < capacity / 8);
}

/// Writes a log of the current flags into the inactive slot and makes it active. The file is replaced with a larger
/// one once the flags fill over half a slot (so the log can double before a rewrite), and with a smaller one when they
/// fill very little of a large slot. Flags over the size limit are checked first, so each change then costs only its
/// encoding: no lock, no directory scan, unless an earlier file or JSON files must still be removed.
- (BOOL)writeSnapshot {
    const BOOL overLimit = self.liveLength > BSGFeatureFlagMaxPersistedLength;
    if (overLimit) {
        // Kept in memory until a change makes them small enough. A retry cannot fix this, so the earlier flags
        // are not kept: they would stay stale while the flags are over the limit.
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
        // Otherwise an earlier file or JSON files must still be removed
    } else {
        self.tooLargeToPersist = NO;
    }
    if (self.fd == -1 && (self.liveLength == 0 || overLimit) && !self.staleFileMayExist && !self.pendingLegacyPaths.count) {
        // No file and nothing to save: create nothing and take no lock, as a missing file means no flags. Every path
        // that leaves a file there while fd is -1 has emptied or removed it, or set staleFileMayExist.
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
        // Reopen a file that could not be opened earlier, so its log is emptied or replaced in place
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
        // A possibly stale file could not be opened: kept and retried (see "Files that cannot be opened")
        if (canRetryNow) {
            [self retryLater];
        }
        return NO;
    }
    const BOOL hasFile = self.fd != -1;
    const uint64_t capacity = hasFile ? self.slotCapacity : 0;
    if (!canRetryNow && (!hasFile || self.liveLength > capacity)) {
        // The flags remain in memory, and are saved by a later change or by the scheduled retry
        [self emptyLogUntilTheFileIsReplaced];
        return NO;
    }
    NSMutableData *snapshot = [NSMutableData dataWithCapacity:(NSUInteger)self.liveLength];
    for (NSData *record in [self orderedRecords]) {
        [snapshot appendData:record];
    }
    const BOOL fits = hasFile && snapshot.length <= capacity;
    // The largest slot holds twice the limit (see BSGFeatureFlagFileFormat.h), so a log at the limit can still double
    // there before it is rewritten.
    const BOOL tooSmall = !hasFile || ((uint64_t)snapshot.length * 2 > capacity && capacity < BSGFeatureFlagMaxSlotCapacity);
    // Replacement failures (e.g. no space) rarely clear at once, so the next replacement waits for the retry interval
    // (a non-empty directory at the path is never retried). At most one retry is scheduled per attempt, so a failed
    // replacement followed by a failed write in place doubles the delay only once.
    BOOL retryScheduled = NO;
    if ((tooSmall || [self fileShouldShrink]) && canRetryNow && !self.directoryAtFilePath) {
        if ([self replaceFileWithSnapshot:snapshot]) {
            self.fileIsCurrent = YES;
            self.staleFileMayExist = NO;
            [self resetRetry];
            return YES;
        }
        if (!self.directoryAtFilePath) {
            if (self.compactingCurrentLog) {
                [self deferCompaction];
            } else {
                [self retryLater];
            }
            retryScheduled = YES;
        }
    }
    if (!fits) {
        // The flags remain in memory, and are saved by a later change or by the scheduled retry
        [self emptyLogUntilTheFileIsReplaced];
        return NO;
    }
    // The log is written before the header that makes it active
    const uint32_t slot = self.activeSlot ^ 1;
    if ((snapshot.length &&
         !BSGFeatureFlagFileWrite(self.fd, snapshot.bytes, snapshot.length, BSGFeatureFlagSlotOffset(self.slotCapacity, slot))) ||
        ![self writeActiveLength:snapshot.length slot:slot]) {
        [self handleWriteFailureSchedulingRetry:!retryScheduled];
        return NO;
    }
    self.fileIsCurrent = YES;
    self.waitingForProtectedData = NO;
    return YES;
}

/// Called when the flags no longer fit and a larger file cannot be created now (e.g. device locked, disk full); a retry
/// is scheduled or pending. Empties the open file's log, as after any failure to save: a cleared flag reported as
/// active would mislead, an empty set does not. The next successful write saves the whole set.
- (void)emptyLogUntilTheFileIsReplaced {
    [self discardSnapshot];
    self.fileIsCurrent = NO;
}

/// Called when writing to the open file failed (e.g. disk full): empties the log so it holds no outdated flags, closes
/// the file, and replaces it after the retry interval.
- (void)handleWriteFailure {
    [self handleWriteFailureSchedulingRetry:YES];
}

/// As handleWriteFailure. `scheduleRetry` is NO when this attempt already scheduled one (after failing to replace the
/// file), so the delay doubles only once.
- (void)handleWriteFailureSchedulingRetry:(BOOL)scheduleRetry {
    const int error = errno;
    if (self.compactingCurrentLog && self.fd != -1 && self.fileIsCurrent) {
        // Only the inactive slot or the header switch failed, so the active log is still current and is kept
        bsg_log_warn(@"Unable to compact persisted feature flags: %d", error);
        [self deferCompaction];
        return;
    }
    bsg_log_err(@"Unable to save feature flags: %d", error);
    [self recordFailure:error];
    [self discardSnapshot];
    if (self.fd != -1) {
        close(self.fd);
        self.fd = -1;
    }
    self.fileIsCurrent = NO;
    if (scheduleRetry) {
        [self retryLater];
    }
}

/// After a failed compaction of a current log: nothing needs saving, so no retry is scheduled and the save retry delay
/// is untouched. A later change tries compaction again once its own delay has passed: the retry interval, doubling
/// after each consecutive failure up to the maximum retry interval (as for saves), and reset by a compaction that
/// succeeds.
- (void)deferCompaction {
    const NSTimeInterval maximum = MAX(self.maximumRetryInterval, self.retryInterval);
    const NSTimeInterval delay = self.compactionRetryDelay > 0 ? MIN(self.compactionRetryDelay * 2, maximum)
                                                                 : self.retryInterval;
    self.compactionRetryDelay = delay;
    self.compactionRetryTime = NSProcessInfo.processInfo.systemUptime + delay;
}

/// Notes whether UIApplicationProtectedDataDidBecomeAvailable should retry after this failure.
- (void)recordFailure:(int)error {
    self.waitingForProtectedData = error == EACCES || error == EPERM;
}

/// Called after a success: the next failure waits for the retry interval again.
- (void)resetRetry {
    self.retryTime = 0;
    self.retryDelay = 0;
    self.waitingForProtectedData = NO;
}

/// After a failure to write the file or take the lock: sets the next delay (see retryTime at the top) and schedules a
/// retry for when it has passed.
- (void)retryLater {
    const NSTimeInterval maximum = MAX(self.maximumRetryInterval, self.retryInterval);
    const NSTimeInterval delay = self.retryDelay > 0 ? MIN(self.retryDelay * 2, maximum) : self.retryInterval;
    self.retryDelay = delay;
    self.retryTime = NSProcessInfo.processInfo.systemUptime + delay;
    [self scheduleRetry];
}

/// A change is new work, so a long delay after repeated failures is shortened to the retry interval.
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

/// Writes again at the retry time if work is still pending. Only the latest retry acts; it does not retain the store.
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
#if defined(DEBUG) && DEBUG
    BSGFeatureFlagRetryScheduler scheduler = self.retryScheduler;
    if (scheduler) {
        scheduler(delay, retry);
        return;
    }
#endif
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), retry);
}

/// Empties the open file's log (if any) after a failure to save, so it holds no outdated flags. Never deletes a file
/// this store has not opened.
- (void)discardSnapshot {
    if (self.fd == -1 || self.activeLength == 0) {
        return;
    }
    if (![self writeActiveLength:0 slot:self.activeSlot]) {
        // The file is this store's own (lock held, file open), so it is deleted rather than left stale
        bsg_log_err(@"Unable to discard persisted feature flags: %d", errno);
        if (unlink(self.filePath.fileSystemRepresentation) != 0 && errno != ENOENT) {
            self.staleFileMayExist = YES;
        }
        close(self.fd);
        self.fd = -1;
    }
}

/// rename() cannot replace a directory, so one at featureflag.bin's path is removed first, only if empty (rmdir();
/// contents are never removed). A non-empty one was not made by the SDK: logged once, not retried this launch
/// (directoryAtFilePath). Other failures are ordinary and retried. Returns whether no directory is at the path.
- (BOOL)removeDirectoryAtFilePath {
    const char *path = self.filePath.fileSystemRepresentation;
    struct stat st;
    if (lstat(path, &st) != 0 || !S_ISDIR(st.st_mode)) {
        return YES;
    }
    if (rmdir(path) == 0) {
        bsg_log_info(@"Removed an empty directory at %@ so that feature flags can be saved", self.filePath.lastPathComponent);
        return YES;
    }
    const int error = errno;
    if (error == ENOENT) {
        return YES;
    }
    if (error == ENOTEMPTY || error == EEXIST) {
        bsg_log_err(@"Feature flags cannot be saved because %@ is a directory that is not empty",
                    self.filePath.lastPathComponent);
        self.directoryAtFilePath = YES;
        return NO;
    }
    bsg_log_warn(@"Could not remove the empty directory at %@ (%d); saving feature flags will be tried again later",
                 self.filePath.lastPathComponent, error);
    [self recordFailure:error];
    return NO;
}

/// Writes a new file with room for the log to grow and atomically replaces the current one. It shrinks to no less
/// than a quarter at a time, so clearing and re-adding flags does not replace it repeatedly. Blocks are not
/// preallocated: pwrite() reports a full disk like any other failure, so that would only waste space.
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

    if (![self removeDirectoryAtFilePath]) {
        return NO;
    }

    NSString *tempPath = [self newTemporaryFilePath];
    // See "File protection" at the top. Failing while the device is locked is an ordinary failure, retried after the
    // unlock.
    int fd = BSGCreateFileWithoutCompleteProtection(tempPath, O_RDWR);
    if (fd == -1) {
        const int error = errno;
        if (self.compactingCurrentLog) {
            // The current log is kept, so the flags are still saved; the retry state is left alone (see deferCompaction)
            bsg_log_warn(@"Could not create %@ (%d); compacting persisted feature flags will be tried again later",
                         tempPath.lastPathComponent, error);
        } else {
            bsg_log_warn(@"Could not create %@ (%d); saving feature flags will be tried again later",
                         tempPath.lastPathComponent, error);
            [self recordFailure:error];
        }
        return NO;
    }
    const BOOL written = (ftruncate(fd, (off_t)BSGFeatureFlagFileSize(slotCapacity)) == 0 &&
                          BSGFeatureFlagFileWrite(fd, &header, sizeof(header), 0) &&
                          BSGFeatureFlagFileWrite(fd, snapshot.bytes, snapshot.length, headerSize) &&
                          rename(tempPath.fileSystemRepresentation, self.filePath.fileSystemRepresentation) == 0);
    if (!written) {
        const int error = errno;
        if (self.compactingCurrentLog) {
            // The current log is kept, so the flags are still saved
            bsg_log_warn(@"Unable to compact persisted feature flags: %d", error);
        } else {
            bsg_log_err(@"Unable to save feature flags: %d", error);
            [self recordFailure:error];
        }
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
