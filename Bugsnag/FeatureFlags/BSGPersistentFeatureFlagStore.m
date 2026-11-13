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
// the header again then (see openFileWrittenByAnotherStore), but not the flags, because the flags in
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
// Files are opened with BSGOpenFileWithoutCompleteProtection, as BSGRunContext's is: NSFileProtectionComplete is
// changed to NSFileProtectionCompleteUnlessOpen, so the descriptors kept open stay usable while the device is
// locked. A launch while the device is locked (before the first unlock, or in the background for an app whose
// default class is Complete) cannot open the existing files, so it neither reads the previous launch's flags nor
// takes the lock. That is acceptable because the run context cannot be read either, so no OOM is reported; the
// lock is tried again later (see takeLockIfPossible). The files that replace featureflag.bin are created with
// NSFileProtectionCompleteUnlessOpen (see BSGCreateFileWithoutCompleteProtection), so they can be created while the
// device is locked even if the app's default class is Complete. Symbolic links at the paths are never followed.
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

#pragma mark -

typedef NS_ENUM(NSInteger, BSGFeatureFlagFileState) {
    BSGFeatureFlagFileMissing,  // There is no featureflag.bin
    BSGFeatureFlagFileUnusable, // featureflag.bin could not be opened, or its header is invalid
    BSGFeatureFlagFileCorrupt,  // The header is valid but the log is not
    BSGFeatureFlagFileLoaded,   // The flags were read from the log
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

// The descriptor of featureflag.lock while this store holds the lock on it, otherwise -1. Only a store that
// holds the lock writes to or deletes anything in the directory. The lock is taken when the store is created
// if the directory holds files for it to read or delete, and otherwise before the first write, so nothing is
// created in the directory until there are flags to save. Once taken it is kept until the store is deallocated.
@property (nonatomic) int lockFd;
// The descriptor of featureflag.bin, or -1 if this store does not have it open for writing
@property (nonatomic) int fd;
// The file's slot capacity, and the active slot and log length, as last read or written by this store
@property (nonatomic) uint64_t slotCapacity;
@property (nonatomic) uint32_t activeSlot;
@property (nonatomic) uint64_t activeLength;

// Whether replaying the file's log gives exactly the encodable flags, so that records can be appended to it
@property (nonatomic) BOOL fileIsCurrent;
// Set while the file is not current but its log holds an earlier set of this store's flags, which is kept
// because the current flags no longer fit in the file and a larger one could not be created yet (see writeSnapshot)
@property (nonatomic) BOOL keepingEarlierLog;
// Whether the flags were last too large to persist, so that this is only logged once
@property (nonatomic) BOOL tooLargeToPersist;
// The system uptime at which the file can next be replaced, or the lock next be tried, after a failure, to
// avoid repeating the failure on every change. Uptime is used because it is not affected by changes to the clock.
@property (nonatomic) NSTimeInterval retryTime;
// The delay after the first failure, and the largest delay after consecutive failures
@property (nonatomic) NSTimeInterval retryInterval;
@property (nonatomic) NSTimeInterval maximumRetryInterval;
// The delay used after the last failure, or 0 if there has been none since the last success or flag change
@property (nonatomic) NSTimeInterval retryDelay;
// Identifies the most recently scheduled retry; earlier ones do nothing when they run
@property (nonatomic) NSUInteger retryGeneration;
// Set when a file that this store does not have open may be at the path and hold flags that are no longer
// current (e.g. the previous launch's, read by a store that did not have the lock), so that it is emptied
// or removed even when there are no flags to save
@property (nonatomic) BOOL staleFileMayExist;
// JSON files whose flags were read when the store was created but which have not been deleted yet
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
        [self removeAllFlagsFromMemory];
        for (BugsnagFeatureFlag *flag in featureFlags) {
            [self setFlagNamed:flag.name variant:flag.variant];
        }
        self.needsSnapshot = NO;
        // This is called when Bugsnag starts, so it is not delayed by an earlier failure (e.g. when the
        // store was created). If it fails, a retry is scheduled.
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
/// A file system that does not support flock() (ENOTSUP or EOPNOTSUPP, e.g. an NFS volume without a lock daemon)
/// cannot tell two stores apart, so this store proceeds as the only writer, as the JSON files written by earlier
/// versions of the SDK did, rather than never saving the flags. That is logged once, and the descriptor is kept as
/// though it held the lock. Only EWOULDBLOCK means that another store holds the lock.
- (int)acquireLock {
    NSString *path = [self.directoryPath stringByAppendingPathComponent:BSGFeatureFlagLockFileName];
    int fd = BSGOpenFileWithoutCompleteProtection(path, O_RDONLY | O_CREAT);
    if (fd == -1) {
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
        } else {
            bsg_log_warn(@"Could not lock %@: %d", path.lastPathComponent, error);
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
/// (e.g. while the device is locked, or while another store holds it). Returns whether the store holds it.
- (BOOL)takeLockIfPossible {
    if (self.canWrite) {
        return YES;
    }
    if (NSProcessInfo.processInfo.systemUptime < self.retryTime) {
        return NO;
    }
    self.lockFd = [self acquireLock];
    if (!self.canWrite) {
        [self retryLater];
        return NO;
    }
    self.retryTime = 0;
    self.retryDelay = 0;
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
    [self openFileWrittenByAnotherStore];
    return YES;
}

/// Opens featureflag.bin for writing after the lock was taken, if it has a valid header, so that its log can be
/// replaced in place (by writeSnapshot, because the file is not current). A file whose header is invalid holds no
/// flags that can be read, and is removed.
- (void)openFileWrittenByAnotherStore {
    struct stat st;
    if (lstat(self.filePath.fileSystemRepresentation, &st) != 0) {
        self.staleFileMayExist = errno != ENOENT;
        return;
    }
    if (!S_ISREG(st.st_mode)) {
        // Something other than a file (e.g. a directory) cannot hold flags
        self.staleFileMayExist = NO;
        return;
    }
    const int fd = BSGOpenFileWithoutCompleteProtection(self.filePath, O_RDWR);
    if (fd == -1) {
        // Its contents are unknown, so it is removed or replaced when the flags are next saved
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
    // The log holds another store's flags, which are never kept in place of this store's
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

/// Deletes the JSON files that could not be deleted earlier.
///
/// A JSON file that could not be deleted after its flags were imported is found next to featureflag.bin at the
/// next launch, and then both are discarded, because that cannot be told apart from both kinds of file being
/// left by a downgrade and an upgrade in which one of them could not be deleted. Recording the import in the
/// header is not safe: the reserved fields are fixed when a file is created (see BSGFeatureFlagFileFormat.h),
/// and a file is kept and written in place for many launches, so a marker would still be set when a later
/// downgrade and upgrade leaves newer JSON files next to it, which would then be ignored in favour of stale
/// flags. Modification times are not reliable either, because the clock can change. Deleting the files is
/// therefore tried again whenever a log is written, which makes the case very unlikely.
- (void)removePendingLegacyFiles {
    if (self.pendingLegacyPaths.count && self.canWrite) {
        self.pendingLegacyPaths = BSGRemoveLegacyFeatureFlagFiles(self.pendingLegacyPaths);
    }
}

/// Retries saving the flags when protected data becomes available (the device is unlocked), because a store
/// created while the device was locked could not take the lock or open the file.
- (void)observeProtectedData {
#if TARGET_OS_IOS || TARGET_OS_TV
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

- (void)protectedDataDidBecomeAvailable {
    @synchronized (self) {
        if (!self.canWrite || !self.fileIsCurrent) {
            self.retryTime = 0;
            self.retryDelay = 0;
            [self writeSnapshot];
        }
    }
}

/// Reads the flags saved by the previous launch, or imports them from JSON files, and makes the file
/// match them (or removes it if it cannot). A store that does not hold the lock reads the flags but
/// changes nothing in the directory.
- (void)loadFlags {
    // The directory is listed once
    NSArray<NSString *> *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.directoryPath error:nil];
    NSMutableArray<NSString *> *obsoletePaths = [NSMutableArray array];
    NSMutableArray<NSString *> *legacyPaths = [NSMutableArray array];
    BOOL fileExists = NO;
    for (NSString *file in files) {
        NSString *path = [self.directoryPath stringByAppendingPathComponent:file];
        if ([file isEqualToString:BSGFeatureFlagFileName]) {
            fileExists = YES;
        } else if ([self isObsoleteFile:file]) {
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
    if (state == BSGFeatureFlagFileLoaded || state == BSGFeatureFlagFileCorrupt) {
        if (legacyPaths.count) {
            // Both kinds of file are only left together when one of them could not be deleted after
            // the SDK was downgraded and upgraded again, or after the JSON files were imported (see
            // removePendingLegacyFiles). It is not known which of them is current, so neither is used.
            bsg_log_info(@"Discarding persisted feature flags because both featureflag.bin and JSON files were found");
            [self removeAllFlagsFromMemory];
            [self writeSnapshot];
        } else if (state == BSGFeatureFlagFileCorrupt) {
            bsg_log_err(@"Persisted feature flags are corrupt; discarding them");
            [self removeAllFlagsFromMemory];
            // Publish an empty log so that new records are not appended to the corrupt one
            [self writeSnapshot];
        } else {
            // This file can be older than the previous launch: SDK versions before 6.31.0 never touch this
            // directory, so it survives a downgrade to one of them and an upgrade again. Its flags are not
            // reported for that launch, because an app upgrade changes the Mach-O UUID and BSGRunContext
            // then does not report an OOM or thermal kill. They are replaced when Bugsnag starts.
            self.fileIsCurrent = self.fd != -1;
        }
    } else {
        // Flags written as individual files by earlier versions of the SDK are imported so that they
        // can be included in an OOM event (see BSGLegacyFeatureFlags.h). If a featureflag.bin file that could not
        // be used is next to them, it is not known which is current, so they are discarded as above.
        // (Something other than a file at the path, such as a directory or a symbolic link, cannot hold flags.)
        struct stat st;
        const BOOL isFile = fileExists && lstat(self.filePath.fileSystemRepresentation, &st) == 0 && S_ISREG(st.st_mode);
        if (!isFile) {
            for (BugsnagFeatureFlag *flag in BSGLegacyFeatureFlags(legacyPaths)) {
                [self setFlagNamed:flag.name variant:flag.variant];
            }
            self.needsSnapshot = NO;
            if (self.liveLength > 0) {
                // The file is created when there are flags to save
                [self writeSnapshot];
            }
        } else {
            if (legacyPaths.count) {
                bsg_log_info(@"Discarding persisted feature flags because both featureflag.bin and JSON files were found");
            }
            // No flags were read, so there is nothing to save, and an unusable file is removed rather than
            // replaced: it holds the flags of an earlier launch, which must not be reported later
            if (self.canWrite && unlink(self.filePath.fileSystemRepresentation) != 0 && errno != ENOENT) {
                self.staleFileMayExist = YES;
            }
        }
    }
    // The JSON files are deleted even if the flags could not be saved, because they would be stale
    // if imported again at the next launch. The imported flags remain in memory. Files that cannot be
    // deleted now (or by a store that does not hold the lock yet) are deleted by a later write.
    self.pendingLegacyPaths = legacyPaths;
    [self removePendingLegacyFiles];
}

/// Reads the log in featureflag.bin into memory. A store that holds the lock keeps the file open for writing
/// if its header is valid. Failing to open the file is logged separately from a corrupt file.
- (BSGFeatureFlagFileState)readExistingFile {
    int fd = -1;
    if (self.canWrite) {
        fd = BSGOpenFileWithoutCompleteProtection(self.filePath, O_RDWR);
    } else if ((fd = open(self.filePath.fileSystemRepresentation, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)) == -1) {
        // As when the store holds the lock, a symbolic link at the path is refused (ELOOP) rather than followed
        bsg_log_warn(@"Could not open %@: %d", self.filePath.lastPathComponent, errno);
    }
    if (fd == -1) {
        return BSGFeatureFlagFileUnusable;
    }
    struct bsg_feature_flag_file_header header;
    if (!BSGFeatureFlagFileReadHeader(fd, &header)) {
        bsg_log_err(@"Persisted feature flags are corrupt or in an unknown format; discarding them");
        close(fd);
        return BSGFeatureFlagFileUnusable;
    }
    const uint64_t length = header.active >> 1;
    const uint32_t slot = header.active & 1;
    // Only the active log is read; its length is limited by the slot capacity, which was checked above
    NSMutableData *log = length <= header.slotCapacity ? [NSMutableData dataWithLength:(NSUInteger)length] : nil;
    BOOL loaded = (log && BSGFeatureFlagFileRead(fd, log.mutableBytes, length, BSGFeatureFlagSlotOffset(header.slotCapacity, slot)) &&
                   BSGFeatureFlagsDecode(log.bytes, length, ^(NSString *name, __unused NSString *variant, BOOL removed, NSData *record) {
        if (removed) {
            [self.names removeObject:name];
            [self setRecord:nil forName:name];
        } else {
            // As in BSGMemoryFeatureFlagStore, a flag that is already present keeps its position
            if (!self.recordsByName[name]) {
                [self.names addObject:name];
            }
            [self setRecord:record forName:name];
        }
    }));
    if (self.canWrite) {
        self.fd = fd;
        self.slotCapacity = header.slotCapacity;
        self.activeSlot = slot;
        self.activeLength = length;
    } else {
        close(fd);
    }
    return loaded ? BSGFeatureFlagFileLoaded : BSGFeatureFlagFileCorrupt;
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

/// Writes a log of the current flags into the inactive slot and makes it active. The file is replaced
/// with a larger one once the current flags take up more than half of a slot, so that the log can double
/// before it is rewritten, and with a smaller one when they take up very little of a large slot.
- (BOOL)writeSnapshot {
    if (self.fd == -1 && self.liveLength == 0 && !self.staleFileMayExist && !self.pendingLegacyPaths.count) {
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
    [self removePendingLegacyFiles];
    if (self.fd == -1 && self.liveLength == 0) {
        // An earlier file that may still hold flags is removed rather than replaced with an empty one
        if (self.staleFileMayExist &&
            (unlink(self.filePath.fileSystemRepresentation) == 0 || errno == ENOENT)) {
            self.staleFileMayExist = NO;
        }
        if (!self.staleFileMayExist) {
            self.fileIsCurrent = NO;
            return YES;
        }
    }
    if (self.liveLength > BSGFeatureFlagMaxPersistedLength) {
        // The flags remain in memory, and are saved by a later change that makes them small enough. Unlike a
        // file that could not be grown (below), this is not a failure that a retry resolves, so the earlier
        // flags are not kept: they would stay stale for as long as the flags stay over the limit.
        if (!self.tooLargeToPersist) {
            bsg_log_err(@"Feature flags are too large to persist");
            self.tooLargeToPersist = YES;
        }
        [self discardSnapshot];
        self.fileIsCurrent = NO;
        return NO;
    }
    self.tooLargeToPersist = NO;
    const BOOL hasFile = self.fd != -1;
    const uint64_t capacity = hasFile ? self.slotCapacity : 0;
    const BOOL canReplaceFile = NSProcessInfo.processInfo.systemUptime >= self.retryTime;
    if (!canReplaceFile && (!hasFile || self.liveLength > capacity)) {
        // The flags remain in memory, and are saved by a later change or by the scheduled retry
        [self keepEarlierLogUntilTheFileIsReplaced];
        return NO;
    }
    NSMutableData *snapshot = [NSMutableData dataWithCapacity:(NSUInteger)self.liveLength];
    for (NSString *name in self.names) {
        NSData *record = self.recordsByName[name];
        if (record) {
            [snapshot appendData:record];
        }
    }
    const BOOL fits = hasFile && snapshot.length <= capacity;
    // The largest slot holds twice the most flags that are persisted (see BSGFeatureFlagFileFormat.h), so once a
    // file has the largest slots, a log of flags at the limit can still double before it is rewritten.
    const BOOL tooSmall = !hasFile || ((uint64_t)snapshot.length * 2 > capacity && capacity < BSGFeatureFlagMaxSlotCapacity);
    // A file is only shrunk when both the new log and the one it replaces take up very little of it, so
    // that clearing flags and then adding them again does not replace it twice. After the flags are
    // cleared it is therefore shrunk by the next rewrite, which at the latest is when Bugsnag next starts.
    const BOOL tooLarge = (capacity >= BSGFeatureFlagMinimumShrinkableCapacity &&
                           (uint64_t)snapshot.length < capacity / 8 && self.activeLength < capacity / 8);
    // Failures to replace the file are file system errors (e.g. no space, or something other than a
    // file at the path) that are unlikely to resolve themselves immediately, so the file is not
    // replaced again until the retry interval has passed.
    if ((tooSmall || tooLarge) && canReplaceFile) {
        if ([self replaceFileWithSnapshot:snapshot]) {
            self.fileIsCurrent = YES;
            self.keepingEarlierLog = NO;
            self.staleFileMayExist = NO;
            self.retryTime = 0;
            self.retryDelay = 0;
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
    bsg_log_err(@"Unable to save feature flags: %d", errno);
    [self discardSnapshot];
    if (self.fd != -1) {
        close(self.fd);
        self.fd = -1;
    }
    self.fileIsCurrent = NO;
    [self retryLater];
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
            if (!strongSelf.fileIsCurrent) {
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
    // Created with NSFileProtectionCompleteUnlessOpen, so that it can be created while the device is locked
    int fd = BSGCreateFileWithoutCompleteProtection(tempPath, O_RDWR);
    if (fd == -1) {
        return NO;
    }
    const BOOL written = (ftruncate(fd, (off_t)BSGFeatureFlagFileSize(slotCapacity)) == 0 &&
                          BSGFeatureFlagFileWrite(fd, &header, sizeof(header), 0) &&
                          BSGFeatureFlagFileWrite(fd, snapshot.bytes, snapshot.length, headerSize) &&
                          rename(tempPath.fileSystemRepresentation, self.filePath.fileSystemRepresentation) == 0);
    if (!written) {
        bsg_log_err(@"Unable to save feature flags: %d", errno);
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
