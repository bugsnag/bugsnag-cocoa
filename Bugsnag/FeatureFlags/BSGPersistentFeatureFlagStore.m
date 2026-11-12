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
// The file is read once, when the store is created, and changed with pwrite() through a file
// descriptor that is kept open. Data written with pwrite() is kept by the kernel even if the
// process is killed immediately afterwards. The file is not synchronised to disk (fsync), so a
// power loss can lose recent changes. Every write error (e.g. a full disk) is an ordinary error:
// the flags stay in memory, the log in the file is emptied so that it never holds stale flags, and
// writing is tried again later.
//
// Only one store writes to a directory: the one that holds an exclusive lock on featureflag.lock (see
// BSGPersistentFeatureFlagStore.h).
//

// A log is rewritten once the records it no longer needs take up more than this, or than the
// records it needs, whichever is larger.
static const uint64_t BSGFeatureFlagMinimumCompactionSize = 4096;
// Files with slots at least this large are replaced with smaller ones when they are mostly empty.
static const uint64_t BSGFeatureFlagMinimumShrinkableCapacity = 256 * 1024;
// How long to wait before trying to write the file again after it could not be written.
static const NSTimeInterval BSGFeatureFlagRetryInterval = 60;

static NSString * const BSGFeatureFlagFileName = @"featureflag.bin";
static NSString * const BSGFeatureFlagLockFileName = @"featureflag.lock";
// The name used by pre-release builds of this format, whose files are deleted (with their temporary files)
static NSString * const BSGFeatureFlagPrereleaseFileName = @"flags.bin";

/// Opens (or creates) a file that this store writes, with BSGOpenFileWithoutCompleteProtection, which applies
/// Bugsnag's backup policy and the same file protection handling as BSGRunContext: NSFileProtectionComplete is
/// changed to NSFileProtectionCompleteUnlessOpen and other classes are left unchanged. Because the descriptor is
/// kept open for the store's lifetime, a CompleteUnlessOpen file stays writable while the device is locked. An
/// existing CompleteUnlessOpen file cannot be opened again while the device is locked, so a launch while locked
/// cannot read the previous launch's flags (or take the lock); that is acceptable, because OOM detection also
/// depends on the run context, which has the same protection, and a launch before the first unlock follows a
/// reboot, after which BSGRunContext does not report an OOM. A file created here (O_EXCL) is deleted if it
/// cannot be set up.
static int BSGFeatureFlagFileOpen(NSString *path, int flags) {
    return BSGOpenFileWithoutCompleteProtection(path, flags);
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
// holds the lock writes to or deletes anything in the directory.
@property (nonatomic) int lockFd;
// The descriptor of featureflag.bin, or -1 if this store does not have it open for writing
@property (nonatomic) int fd;
// The file's slot capacity, and the active slot and log length, as last read or written by this store
@property (nonatomic) uint64_t slotCapacity;
@property (nonatomic) uint32_t activeSlot;
@property (nonatomic) uint64_t activeLength;

// Whether replaying the file's log gives exactly the encodable flags, so that records can be appended to it
@property (nonatomic) BOOL fileIsCurrent;
// Whether the flags were last too large to persist, so that this is only logged once
@property (nonatomic) BOOL tooLargeToPersist;
// The system uptime at which the file can next be replaced after a failure, to avoid repeating the
// failure on every change. Uptime is used because it is not affected by changes to the clock.
@property (nonatomic) NSTimeInterval retryTime;
@property (nonatomic) NSTimeInterval retryInterval;
// Whether a retry has been scheduled
@property (nonatomic) BOOL retryScheduled;

@end


@implementation BSGPersistentFeatureFlagStore

- (nonnull instancetype)initWithStorageDirectory:(NSString *)directory {
    if ((self = [super init]) != nil) {
        _directoryPath = directory;
        _filePath = [directory stringByAppendingPathComponent:BSGFeatureFlagFileName];
        _retryInterval = BSGFeatureFlagRetryInterval;
        _names = [NSMutableOrderedSet orderedSet];
        _recordsByName = [NSMutableDictionary dictionary];
        _unencodableFlags = [NSMutableDictionary dictionary];
        _fd = -1;
        _lockFd = [self acquireLock];
        [self loadFlags];
    }
    return self;
}

- (void)dealloc {
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
            if (persisted) {
                [self appendRecords:BSGFeatureFlagEncodeRemoval((NSString *_Nonnull)name) ?: [NSData data]];
            }
        }
    }
}

