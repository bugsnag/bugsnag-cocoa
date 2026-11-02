//
//  BSGPersistentFeatureFlagStore.m
//  Bugsnag
//
//  Created by Robert B on 25/11/2024.
//  Copyright © 2024 Bugsnag. All rights reserved.
//

#import "BSGPersistentFeatureFlagStore.h"
#import "BugsnagInternals.h"
#import "BSGFilesystem.h"
#import "BSGKeys.h"
#import "BSGStoredFeatureFlag.h"
#import "BSGUtils.h"
#import "BugsnagLogger.h"
#import <Foundation/Foundation.h>

#import <fcntl.h>
#import <stdatomic.h>
#import <stddef.h>
#import <sys/mman.h>
#import <sys/stat.h>
#import <unistd.h>

//
// Feature flags are persisted so that they are accessible at next launch if an OOM
// or thermal kill is detected.
//
// They are stored in a single memory-mapped file containing two slots, each of which
// can hold a log of changes to the flags:
//
//   [header][slot 0][slot 1]
//   log = record*
//   record = [name length][variant length][name][variant]
//
// Lengths are uint32 values in native byte order (little-endian on every supported platform),
// and records are packed with no alignment padding. The name and variant are UTF-8.
//
// The variant length is UINT32_MAX for a flag without a variant, and UINT32_MAX - 1 for a
// record that removes the flag (which has no variant bytes). Replaying the log in order gives
// the flags: a record for a flag that is already present replaces it and moves it to the end.
//
// The header records which slot holds the log and how long it is, and is updated with a
// single atomic store after the bytes it refers to have been written, so the file always
// holds a complete set of flags even if the process is killed during an update:
//
// - Adding, changing or clearing a flag appends a record after the end of the log, then
//   publishes the longer length.
// - Clearing all flags, or a log that has grown to more than twice the size of the flags it
//   describes, writes a log of just the current flags into the other slot, then switches to it.
// - A log that no longer fits is written to a new, larger file, which is mapped and then
//   renamed over the current one. Large files are also replaced with smaller ones when most
//   of the flags are cleared.
//
// Because the file is mapped with MAP_SHARED, the kernel keeps what has been copied into
// the mapping even if the process is killed immediately afterwards. The file is not
// synchronised to disk (msync/fsync), so a power loss can lose recent changes. Changes are
// copied into the mapping rather than written with pwrite so that they need no system call;
// the file's blocks are allocated when it is created so that writing to it does not need
// more disk space.
//
// File format policy. Released versions of the SDK only read files whose version they know,
// so once a format version has been released it must never change:
//
// - A change that older versions can ignore uses the reserved header fields, which are written
//   as zero and ignored when read; a newer version must treat zero as "not set". They may only
//   hold values that are fixed when the file is created (a file is always created whole and
//   renamed into place), because an older version that appends to a newer version's file leaves
//   them unchanged. Anything that describes the log needs a new version.
// - Any other change (header layout, record layout, the meaning of a length or of the special
//   variant lengths) needs a new version number. A version that writes format N+1 must still
//   read every earlier version, so that flags survive an upgrade.
// - A file with a different magic number or an unknown version is discarded, never misread. So
//   when older and newer versions of the SDK replace each other (upgrade, downgrade, or two
//   versions in the same container), only the flags from the previous launch can be lost.
// - The JSON files written by SDK versions before this file existed (one file per flag) are
//   imported and deleted at launch. That import must be kept as long as an upgrade from such a
//   version is supported.
//

static const uint32_t BSGFeatureFlagFileMagic = 0x46465342; // "BSFF"
static const uint32_t BSGFeatureFlagFileVersion = 1;
static const uint32_t BSGFeatureFlagNoVariant = UINT32_MAX;
static const uint32_t BSGFeatureFlagRemoved = UINT32_MAX - 1;
// The largest slot capacity that is written; anything larger in a header means the file is corrupt.
static const uint64_t BSGFeatureFlagMaxSlotCapacity = UINT32_MAX / 4;
// A log is rewritten once the records it no longer needs take up more than this, or than the
// records it needs, whichever is larger.
static const uint64_t BSGFeatureFlagMinimumCompactionSize = 4096;
// Files with slots at least this large are replaced with smaller ones when they are mostly empty.
static const uint64_t BSGFeatureFlagMinimumShrinkableCapacity = 256 * 1024;
// How long to wait before trying to write the file again after it could not be written.
static const NSTimeInterval BSGFeatureFlagRetryInterval = 60;

static NSString * const BSGFeatureFlagFileName = @"flags.bin";

struct bsg_feature_flag_file_header {
    uint32_t magic;
    uint32_t version;
    uint32_t slotCapacity; // Size of each of the two slots that follow the header
    uint32_t reserved;
    // The length of the log (high bits) and the slot it is in (low bit).
    _Atomic(uint64_t) active;
    uint64_t reserved2;
};

// The layout is part of the file format, so it must be the same on every architecture (e.g. arm64_32).
_Static_assert(sizeof(struct bsg_feature_flag_file_header) == 32, "Feature flag file header size");
_Static_assert(offsetof(struct bsg_feature_flag_file_header, active) == 16, "Feature flag file header layout");
// The header is published with a single store, which must not be implemented with a lock.
_Static_assert(ATOMIC_LLONG_LOCK_FREE == 2, "64-bit atomics must be lock-free");

static uint64_t BSGFeatureFlagFileActiveValue(uint64_t length, uint32_t slot) {
    return (length << 1) | slot;
}

// Calculated in 64 bits because it can overflow a 32-bit size_t (e.g. on arm64_32) for a corrupt header.
static uint64_t BSGFeatureFlagFileSize(uint32_t slotCapacity) {
    return sizeof(struct bsg_feature_flag_file_header) + 2 * (uint64_t)slotCapacity;
}

static NSData * BSGFeatureFlagRecord(NSData *nameData, uint32_t variantLength, NSData *variantData) {
    const uint32_t lengths[2] = {(uint32_t)nameData.length, variantLength};
    NSMutableData *record = [NSMutableData dataWithCapacity:sizeof(lengths) + nameData.length + variantData.length];
    [record appendBytes:lengths length:sizeof(lengths)];
    [record appendData:nameData];
    if (variantData) {
        [record appendData:variantData];
    }
    return record;
}

/// Returns the record for a flag, or nil if it cannot be encoded.
static NSData * BSGFeatureFlagEncode(NSString *name, NSString *variant) {
    NSData *nameData = [name dataUsingEncoding:NSUTF8StringEncoding];
    NSData *variantData = [variant dataUsingEncoding:NSUTF8StringEncoding];
    if (!nameData || (variant && !variantData) ||
        nameData.length >= BSGFeatureFlagRemoved || variantData.length >= BSGFeatureFlagRemoved) {
        return nil;
    }
    return BSGFeatureFlagRecord(nameData, variantData ? (uint32_t)variantData.length : BSGFeatureFlagNoVariant, variantData);
}

/// Returns the record that removes a flag whose record was returned by BSGFeatureFlagEncode.
static NSData * BSGFeatureFlagEncodeRemoval(NSString *name) {
    NSData *nameData = [name dataUsingEncoding:NSUTF8StringEncoding];
    return nameData ? BSGFeatureFlagRecord(nameData, BSGFeatureFlagRemoved, nil) : nil;
}

/// Decodes UTF-8 bytes, keeping a leading byte order mark, which Foundation would remove.
static NSString * BSGFeatureFlagDecodeString(const uint8_t *bytes, uint32_t length) {
    static const uint8_t byteOrderMark[] = {0xEF, 0xBB, 0xBF};
    NSString *string = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
    if (string && length >= sizeof(byteOrderMark) && memcmp(bytes, byteOrderMark, sizeof(byteOrderMark)) == 0 &&
        [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding] == length - sizeof(byteOrderMark)) {
        string = [@"\uFEFF" stringByAppendingString:string];
    }
    return string;
}