- (void)clear {
    @synchronized (self) {
        [self removeAllFlagsFromMemory];
        [self writeSnapshot];
    }
}

#pragma mark - Private methods

/// Takes the lock that allows this store to write to the directory, returning its descriptor or -1.
/// flock() locks belong to an open file description, so two stores in the same process conflict just as
/// two processes (e.g. two instances of a macOS app) do. The lock is on a separate file because featureflag.bin
/// is replaced by renaming another file over it.
- (int)acquireLock {
    NSString *path = [self.directoryPath stringByAppendingPathComponent:BSGFeatureFlagLockFileName];
    int fd = BSGFeatureFlagFileOpen(path, O_RDONLY | O_CREAT);
    if (fd == -1) {
        return -1;
    }
    if (flock(fd, LOCK_EX | LOCK_NB) != 0) {
        const int error = errno;
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

/// Reads the flags saved by the previous launch, or imports them from JSON files, and makes the file
/// match them (or removes it if it cannot). A store that does not hold the lock reads the flags but
/// changes nothing in the directory.
- (void)loadFlags {
    // The directory is listed once
    NSArray<NSString *> *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.directoryPath error:nil];
    NSString *temporaryFilePrefix = [BSGFeatureFlagFileName stringByAppendingString:@"."];
    NSString *prereleaseTemporaryFilePrefix = [BSGFeatureFlagPrereleaseFileName stringByAppendingString:@"."];
    NSMutableArray<NSString *> *legacyPaths = [NSMutableArray array];
    BOOL fileExists = NO;
    for (NSString *file in files) {
        NSString *path = [self.directoryPath stringByAppendingPathComponent:file];
        if ([file isEqualToString:BSGFeatureFlagFileName]) {
            fileExists = YES;
        } else if ([file hasPrefix:temporaryFilePrefix] && [file.pathExtension isEqualToString:@"tmp"]) {
            // Left behind by a process that was killed while replacing featureflag.bin. Only the store that holds
            // the lock writes these, so none of them is in use.
            if (self.canWrite) {
                unlink(path.fileSystemRepresentation);
            }
        } else if ([file isEqualToString:BSGFeatureFlagPrereleaseFileName] ||
                   ([file hasPrefix:prereleaseTemporaryFilePrefix] && [file.pathExtension isEqualToString:@"tmp"])) {
            // Written by pre-release builds, which used a different file name; the flags in it are not read
            if (self.canWrite) {
                unlink(path.fileSystemRepresentation);
            }
        } else if (BSGIsLegacyFeatureFlagFile(file)) {
            [legacyPaths addObject:path];
        }
    }

    const BSGFeatureFlagFileState state = fileExists ? [self readExistingFile] : BSGFeatureFlagFileMissing;
    if (state == BSGFeatureFlagFileLoaded || state == BSGFeatureFlagFileCorrupt) {
        if (legacyPaths.count) {
            // Both kinds of file are only left together when one of them could not be deleted after
            // the SDK was downgraded and upgraded again. It is not known which of them is current, so
            // neither is used.
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
        // (Something other than a file at the path, such as a directory, cannot hold flags.)
        struct stat st;
        const BOOL isFile = fileExists && stat(self.filePath.fileSystemRepresentation, &st) == 0 && S_ISREG(st.st_mode);
        if (!isFile) {
            for (BugsnagFeatureFlag *flag in BSGLegacyFeatureFlags(legacyPaths)) {
                [self setFlagNamed:flag.name variant:flag.variant];
            }
            self.needsSnapshot = NO;
        } else if (legacyPaths.count) {
            bsg_log_info(@"Discarding persisted feature flags because both featureflag.bin and JSON files were found");
        }
        if (self.liveLength > 0) {
            // The file is created when there are flags to save
            if (![self writeSnapshot] && isFile && self.canWrite) {
                // The unusable file holds the flags of an earlier launch, which must not be reported later
                unlink(self.filePath.fileSystemRepresentation);
            }
        } else if (isFile && self.canWrite) {
            // There is nothing to save, so an unusable file is removed rather than replaced
            unlink(self.filePath.fileSystemRepresentation);
        }
    }
    if (self.canWrite) {
        // The JSON files are deleted even if the flags could not be saved, because they would be stale
        // if imported again at the next launch. The imported flags remain in memory.
        BSGRemoveLegacyFeatureFlagFiles(legacyPaths);
    }
}

/// Reads the log in featureflag.bin into memory. A store that holds the lock keeps the file open for writing
/// if its header is valid. Failing to open the file is logged separately from a corrupt file.
- (BSGFeatureFlagFileState)readExistingFile {
    int fd = -1;
    if (self.canWrite) {
        fd = BSGFeatureFlagFileOpen(self.filePath, O_RDWR);
    } else if ((fd = open(self.filePath.fileSystemRepresentation, O_RDONLY | O_CLOEXEC)) == -1) {
        bsg_log_warn(@"Could not open %@: %d", self.filePath.lastPathComponent, errno);
    }
    if (fd == -1) {
        return BSGFeatureFlagFileUnusable;
    }
    struct stat st;
    struct bsg_feature_flag_file_header header;
    const BOOL valid = (fstat(fd, &st) == 0 &&
                        BSGFeatureFlagFileRead(fd, &header, sizeof(header), 0) &&
                        header.magic == BSGFeatureFlagFileMagic &&
                        header.version == BSGFeatureFlagFileVersion &&
                        header.slotCapacity > 0 &&
                        header.slotCapacity <= BSGFeatureFlagMaxReadableSlotCapacity &&
                        (uint64_t)st.st_size >= BSGFeatureFlagFileSize(header.slotCapacity));
    if (!valid) {
        bsg_log_err(@"Persisted feature flags are corrupt or in an unknown format; discarding them");
        close(fd);
        return BSGFeatureFlagFileUnusable;
    }
    const uint64_t length = header.active >> 1;
    const uint32_t slot = header.active & 1;
    // Only the active log is read; its length is limited by the slot capacity, which was checked above
    NSMutableData *log = length <= header.slotCapacity ? [NSMutableData dataWithLength:(NSUInteger)length] : nil;
    BOOL loaded = (log && BSGFeatureFlagFileRead(fd, log.mutableBytes, length, BSGFeatureFlagSlotOffset(header.slotCapacity, slot)) &&
                   BSGFeatureFlagsDecode(log.bytes, length, ^(NSString *name, NSString *variant, BOOL removed, NSData *record) {
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
        (void)variant;
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
    if (length + records.length > self.slotCapacity) {
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
    if (!self.canWrite) {
        self.fileIsCurrent = NO;
        return NO;
    }
    if (self.liveLength > BSGFeatureFlagMaxSlotCapacity) {
        // The flags remain in memory, and are saved by a later change that makes them small enough
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
        [self discardSnapshot];
        self.fileIsCurrent = NO;
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
            self.retryTime = 0;
            return YES;
        }
        self.retryTime = NSProcessInfo.processInfo.systemUptime + self.retryInterval;
        [self scheduleRetry];
    }
    if (!fits) {
        // The flags remain in memory, and are saved by a later change or by the scheduled retry
        [self discardSnapshot];
        self.fileIsCurrent = NO;
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
    return YES;
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
    self.retryTime = NSProcessInfo.processInfo.systemUptime + self.retryInterval;
    [self scheduleRetry];
}

/// Writes the flags again after the retry interval if they still have not been saved. Only one retry is
/// scheduled at a time, and it does not keep the store alive.
- (void)scheduleRetry {
    if (self.retryScheduled || self.retryInterval <= 0 || !self.canWrite) {
        return;
    }
    self.retryScheduled = YES;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.retryInterval * NSEC_PER_SEC)),
                   dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        @synchronized (strongSelf) {
            strongSelf.retryScheduled = NO;
            if (!strongSelf.fileIsCurrent) {
                strongSelf.retryTime = 0;
                [strongSelf writeSnapshot];
            }
        }
    });
}

/// Empties the log in the file this store has open (if any) after the flags could not be written, so
/// that it does not contain flags that have since been changed or cleared. A file this store has not
/// opened is never deleted here.
- (void)discardSnapshot {
    if (self.fd == -1 || self.activeLength == 0) {
        return;
    }
    if (![self writeActiveLength:0 slot:self.activeSlot]) {
        // This store holds the lock and has the file open, so the file is its own. It is deleted rather
        // than left holding stale flags.
        bsg_log_err(@"Unable to discard persisted feature flags: %d", errno);
        unlink(self.filePath.fileSystemRepresentation);
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
    int fd = BSGFeatureFlagFileOpen(tempPath, O_RDWR | O_CREAT | O_EXCL);
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