/// Calls the block with each record in a log: the flag it adds and its encoded record, or the name of
/// the flag it removes. Returns NO if the log is corrupt.
static BOOL BSGFeatureFlagsDecode(const uint8_t *bytes, uint64_t length,
                                  void (^ block)(NSString *name, NSString *variant, BOOL removed, NSData *record)) {
    uint64_t offset = 0;
    while (offset < length) {
        const uint64_t start = offset;
        uint32_t lengths[2];
        if (length - offset < sizeof(lengths)) {
            return NO;
        }
        memcpy(lengths, bytes + offset, sizeof(lengths));
        offset += sizeof(lengths);
        const uint32_t nameLength = lengths[0];
        const BOOL hasVariant = lengths[1] != BSGFeatureFlagNoVariant && lengths[1] != BSGFeatureFlagRemoved;
        const uint32_t variantLength = hasVariant ? lengths[1] : 0;
        if (nameLength > length - offset || variantLength > length - offset - nameLength) {
            return NO;
        }
        NSString *name = BSGFeatureFlagDecodeString(bytes + offset, nameLength);
        offset += nameLength;
        NSString *variant = nil;
        if (hasVariant) {
            variant = BSGFeatureFlagDecodeString(bytes + offset, variantLength);
            offset += variantLength;
            if (!variant) {
                return NO;
            }
        }
        if (!name) {
            return NO;
        }
        block(name, variant, lengths[1] == BSGFeatureFlagRemoved,
              [NSData dataWithBytes:bytes + start length:(NSUInteger)(offset - start)]);
    }
    return YES;
}

/// Maps a file into memory, returning NULL on failure.
static struct bsg_feature_flag_file_header * BSGFeatureFlagFileMap(int fd, size_t size) {
    void *ptr = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_FILE | MAP_SHARED, fd, 0);
    if (ptr == MAP_FAILED) {
        const int error = errno;
        bsg_log_warn(@"mmap failed: %d", error);
        errno = error;
        return NULL;
    }
    return ptr;
}

/// Allocates all of a new file's blocks and sets its size. Writing through a mapping into a sparse
/// file can raise SIGBUS or silently lose data if the disk is full, rather than returning an error.
/// (On APFS an overwrite can still need new blocks while the file is in a snapshot, so this reduces
/// rather than removes that risk.)
static BOOL BSGFeatureFlagFileAllocate(int fd, size_t size) {
    fstore_t store = {.fst_flags = F_ALLOCATEALL, .fst_posmode = F_PEOFPOSMODE, .fst_length = (off_t)size};
    if (fcntl(fd, F_PREALLOCATE, &store) == -1) {
        // F_PREALLOCATE is not supported by every file system, so fall back to writing zeros
        const uint8_t zeros[4096] = {0};
        for (size_t offset = 0; offset < size;) {
            const ssize_t written = pwrite(fd, zeros, MIN(sizeof(zeros), size - offset), (off_t)offset);
            if (written <= 0) {
                return NO;
            }
            offset += (size_t)written;
        }
    }
    return ftruncate(fd, (off_t)size) == 0;
}

/// Mappings of a file with NSFileProtectionComplete become invalid 10 seconds after the device is
/// locked. NSFileProtectionCompleteUnlessOpen only keeps a file accessible while it is open, and the
/// descriptor is closed once the file is mapped, and NSFileProtectionCompleteWhenUserInactive makes
/// a file inaccessible after a period of inactivity. So the file is given
/// NSFileProtectionCompleteUntilFirstUserAuthentication, which keeps it accessible while the device
/// is locked once it has been unlocked after starting up.
static BOOL BSGFeatureFlagFileSetProtection(NSString *path) {
    // NSURLFileProtectionKey is unavailable in macOS SDKs prior to 11.0 (see BSGDisableNSFileProtectionComplete)
#if !TARGET_OS_OSX || defined(__MAC_11_0)
    if (@available(macOS 11.0, *)) {
        NSURL *url = [NSURL fileURLWithPath:path];
        NSURLFileProtectionType protection = nil;
        [url getResourceValue:&protection forKey:NSURLFileProtectionKey error:nil];
        // Every other class (Complete, CompleteUnlessOpen, CompleteWhenUserInactive and any newer
        // one) can make the file inaccessible while it is mapped
        if (!protection || [protection isEqualToString:NSURLFileProtectionNone] ||
            [protection isEqualToString:NSURLFileProtectionCompleteUntilFirstUserAuthentication]) {
            return YES;
        }
        NSError *error = nil;
        if (![url setResourceValue:NSURLFileProtectionCompleteUntilFirstUserAuthentication
                            forKey:NSURLFileProtectionKey error:&error]) {
            bsg_log_warn(@"Could not set the file protection of %@: %@", path.lastPathComponent, error);
            return NO;
        }
    }
#else
    (void)(path);
#endif
    return YES;
}

/// Opens a file for memory mapping, applying Bugsnag's backup policy and a file protection class that
/// allows it to be mapped.
static int BSGFeatureFlagFileOpen(NSString *path, int flags) {
    int fd = open(path.fileSystemRepresentation, flags, 0600);
    if (fd == -1) {
        bsg_log_warn(@"Could not open %@: %d", path.lastPathComponent, errno);
        return -1;
    }
    [BSGFilesystem applyFileBackupSupportToPath:path];
    if (!BSGFeatureFlagFileSetProtection(path)) {
        close(fd);
        return -1;
    }
    return fd;
}

#pragma mark - Legacy files

// Earlier versions of the SDK saved each flag in a separate JSON file in the same directory,
// containing its name, variant and the order it was added in. They are read once, to import them.

/// Returns whether a file's contents have the types expected by BSGStoredFeatureFlag. The SDK always
/// wrote a name, so a file without one is not a feature flag file.
static BOOL BSGIsValidStoredFeatureFlag(id content) {
    if (![content isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    id name = content[BSGKeyFeatureFlag];
    id variant = content[BSGKeyVariant];
    id index = content[@"index"];
    return ([name isKindOfClass:[NSString class]] &&
            (!variant || [variant isKindOfClass:[NSString class]]) &&
            (!index || [index isKindOfClass:[NSNumber class]]));
}

static NSArray<NSString *> * BSGLegacyFeatureFlagFilePaths(NSString *directory) {
    NSError *error = nil;
    NSArray<NSString *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:&error];
    if (!files) {
        bsg_log_err(@"Unable to get paths for feature flags: %@", error);
        return @[];
    }
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    for (NSString *file in files) {
        if ([file.pathExtension isEqualToString:@"json"]) {
            [paths addObject:[directory stringByAppendingPathComponent:file]];
        }
    }
    return paths;
}

/// The flags saved as JSON files in the directory, in the order they were added. Files that cannot be
/// read or decoded are skipped.
static NSArray<BugsnagFeatureFlag *> * BSGLegacyFeatureFlags(NSString *directory) {
    NSMutableArray<BSGStoredFeatureFlag *> *storedFlags = [NSMutableArray array];
    for (NSString *path in BSGLegacyFeatureFlagFilePaths(directory)) {
        // A file can be deleted or become unreadable between listing and reading it
        NSData *data = [NSData dataWithContentsOfFile:path];
        id content = data ? [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil] : nil;
        if (content && BSGIsValidStoredFeatureFlag(content)) {
            [storedFlags addObject:[BSGStoredFeatureFlag fromJSON:content]];
        } else {
            bsg_log_err(@"Unable to decode feature flag in %@", path.lastPathComponent);
        }
    }
    // A stable sort keeps files with the same index in the order they were listed
    [storedFlags sortWithOptions:NSSortStable usingComparator:^NSComparisonResult(BSGStoredFeatureFlag * _Nonnull obj1, BSGStoredFeatureFlag * _Nonnull obj2) {
        if (obj1.index == obj2.index) {
            return NSOrderedSame;
        }
        return obj1.index < obj2.index ? NSOrderedAscending : NSOrderedDescending;
    }];
    NSMutableArray<BugsnagFeatureFlag *> *flags = [NSMutableArray arrayWithCapacity:storedFlags.count];
    for (BSGStoredFeatureFlag *storedFlag in storedFlags) {
        [flags addObject:[BugsnagFeatureFlag flagWithName:storedFlag.name variant:storedFlag.variant]];
    }
    return flags;
}

static void BSGRemoveLegacyFeatureFlagFiles(NSString *directory) {
    for (NSString *path in BSGLegacyFeatureFlagFilePaths(directory)) {
        NSError *error = nil;
        if (![[NSFileManager defaultManager] removeItemAtPath:path error:&error] &&
            !([error.domain isEqualToString:NSCocoaErrorDomain] && error.code == NSFileNoSuchFileError)) {
            bsg_log_err(@"Unable to delete a feature flag file: %@", error);
        }
    }
}


@interface BSGPersistentFeatureFlagStore ()

@property (nonatomic, strong) NSString *directoryPath;
@property (nonatomic, strong) NSString *filePath;

// The flags in the order they were last added, which is also the order of their records in a rewritten log
@property (nonatomic, strong) NSMutableOrderedSet<NSString *> *names;
@property (nonatomic, strong) NSMutableDictionary<NSString *, BugsnagFeatureFlag *> *flagsByName;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSData *> *recordsByName;
// The total length of recordsByName, i.e. of a log holding just the current flags
@property (nonatomic) uint64_t liveLength;

@property (nonatomic) struct bsg_feature_flag_file_header *header;
@property (nonatomic) size_t mappedSize;
// The capacity of each slot in the mapping. Offsets are calculated from this rather than from the
// header, which another process using the same file could change.
@property (nonatomic) uint64_t slotCapacity;

// Whether replaying the file's log gives exactly the encodable flags, so that records can be appended to it
@property (nonatomic) BOOL fileIsCurrent;
// The system uptime at which the file can next be replaced after a failure, to avoid repeating the
// failure on every change. Uptime is used because it is not affected by changes to the clock.
@property (nonatomic) NSTimeInterval retryTime;
@property (nonatomic) NSTimeInterval retryInterval;

@end


@implementation BSGPersistentFeatureFlagStore

- (nonnull instancetype)initWithStorageDirectory:(NSString *)directory {
    if ((self = [super init]) != nil) {
        _directoryPath = directory;
        _filePath = [directory stringByAppendingPathComponent:BSGFeatureFlagFileName];
        _retryInterval = BSGFeatureFlagRetryInterval;
        [self removeTemporaryFiles];
        _names = [NSMutableOrderedSet orderedSet];
        _flagsByName = [NSMutableDictionary dictionary];
        _recordsByName = [NSMutableDictionary dictionary];
        if ([self mapExistingFile]) {
            if (BSGLegacyFeatureFlagFilePaths(directory).count) {
                // Both kinds of file are only left together when one of them could not be deleted after
                // the SDK was downgraded and upgraded again. It is not known which of them is current, so
                // neither is used.
                bsg_log_info(@"Discarding persisted feature flags because both flags.bin and JSON files were found");
                [self writeSnapshot];
            } else {
                // This file can be older than the previous launch: SDK versions before 6.31.0 never touch this
                // directory, so it survives a downgrade to one of them and an upgrade again. Its flags are not
                // reported for that launch, because an app upgrade changes the Mach-O UUID and BSGRunContext
                // then does not report an OOM or thermal kill. They are replaced when Bugsnag starts.
                [self loadActiveLog];
            }
        } else {
            // Flags written as individual files by earlier versions of the SDK are imported so that they
            // can be included in an OOM event. If a flags.bin file that could not be used is next to them, it
            // is not known which is current, so they are discarded as above. (Something other than a
            // file at the path, such as a directory, cannot hold flags.)
            struct stat st;
            if (stat(self.filePath.fileSystemRepresentation, &st) != 0 || !S_ISREG(st.st_mode)) {
                for (BugsnagFeatureFlag *flag in BSGLegacyFeatureFlags(directory)) {
                    [self setFlagNamed:flag.name variant:flag.variant];
                }
            } else if (BSGLegacyFeatureFlagFilePaths(directory).count) {
                bsg_log_info(@"Discarding persisted feature flags because both flags.bin and JSON files were found");
            }
            [self writeSnapshot];
        }
        // The JSON files are deleted even if the flags could not be saved, because they would be stale
        // if imported again at the next launch. The imported flags remain in memory.
        BSGRemoveLegacyFeatureFlagFiles(directory);
    }
    return self;
}

- (void)dealloc {
    if (_header) {
        munmap(_header, _mappedSize);
    }
}

#pragma mark - BSGFeatureFlagStore

- (nonnull NSArray<BugsnagFeatureFlag *> *)allFlags {
    @synchronized (self) {
        NSMutableArray<BugsnagFeatureFlag *> *flags = [NSMutableArray arrayWithCapacity:self.names.count];
        for (NSString *name in self.names) {
            BugsnagFeatureFlag *flag = self.flagsByName[name];
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
        if ([self isLastFlagNamed:name withVariant:variant]) {
            // Adding the last flag again with the same variant changes nothing
            return;
        }
        [self appendRecords:[self setFlagNamed:name variant:variant]];
    }
}

- (void)addFeatureFlags:(nonnull NSArray<BugsnagFeatureFlag *> *)featureFlags {
    @synchronized (self) {
        NSMutableData *records = [NSMutableData data];
        for (BugsnagFeatureFlag *flag in featureFlags) {
            [records appendData:[self setFlagNamed:flag.name variant:flag.variant]];
        }
        [self appendRecords:records];
    }
}

- (void)replaceAllFlags:(NSArray<BugsnagFeatureFlag *> *)featureFlags {
    @synchronized (self) {
        [self removeAllFlagsFromMemory];
        for (BugsnagFeatureFlag *flag in featureFlags) {
            [self setFlagNamed:flag.name variant:flag.variant];
        }
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
            [self.flagsByName removeObjectForKey:(NSString *_Nonnull)name];
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

/// A new path for a file that will replace flags.bin. Each replacement uses its own file, so that two
/// stores using the same directory (two clients, or two instances of a macOS app) never write to,
/// truncate or map each other's new file.
- (NSString *)newTemporaryFilePath {
    return [NSString stringWithFormat:@"%@.%@.tmp", self.filePath, NSUUID.UUID.UUIDString];
}

/// Deletes the temporary files left behind by processes that were killed while replacing flags.bin.
/// A temporary file that another store is still writing may also be deleted. That store's mapping is
/// unaffected, and replacing flags.bin with it fails and is retried later.
- (void)removeTemporaryFiles {
    NSString *prefix = [BSGFeatureFlagFileName stringByAppendingString:@"."];
    for (NSString *file in [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.directoryPath error:nil]) {
        if ([file hasPrefix:prefix] && [file.pathExtension isEqualToString:@"tmp"]) {
            unlink([self.directoryPath stringByAppendingPathComponent:file].fileSystemRepresentation);
        }
    }
}

- (BOOL)isLastFlagNamed:(NSString *)name withVariant:(nullable NSString *)variant {
    if (![self.names.lastObject isEqualToString:name]) {
        return NO;
    }
    NSString *current = self.flagsByName[name].variant;
    return current == variant || [current isEqualToString:(NSString *_Nonnull)variant];
}

- (void)setRecord:(nullable NSData *)record forName:(NSString *)name {
    self.liveLength -= self.recordsByName[name].length;
    self.liveLength += record.length;
    self.recordsByName[name] = record;
}

- (void)removeAllFlagsFromMemory {
    [self.names removeAllObjects];
    [self.flagsByName removeAllObjects];
    [self.recordsByName removeAllObjects];
    self.liveLength = 0;
}

/// Adds or replaces a flag, moving it to the end. Returns the records to append to the log.
- (NSData *)setFlagNamed:(NSString *)name variant:(nullable NSString *)variant {
    const BOOL wasPersisted = self.recordsByName[name] != nil;
    [self.names removeObject:name];
    [self.names addObject:name];
    self.flagsByName[name] = [BugsnagFeatureFlag flagWithName:name variant:variant];
    NSData *record = BSGFeatureFlagEncode(name, variant);
    [self setRecord:record forName:name];
    if (record) {
        return record;
    }
    // A flag that cannot be encoded is kept in memory but not persisted, so the persisted
    // record for its previous variant must be removed.
    return (wasPersisted ? BSGFeatureFlagEncodeRemoval(name) : nil) ?: [NSData data];
}

/// Maps the file if it exists and has a valid header.
- (BOOL)mapExistingFile {
    if (access(self.filePath.fileSystemRepresentation, F_OK) != 0) {
        return NO;
    }
    int fd = BSGFeatureFlagFileOpen(self.filePath, O_RDWR);
    if (fd == -1) {
        return NO;
    }
    struct stat st;
    struct bsg_feature_flag_file_header header;
    BOOL valid = (fstat(fd, &st) == 0 &&
                  pread(fd, &header, sizeof(header), 0) == sizeof(header) &&
                  header.magic == BSGFeatureFlagFileMagic &&
                  header.version == BSGFeatureFlagFileVersion &&
                  header.slotCapacity > 0 &&
                  header.slotCapacity <= BSGFeatureFlagMaxSlotCapacity &&
                  BSGFeatureFlagFileSize(header.slotCapacity) <= SIZE_MAX &&
                  (uint64_t)st.st_size >= BSGFeatureFlagFileSize(header.slotCapacity));
    const size_t size = valid ? (size_t)BSGFeatureFlagFileSize(header.slotCapacity) : 0;
    struct bsg_feature_flag_file_header *mapping = valid ? BSGFeatureFlagFileMap(fd, size) : NULL;
    close(fd);
    if (!mapping) {
        return NO;
    }
    [self useMapping:mapping size:size];
    return YES;
}

- (void)useMapping:(struct bsg_feature_flag_file_header *)mapping size:(size_t)size {
    if (self.header) {
        munmap(self.header, self.mappedSize);
    }
    self.header = mapping;
    self.mappedSize = size;
    self.slotCapacity = (size - sizeof(struct bsg_feature_flag_file_header)) / 2;
}

- (uint8_t *)slotData:(uint32_t)slot {
    return (uint8_t *)(self.header + 1) + (size_t)slot * (size_t)self.slotCapacity;
}

- (void)loadActiveLog {
    const uint64_t active = atomic_load_explicit(&self.header->active, memory_order_acquire);
    const uint64_t length = active >> 1;
    BOOL valid = length <= self.slotCapacity &&
    BSGFeatureFlagsDecode([self slotData:active & 1], length, ^(NSString *name, NSString *variant, BOOL removed, NSData *record) {
        [self.names removeObject:name];
        if (removed) {
            [self.flagsByName removeObjectForKey:name];
            [self setRecord:nil forName:name];
        } else {
            [self.names addObject:name];
            self.flagsByName[name] = [BugsnagFeatureFlag flagWithName:name variant:variant];
            [self setRecord:record forName:name];
        }
    });
    if (!valid) {
        bsg_log_err(@"Persisted feature flags are corrupt; discarding them");
        [self removeAllFlagsFromMemory];
        // Publish an empty log so that new records are not appended to the corrupt one
        [self writeSnapshot];
    } else {
        self.fileIsCurrent = YES;
    }
}

/// Appends records to the end of the log, or rewrites it if they don't fit or it has grown too large.
- (BOOL)appendRecords:(NSData *)records {
    if (records.length == 0) {
        return self.fileIsCurrent;
    }
    if (!self.header || !self.fileIsCurrent) {
        return [self writeSnapshot];
    }
    const uint64_t active = atomic_load_explicit(&self.header->active, memory_order_relaxed);
    const uint32_t slot = active & 1;
    const uint64_t length = active >> 1;
    if (length + records.length > self.slotCapacity) {
        return [self writeSnapshot];
    }
    memcpy([self slotData:slot] + length, records.bytes, records.length);
    // The release ordering ensures the records are written before they become part of the log.
    atomic_store_explicit(&self.header->active, BSGFeatureFlagFileActiveValue(length + records.length, slot),
                          memory_order_release);
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
    const uint64_t capacity = self.header ? self.slotCapacity : 0;
    const BOOL canReplaceFile = NSProcessInfo.processInfo.systemUptime >= self.retryTime;
    if (!canReplaceFile && (!self.header || self.liveLength > capacity)) {
        // The flags remain in memory, and are saved by a later change once the file can be replaced
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
    const BOOL fits = self.header && snapshot.length <= capacity;
    const BOOL tooSmall = !self.header || (uint64_t)snapshot.length * 2 > capacity;
    // A file is only shrunk when both the new log and the one it replaces take up very little of it, so
    // that clearing flags and then adding them again does not replace it twice. After the flags are
    // cleared it is therefore shrunk by the next rewrite, which at the latest is when Bugsnag next starts.
    const uint64_t currentLength = self.header ? atomic_load_explicit(&self.header->active, memory_order_relaxed) >> 1 : 0;
    const BOOL tooLarge = (capacity >= BSGFeatureFlagMinimumShrinkableCapacity &&
                           (uint64_t)snapshot.length < capacity / 8 && currentLength < capacity / 8);
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
    }
    if (!fits) {
        // The flags remain in memory, and are saved by a later change once the file can be replaced
        [self discardSnapshot];
        self.fileIsCurrent = NO;
        return NO;
    }
    const uint64_t active = atomic_load_explicit(&self.header->active, memory_order_relaxed);
    const uint32_t slot = (active & 1) ^ 1;
    if (snapshot.length) {
        memcpy([self slotData:slot], snapshot.bytes, snapshot.length);
    }
    // The release ordering ensures the log is written before it becomes active.
    atomic_store_explicit(&self.header->active, BSGFeatureFlagFileActiveValue(snapshot.length, slot),
                          memory_order_release);
    self.fileIsCurrent = YES;
    return YES;
}

/// Empties the log in the current file (if any) after the flags could not be written, so that
/// it does not contain flags that have since been changed or cleared.
- (void)discardSnapshot {
    if (self.header) {
        const uint64_t active = atomic_load_explicit(&self.header->active, memory_order_relaxed);
        atomic_store_explicit(&self.header->active, BSGFeatureFlagFileActiveValue(0, active & 1), memory_order_release);
    } else {
        // A file that exists but could not be mapped holds the flags of an earlier launch
        unlink(self.filePath.fileSystemRepresentation);
    }
}

/// Writes a new file with room for the log to grow and atomically replaces the current one. A file is
/// shrunk to no less than a quarter of its size at a time, so that flags being cleared and then added
/// again do not repeatedly replace it.
- (BOOL)replaceFileWithSnapshot:(NSData *)snapshot {
    const uint64_t pageSize = (uint64_t)getpagesize();
    const uint64_t minimumCapacity = MAX(MAX((uint64_t)snapshot.length * 2,
                                             (pageSize - sizeof(struct bsg_feature_flag_file_header)) / 2),
                                         self.header ? self.slotCapacity / 4 : 0);
    const uint64_t pageAlignedSize = (sizeof(struct bsg_feature_flag_file_header) + 2 * minimumCapacity + pageSize - 1) / pageSize * pageSize;
    const uint64_t slotCapacity = (pageAlignedSize - sizeof(struct bsg_feature_flag_file_header)) / 2;
    if (slotCapacity > BSGFeatureFlagMaxSlotCapacity || pageAlignedSize > SIZE_MAX) {
        bsg_log_err(@"Feature flags are too large to persist");
        return NO;
    }
    const size_t fileSize = (size_t)pageAlignedSize;

    struct bsg_feature_flag_file_header header = {
        .magic = BSGFeatureFlagFileMagic,
        .version = BSGFeatureFlagFileVersion,
        .slotCapacity = (uint32_t)slotCapacity,
    };
    atomic_init(&header.active, BSGFeatureFlagFileActiveValue(snapshot.length, 0));

    NSString *tempPath = [self newTemporaryFilePath];
    int fd = BSGFeatureFlagFileOpen(tempPath, O_RDWR | O_CREAT | O_EXCL);
    if (fd == -1) {
        return NO;
    }
    // The new file is mapped before it replaces the current one, so that the current mapping
    // is only abandoned once the new one is in place.
    struct bsg_feature_flag_file_header *mapping = NULL;
    BOOL written = (BSGFeatureFlagFileAllocate(fd, fileSize) &&
                    pwrite(fd, &header, sizeof(header), 0) == sizeof(header) &&
                    (!snapshot.length || pwrite(fd, snapshot.bytes, snapshot.length, sizeof(header)) == (ssize_t)snapshot.length) &&
                    (mapping = BSGFeatureFlagFileMap(fd, fileSize)) != NULL &&
                    rename(tempPath.fileSystemRepresentation, self.filePath.fileSystemRepresentation) == 0);
    const int error = errno;
    close(fd);
    if (!written) {
        bsg_log_err(@"Unable to save feature flags: %d", error);
        if (mapping) {
            munmap(mapping, fileSize);
        }
        unlink(tempPath.fileSystemRepresentation);
        return NO;
    }
    [self useMapping:mapping size:fileSize];
    return YES;
}

@end
