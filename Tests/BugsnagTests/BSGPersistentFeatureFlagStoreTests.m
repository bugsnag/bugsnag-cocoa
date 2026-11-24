//
//  BSGPersistentFeatureFlagStoreTests.m
//  Bugsnag
//
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import "BSGTestCase.h"

#import "BSGAtomicFeatureFlagStore.h"
#import "BSGCompositeFeatureFlagStore.h"
#import "BSGFeatureFlagFileFormat.h"
#import "BSGLegacyFeatureFlags.h"
#import "BSGMemoryFeatureFlagStore.h"
#import "BSGPersistentFeatureFlagStore.h"
#import "BSGUtils.h"
#import "BugsnagFeatureFlag.h"

#import <errno.h>
#import <fcntl.h>
#import <signal.h>
#import <stdatomic.h>
#import <sys/file.h>
#import <sys/mman.h>
#import <sys/resource.h>
#import <sys/stat.h>

// Layout of the file header; see BSGFeatureFlagFileFormat.h
static const size_t HeaderSize = 32;
static const size_t MagicOffset = 0;
static const size_t VersionOffset = 4;
static const size_t SlotCapacityOffset = 8;
static const size_t ActiveOffset = 16;

#pragma mark - Instrumented store

@interface BSGPersistentFeatureFlagStore (Private)
- (BOOL)writeSnapshot;
- (BOOL)appendRecords:(NSData *)records;
- (BOOL)replaceFileWithSnapshot:(NSData *)snapshot;
- (BOOL)writeActiveLength:(uint64_t)length slot:(uint32_t)slot;
@property (nonatomic) NSTimeInterval retryInterval;
@property (nonatomic) NSTimeInterval retryTime;
@property (nonatomic) BOOL fileIsCurrent;
@property (nonatomic) int lockFd;
@property (nonatomic) int fd;
@property (nonatomic) BOOL lockGivenUp;
@property (nonatomic) uint64_t slotCapacity;
@property (nonatomic, strong) NSArray<NSString *> *pendingLegacyPaths;
@property (nonatomic) NSTimeInterval compactionRetryTime;
@property (nonatomic) BOOL directoryAtFilePath;
- (BOOL)hasPendingWork;
- (void)protectedDataDidBecomeAvailable;
@end

/// Waits until the store holds the lock and has saved, without taking the lock itself (so never competing with a
/// retry).
static BOOL BSGWaitUntilStoreHasSaved(BSGPersistentFeatureFlagStore *store, NSTimeInterval timeout) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while (YES) {
        @synchronized (store) {
            if (store.lockFd != -1 && store.fileIsCurrent) {
                return YES;
            }
        }
        if (deadline.timeIntervalSinceNow < 0) {
            return NO;
        }
        [NSThread sleepForTimeInterval:0.01];
    }
}

/// The flags in featureflag.bin as [name, variant or NSNull] pairs, or [] if there is no valid file. Decoded without a
/// store, because a store created while another holds the lock reports none.
static NSArray<NSArray *> * BSGFlagsInFeatureFlagFile(NSString *directory) {
    NSString *path = [directory stringByAppendingPathComponent:@"featureflag.bin"];
    struct stat st;
    if (lstat(path.fileSystemRepresentation, &st) != 0 || !S_ISREG(st.st_mode)) {
        return @[];
    }
    NSData *data = [NSData dataWithContentsOfFile:path];
    struct bsg_feature_flag_file_header header;
    if (data.length < sizeof(header)) {
        return @[];
    }
    [data getBytes:&header length:sizeof(header)];
    const uint64_t length = header.active >> 1;
    const uint64_t offset = BSGFeatureFlagSlotOffset(header.slotCapacity, header.active & 1);
    if (header.magic != BSGFeatureFlagFileMagic || header.version != BSGFeatureFlagFileVersion ||
        length > header.slotCapacity || offset + length > data.length) {
        return @[];
    }
    NSMutableOrderedSet<NSString *> *names = [NSMutableOrderedSet orderedSet];
    NSMutableDictionary<NSString *, id> *variants = [NSMutableDictionary dictionary];
    const BOOL decoded = BSGFeatureFlagsDecode([data subdataWithRange:NSMakeRange((NSUInteger)offset, (NSUInteger)length)],
                                               ^(NSString *name, NSString *variant, BOOL removed, __unused NSData *record) {
        if (removed) {
            [names removeObject:name];
            [variants removeObjectForKey:name];
        } else {
            // An existing flag keeps its position, as in the store
            [names addObject:name];
            variants[name] = variant ?: NSNull.null;
        }
    });
    if (!decoded) {
        return @[];
    }
    NSMutableArray<NSArray *> *flags = [NSMutableArray arrayWithCapacity:names.count];
    for (NSString *name in names) {
        [flags addObject:@[name, variants[name]]];
    }
    return flags;
}

/// The flags the next launch reads: from a new store if it can take the lock (importing JSON files), else decoded from
/// featureflag.bin.
static NSArray<NSArray *> * BSGReopenedFlags(NSString *directory) {
    @autoreleasepool {
        BSGPersistentFeatureFlagStore *store = [[BSGPersistentFeatureFlagStore alloc] initWithStorageDirectory:directory];
        if (store.lockFd == -1 && [NSFileManager.defaultManager fileExistsAtPath:[directory stringByAppendingPathComponent:@"featureflag.lock"]]) {
            return BSGFlagsInFeatureFlagFile(directory);
        }
        NSMutableArray<NSArray *> *flags = [NSMutableArray array];
        for (BugsnagFeatureFlag *flag in store.allFlags) {
            [flags addObject:@[flag.name, flag.variant ?: NSNull.null]];
        }
        return flags;
    }
}

#if defined(DEBUG) && DEBUG
// retryScheduler is debug-only, so this class and its tests are too
/// Queues scheduled retries instead of running them, so tests decide when they run. Retries hold their stores weakly.
@interface BSGManualRetryScheduler : NSObject
/// The delay of each retry scheduled so far, in order.
@property (nonatomic, readonly) NSMutableArray<NSNumber *> *delays;
@property (nonatomic, readonly) NSMutableArray<dispatch_block_t> *pendingRetries;
- (void)attachToStore:(BSGPersistentFeatureFlagStore *)store;
/// Runs the pending retries in order and returns how many ran. Only the latest does anything; retries they schedule
/// stay pending.
- (NSUInteger)runPendingRetries;
@end

@implementation BSGManualRetryScheduler

- (instancetype)init {
    if ((self = [super init])) {
        _delays = [NSMutableArray array];
        _pendingRetries = [NSMutableArray array];
    }
    return self;
}

- (void)attachToStore:(BSGPersistentFeatureFlagStore *)store {
    __weak typeof(self) weakSelf = self;
    store.retryScheduler = ^(NSTimeInterval delay, dispatch_block_t retry) {
        typeof(self) strongSelf = weakSelf;
        [strongSelf.delays addObject:@(delay)];
        [strongSelf.pendingRetries addObject:retry];
    };
}

- (NSUInteger)runPendingRetries {
    NSArray<dispatch_block_t> *retries = [self.pendingRetries copy];
    [self.pendingRetries removeAllObjects];
    for (dispatch_block_t retry in retries) {
        retry();
    }
    return retries.count;
}

@end
#endif

/// A store whose file can never be replaced, as when the disk is full.
@interface BSGUnreplaceablePersistentFeatureFlagStore : BSGPersistentFeatureFlagStore
@end

@implementation BSGUnreplaceablePersistentFeatureFlagStore

- (BOOL)replaceFileWithSnapshot:(__unused NSData *)snapshot {
    return NO;
}

@end

/// Counts calls to the store's private methods.
@interface BSGCountingPersistentFeatureFlagStore : BSGPersistentFeatureFlagStore
@property (nonatomic) NSUInteger snapshotCount;
@property (nonatomic) NSUInteger appendCount;
@property (nonatomic) NSUInteger replaceFileCount;
@property (nonatomic) NSUInteger clearCount;
// Header active-value writes; every write to an open file ends with one
@property (nonatomic) NSUInteger headerWriteCount;
@end

@implementation BSGCountingPersistentFeatureFlagStore

- (BOOL)writeSnapshot {
    self.snapshotCount++;
    return [super writeSnapshot];
}

- (BOOL)appendRecords:(NSData *)records {
    self.appendCount++;
    return [super appendRecords:records];
}

- (BOOL)replaceFileWithSnapshot:(NSData *)snapshot {
    self.replaceFileCount++;
    return [super replaceFileWithSnapshot:snapshot];
}

- (void)clear {
    self.clearCount++;
    [super clear];
}

- (BOOL)writeActiveLength:(uint64_t)length slot:(uint32_t)slot {
    self.headerWriteCount++;
    return [super writeActiveLength:length slot:slot];
}

/// File replacements plus header writes.
- (NSUInteger)writeCount {
    return self.replaceFileCount + self.headerWriteCount;
}

@end

/// Fails replaceFile while failReplaceFile is set, or substitutes replacementSnapshot.
@interface BSGFailingPersistentFeatureFlagStore : BSGCountingPersistentFeatureFlagStore
@property (nonatomic) BOOL failReplaceFile;
@property (nonatomic) NSData *replacementSnapshot;
@end

@implementation BSGFailingPersistentFeatureFlagStore

- (BOOL)replaceFileWithSnapshot:(NSData *)snapshot {
    if (self.failReplaceFile) {
        self.replaceFileCount++;
        return NO;
    }
    return [super replaceFileWithSnapshot:self.replacementSnapshot ?: snapshot];
}

@end

/// Also fails the next failHeaderWrites header writes with EIO, so both ways of writing a log fail in one attempt.
@interface BSGDoublyFailingPersistentFeatureFlagStore : BSGFailingPersistentFeatureFlagStore
@property (nonatomic) NSUInteger failHeaderWrites;
@end

@implementation BSGDoublyFailingPersistentFeatureFlagStore

- (BOOL)writeActiveLength:(uint64_t)length slot:(uint32_t)slot {
    if (self.failHeaderWrites > 0) {
        self.failHeaderWrites--;
        errno = EIO;
        return NO;
    }
    return [super writeActiveLength:length slot:slot];
}

@end

/// Fails the next failHeaderWrites header writes with EIO, leaving records written but not committed by the header.
@interface BSGHeaderFailingPersistentFeatureFlagStore : BSGPersistentFeatureFlagStore
@property (nonatomic) NSUInteger failHeaderWrites;
@end

@implementation BSGHeaderFailingPersistentFeatureFlagStore

- (BOOL)writeActiveLength:(uint64_t)length slot:(uint32_t)slot {
    if (self.failHeaderWrites > 0) {
        self.failHeaderWrites--;
        errno = EIO;
        return NO;
    }
    return [super writeActiveLength:length slot:slot];
}

@end

/// The running test's directory. Swapped-in file functions are global and stores left from earlier tests may call them,
/// so simulations and counters act only on this directory and pass other paths through.
static NSString *gTestDirectory;

static BOOL BSGIsInTestDirectory(NSString *path) {
    NSString *directory = gTestDirectory;
    return directory && [path hasPrefix:[directory stringByAppendingString:@"/"]];
}

/// Whether the descriptor is in the test's directory, matched on its unique (UUID) name since the path may differ
/// (/private/var vs /var).
static BOOL BSGDescriptorIsInTestDirectory(int fd) {
    NSString *directory = gTestDirectory;
    char path[MAXPATHLEN] = {0};
    if (!directory || fcntl(fd, F_GETPATH, path) != 0) {
        return NO;
    }
    NSString *component = [NSString stringWithFormat:@"/%@/", directory.lastPathComponent];
    return [@(path) containsString:component];
}

/// Runs the block with RLIMIT_FSIZE at `limit`, so writes past it fail with EFBIG (or are cut short) as on a full disk;
/// SIGXFSZ is ignored meanwhile. Returns NO if the limit can't be set. The limit is process-wide, so it is always
/// restored and the block must be short.
static BOOL BSGWithFileSizeLimit(rlim_t limit, void (^ block)(void)) {
    struct rlimit original;
    if (getrlimit(RLIMIT_FSIZE, &original) != 0 || limit > original.rlim_max) {
        return NO;
    }
    void (*previousHandler)(int) = signal(SIGXFSZ, SIG_IGN);
    const struct rlimit limited = {limit, original.rlim_max};
    if (setrlimit(RLIMIT_FSIZE, &limited) != 0) {
        signal(SIGXFSZ, previousHandler);
        return NO;
    }
    @try {
        block();
    } @finally {
        setrlimit(RLIMIT_FSIZE, &original);
        signal(SIGXFSZ, previousHandler);
    }
    return YES;
}

static NSArray * FlagNames(NSArray<BugsnagFeatureFlag *> *flags) {
    return [flags valueForKey:@"name"];
}

/// Makes featureflag.lock unopenable (EACCES), as when protected data is unavailable: a failure that clears, so the
/// store retries the lock. Returns NO for root.
static BOOL BSGMakeLockFileUnopenable(NSString *directory) {
    NSString *path = [directory stringByAppendingPathComponent:@"featureflag.lock"];
    return geteuid() != 0 && chmod(path.fileSystemRepresentation, 0) == 0;
}

static void BSGRestoreLockFile(NSString *directory) {
    chmod([directory stringByAppendingPathComponent:@"featureflag.lock"].fileSystemRepresentation, 0600);
}

/// Records the BSGFeatureFlagStore methods that are called.
@interface BSGRecordingFeatureFlagStore : NSObject <BSGReplaceableFeatureFlagStore>
@property (nonatomic) NSMutableArray *calls;
@end

@implementation BSGRecordingFeatureFlagStore

- (instancetype)init {
    if ((self = [super init])) {
        _calls = [NSMutableArray array];
    }
    return self;
}

- (NSArray<BugsnagFeatureFlag *> *)allFlags {
    return @[];
}

- (BOOL)isEmpty {
    return YES;
}

- (void)addFeatureFlag:(NSString *)name withVariant:(NSString *)variant {
    [self.calls addObject:@"addFeatureFlag:withVariant:"];
}

- (void)addFeatureFlags:(NSArray<BugsnagFeatureFlag *> *)featureFlags {
    [self.calls addObject:@"addFeatureFlags:"];
}

- (void)clear:(NSString *)name {
    [self.calls addObject:@"clear:"];
}

- (void)clear {
    [self.calls addObject:@"clear"];
}

- (void)replaceAllFlags:(NSArray<BugsnagFeatureFlag *> *)featureFlags {
    [self.calls addObject:@[@"replaceAllFlags:", FlagNames(featureFlags)]];
}

@end

/// A memory store with replaceAllFlags: (the SDK's lacks it, as nothing calls it), used as a stand-in or as the
/// reference order.
@interface BSGReplaceableMemoryFeatureFlagStore : BSGMemoryFeatureFlagStore <BSGReplaceableFeatureFlagStore>
@end

@implementation BSGReplaceableMemoryFeatureFlagStore

- (void)replaceAllFlags:(NSArray<BugsnagFeatureFlag *> *)featureFlags {
    [self clear];
    [self addFeatureFlags:featureFlags];
}

@end

#pragma mark -

@interface BSGPersistentFeatureFlagStoreTests : BSGTestCase

@property (nonatomic) NSString *directory;

@end

@implementation BSGPersistentFeatureFlagStoreTests

- (void)setUp {
    [super setUp];
    self.directory = [NSTemporaryDirectory() stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"BSGPersistentFeatureFlagStoreTests-%@", NSUUID.UUID.UUIDString]];
    [NSFileManager.defaultManager createDirectoryAtPath:self.directory withIntermediateDirectories:YES attributes:nil error:nil];
    gTestDirectory = self.directory;
}

- (void)tearDown {
    gTestDirectory = nil;
    // In case testUnwritableDirectoryAfterTheFileIsCreated failed midway
    chmod(self.directory.fileSystemRepresentation, 0700);
    [NSFileManager.defaultManager removeItemAtPath:self.directory error:nil];
    [super tearDown];
}

#pragma mark Helpers

- (NSString *)filePath {
    return [self.directory stringByAppendingPathComponent:@"featureflag.bin"];
}

/// Named "new" so ARC returns it retained: a store holds the lock until deallocated, so release one-off stores at once.
- (BSGPersistentFeatureFlagStore *)newStore {
    return [[BSGPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
}

static NSArray * FlagsToArray(NSArray<BugsnagFeatureFlag *> *flags) {
    NSMutableArray *result = [NSMutableArray array];
    for (BugsnagFeatureFlag *flag in flags) {
        [result addObject:@[flag.name, flag.variant ?: NSNull.null]];
    }
    return result;
}

- (NSArray *)reopenedFlags {
    return BSGReopenedFlags(self.directory);
}

/// A store that has replaced its flags with those it read, as at Bugsnag start. That write deletes imported JSON files.
- (BSGPersistentFeatureFlagStore *)newStartedStore {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store replaceAllFlags:store.allFlags];
    return store;
}

- (uint64_t)activeValue {
    NSData *data = [NSData dataWithContentsOfFile:self.filePath];
    uint64_t active = 0;
    if (data.length >= HeaderSize) {
        [data getBytes:&active range:NSMakeRange(ActiveOffset, sizeof(active))];
    }
    return active;
}

- (uint32_t)headerFieldAtOffset:(size_t)offset {
    NSData *data = [NSData dataWithContentsOfFile:self.filePath];
    uint32_t value = 0;
    if (data.length >= HeaderSize) {
        [data getBytes:&value range:NSMakeRange(offset, sizeof(value))];
    }
    return value;
}

- (void)replaceFileBytesAtOffset:(size_t)offset withBytes:(const void *)bytes length:(size_t)length {
    NSMutableData *data = [NSMutableData dataWithContentsOfFile:self.filePath];
    [data replaceBytesInRange:NSMakeRange(offset, length) withBytes:bytes];
    [data writeToFile:self.filePath atomically:NO];
}

/// Offset of the active snapshot.
- (size_t)activeSlotOffset {
    return HeaderSize + ([self activeValue] & 1) * [self headerFieldAtOffset:SlotCapacityOffset];
}

- (void)assertFileIsAValidEmptySnapshot {
    XCTAssertEqual([self headerFieldAtOffset:MagicOffset], 0x46465342);
    XCTAssertEqual([self headerFieldAtOffset:VersionOffset], 1);
    XCTAssertGreaterThan([self headerFieldAtOffset:SlotCapacityOffset], 0);
    XCTAssertEqual([self activeValue] >> 1, 0);
}

- (void)assertUnusableFileWasRemoved {
    // An unusable file with nothing to save is removed, not replaced
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:self.filePath]);
}

- (void)writeLegacyJSON:(NSString *)json toFile:(NSString *)name {
    [[json dataUsingEncoding:NSUTF8StringEncoding] writeToFile:[self.directory stringByAppendingPathComponent:name] atomically:YES];
}

- (void)writeLegacyFlag:(NSString *)name variant:(NSString *)variant index:(uint64_t)index {
    // The format written by earlier versions of the SDK
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    json[@"featureFlag"] = name;
    json[@"index"] = @(index);
    if (variant) {
        json[@"variant"] = variant;
    }
    NSString *fileName = [name stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.alphanumericCharacterSet];
    NSString *path = [self.directory stringByAppendingPathComponent:[fileName stringByAppendingString:@".json"]];
    [[NSJSONSerialization dataWithJSONObject:json options:0 error:nil] writeToFile:path atomically:YES];
}

- (NSArray<NSString *> *)jsonFiles {
    NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.directory error:nil];
    return [files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.json'"]];
}

#pragma mark Basic operations

- (void)testInitiallyEmpty {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    XCTAssertTrue(store.isEmpty);
    XCTAssertEqualObjects(store.allFlags, @[]);
    // Not created until there is something to save
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:self.filePath]);
    XCTAssertEqualObjects([self reopenedFlags], @[]);

    [store addFeatureFlag:@"a" withVariant:nil];
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:self.filePath]);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", NSNull.null]]));
}

- (void)testAddAndReopen {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    [store addFeatureFlag:@"b" withVariant:nil];
    [store addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:@"c" variant:@"3"],
                             [BugsnagFeatureFlag flagWithName:@"d"]]];
    NSArray *expected = @[@[@"a", @"1"], @[@"b", NSNull.null], @[@"c", @"3"], @[@"d", NSNull.null]];
    XCTAssertFalse(store.isEmpty);
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), expected);
    XCTAssertEqualObjects([self reopenedFlags], expected);
}

- (void)testOverwriteKeepsThePosition {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    [store addFeatureFlag:@"b" withVariant:@"2"];
    [store addFeatureFlag:@"c" withVariant:@"3"];
    [store addFeatureFlag:@"a" withVariant:@"1b"];
    [store addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:@"b" variant:nil],
                             [BugsnagFeatureFlag flagWithName:@"e" variant:@"5"]]];
    NSArray *expected = @[@[@"a", @"1b"], @[@"b", NSNull.null], @[@"c", @"3"], @[@"e", @"5"]];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), expected);
    XCTAssertEqualObjects([self reopenedFlags], expected);
}

- (void)testClearNamedFlag {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    [store addFeatureFlag:@"b" withVariant:@"2"];
    [store addFeatureFlag:@"c" withVariant:@"3"];
    [store clear:@"b"];
    [store clear:@"unknown"];
    NSArray *expected = @[@[@"a", @"1"], @[@"c", @"3"]];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), expected);
    XCTAssertEqualObjects([self reopenedFlags], expected);
}

- (void)testMutableNameChangedAfterAddingDoesNotAffectTheFlag {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    NSMutableString *name = [NSMutableString stringWithString:@"a"];
    [store addFeatureFlag:name withVariant:@"1"];
    [name setString:@"b"];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), (@[@[@"a", @"1"]]));

    [store clear:@"a"];
    XCTAssertTrue(store.isEmpty);
    XCTAssertEqualObjects([self reopenedFlags], @[]);
}

- (void)testClearAll {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    [store addFeatureFlag:@"b" withVariant:@"2"];
    [store clear];
    XCTAssertTrue(store.isEmpty);
    XCTAssertEqualObjects([self reopenedFlags], @[]);

    [store addFeatureFlag:@"c" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"c", NSNull.null]]));

    // clear: with a nil name clears everything
    [store clear:nil];
    XCTAssertEqualObjects([self reopenedFlags], @[]);
}

- (void)testReopenedStoreCanBeModified {
    [[self newStore] addFeatureFlag:@"a" withVariant:@"1"];
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store addFeatureFlag:@"b" withVariant:@"2"];
    [store addFeatureFlag:@"a" withVariant:@"3"];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"3"], @[@"b", @"2"]]));
}

#pragma mark Encoding

- (void)testNilAndEmptyVariantsAreDistinct {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store addFeatureFlag:@"nil" withVariant:nil];
    [store addFeatureFlag:@"empty" withVariant:@""];
    [store addFeatureFlag:@"" withVariant:@"empty name"];
    store = nil;
    NSArray<BugsnagFeatureFlag *> *flags = [self newStore].allFlags;
    XCTAssertEqual(flags.count, 3);
    XCTAssertEqualObjects(flags[0].name, @"nil");
    XCTAssertNil(flags[0].variant);
    XCTAssertEqualObjects(flags[1].name, @"empty");
    XCTAssertEqualObjects(flags[1].variant, @"");
    XCTAssertEqualObjects(flags[2].name, @"");
    XCTAssertEqualObjects(flags[2].variant, @"empty name");
}

- (void)testLastEntryWithEmptyNameAndNoVariant {
    // An empty name with no variant is just the two lengths
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store addFeatureFlag:@"" withVariant:nil];
    XCTAssertEqual([self activeValue] >> 1, 8);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"", NSNull.null]]));

    [store addFeatureFlag:@"a" withVariant:@"1"];
    [store addFeatureFlag:@"" withVariant:@"x"];
    [store addFeatureFlag:@"" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"", NSNull.null], @[@"a", @"1"]]));
}

- (void)testUnicodeNames {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store addFeatureFlag:@"フラグ🚩" withVariant:@"variante-é"];
    [store addFeatureFlag:@"Ελληνικά name" withVariant:@"👩‍👩‍👧‍👦"];
    NSArray *expected = @[@[@"フラグ🚩", @"variante-é"], @[@"Ελληνικά name", @"👩‍👩‍👧‍👦"]];
    XCTAssertEqualObjects([self reopenedFlags], expected);
}

- (void)testLongNames {
    NSString *longName = [@"" stringByPaddingToLength:10 * 1024 withString:@"n" startingAtIndex:0];
    NSString *longVariant = [@"" stringByPaddingToLength:10 * 1024 withString:@"vé" startingAtIndex:0];
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store addFeatureFlag:@"short" withVariant:nil];
    [store addFeatureFlag:longName withVariant:longVariant];
    [store addFeatureFlag:@"after" withVariant:@"x"];
    NSArray *expected = @[@[@"short", NSNull.null], @[longName, longVariant], @[@"after", @"x"]];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), expected);
    XCTAssertEqualObjects([self reopenedFlags], expected);
}

#pragma mark Growth

- (void)assertGrowthWithCount:(NSUInteger)count {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    NSMutableArray *expected = [NSMutableArray array];
    for (NSUInteger i = 0; i < count; i++) {
        NSString *name = [NSString stringWithFormat:@"flag-%lu", (unsigned long)i];
        NSString *variant = i % 3 ? [NSString stringWithFormat:@"variant-%lu", (unsigned long)i] : nil;
        [store addFeatureFlag:name withVariant:variant];
        [expected addObject:@[name, variant ?: NSNull.null]];
    }
    XCTAssertGreaterThan([[NSFileManager.defaultManager attributesOfItemAtPath:self.filePath error:nil] fileSize],
                         (unsigned long long)getpagesize());
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), expected);
    XCTAssertEqualObjects([self reopenedFlags], expected);

    // Shrinking keeps the larger file
    [store clear:@"flag-0"];
    [expected removeObjectAtIndex:0];
    XCTAssertEqualObjects([self reopenedFlags], expected);
}

- (void)assertFileSizeMatchesTheHeader {
    const unsigned long long size = [[NSFileManager.defaultManager attributesOfItemAtPath:self.filePath error:nil] fileSize];
    XCTAssertEqual(size, HeaderSize + 2 * (unsigned long long)[self headerFieldAtOffset:SlotCapacityOffset]);
}

- (void)testFileSizeMatchesTheHeader {
    // Created whole (not preallocated, so possibly sparse); grows by being replaced
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store addFeatureFlag:@"a" withVariant:nil];
    [self assertFileSizeMatchesTheHeader];
    const unsigned long long initialSize = [[NSFileManager.defaultManager attributesOfItemAtPath:self.filePath error:nil] fileSize];
    for (NSUInteger i = 0; i < 10000; i++) {
        [store addFeatureFlag:[NSString stringWithFormat:@"flag-%lu", (unsigned long)i] withVariant:@"variant"];
    }
    XCTAssertGreaterThan([[NSFileManager.defaultManager attributesOfItemAtPath:self.filePath error:nil] fileSize], initialSize);
    [self assertFileSizeMatchesTheHeader];
}

- (void)testGrowthTo1000Flags {
    [self assertGrowthWithCount:1000];
}

- (void)testGrowthTo10000Flags {
    [self assertGrowthWithCount:10000];
}

- (void)testGrowthWithBatchAdd {
    NSMutableArray *flags = [NSMutableArray array];
    for (NSUInteger i = 0; i < 5000; i++) {
        [flags addObject:[BugsnagFeatureFlag flagWithName:[NSString stringWithFormat:@"batch-%lu", (unsigned long)i] variant:@"v"]];
    }
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store addFeatureFlag:@"first" withVariant:nil];
    [store addFeatureFlags:flags];
    NSArray *reopened = [self reopenedFlags];
    XCTAssertEqual(reopened.count, 5001);
    XCTAssertEqualObjects(reopened.firstObject, (@[@"first", NSNull.null]));
    XCTAssertEqualObjects(reopened.lastObject, (@[@"batch-4999", @"v"]));
}

#pragma mark Append vs snapshot

- (void)testNewFlagsAreAppendedToTheActiveSlot {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    const uint64_t before = [self activeValue];
    [store addFeatureFlag:@"b" withVariant:@"2"];
    [store addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:@"c"]]];
    const uint64_t after = [self activeValue];
    XCTAssertEqual(after & 1, before & 1, @"Appending should not switch slots");
    // Entry: two uint32 lengths, then name and variant
    XCTAssertEqual((after >> 1) - (before >> 1), (uint64_t)(8 + 2 + 8 + 1));
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"], @[@"b", @"2"], @[@"c", NSNull.null]]));
}

- (void)testChangesAreAppendedToTheActiveSlot {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    [store addFeatureFlag:@"b" withVariant:@"2"];

    uint64_t before = [self activeValue];
    [store addFeatureFlag:@"a" withVariant:@"3"];
    uint64_t after = [self activeValue];
    XCTAssertEqual(after & 1, before & 1, @"Overwriting should append a record");
    XCTAssertEqual((after >> 1) - (before >> 1), (uint64_t)(8 + 1 + 1));

    before = after;
    [store clear:@"b"];
    after = [self activeValue];
    XCTAssertEqual(after & 1, before & 1, @"Clearing should append a record");
    // Removal record: name length, UINT32_MAX - 1, name
    XCTAssertEqual((after >> 1) - (before >> 1), (uint64_t)(8 + 1));

    before = after;
    [store addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:@"new"], [BugsnagFeatureFlag flagWithName:@"a"]]];
    after = [self activeValue];
    XCTAssertEqual(after & 1, before & 1, @"A batch containing an existing flag should append records");

    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", NSNull.null], @[@"new", NSNull.null]]));
}

- (void)testChangesNeverRewriteTheLog {
    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    // The file is created by the first change
    [store addFeatureFlag:@"first" withVariant:nil];
    store.snapshotCount = 0;
    store.appendCount = 0;
    [store addFeatureFlag:@"a" withVariant:nil];
    [store addFeatureFlag:@"b" withVariant:nil];
    [store addFeatureFlag:@"a" withVariant:@"x"];
    [store clear:@"b"];
    XCTAssertEqual(store.appendCount, 4);
    XCTAssertEqual(store.snapshotCount, 0);
}

- (void)testClearAllWritesAnEmptyLogToTheOtherSlot {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    const uint64_t before = [self activeValue];
    [store clear];
    const uint64_t after = [self activeValue];
    XCTAssertNotEqual(after & 1, before & 1, @"Clearing all flags should switch slots");
    XCTAssertEqual(after >> 1, 0);
    XCTAssertEqualObjects([self reopenedFlags], @[]);
}

- (void)testClearingAnEmptyCurrentFileWritesNothing {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    [store clear];
    const uint64_t empty = [self activeValue];
    XCTAssertEqual(empty >> 1, 0);

    // The log is already empty and current, so clearing again doesn't switch slots
    [store clear];
    [store clear];
    XCTAssertEqual([self activeValue], empty);
    XCTAssertEqualObjects([self reopenedFlags], @[]);
}

- (void)testClearingAnEmptyFileStillDeletesPendingJSONFiles {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    [store clear];
    // JSON files are still pending deletion, so clearing is not skipped
    [self writeLegacyFlag:@"legacy" variant:@"1" index:0];
    NSString *legacyPath = [self.directory stringByAppendingPathComponent:@"legacy.json"];
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:legacyPath]);
    store.pendingLegacyPaths = @[legacyPath];

    [store clear];
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:legacyPath]);
    XCTAssertEqualObjects(store.pendingLegacyPaths, @[]);
    XCTAssertEqualObjects([self reopenedFlags], @[]);
}

- (void)testRemovalRecordsAreReplayed {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    [store addFeatureFlag:@"b" withVariant:nil];
    [store addFeatureFlag:@"c" withVariant:@""];
    [store clear:@"b"];
    [store addFeatureFlag:@"b" withVariant:@"again"];
    [store clear:@"a"];
    [store clear:@"not-present"];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"c", @""], @[@"b", @"again"]]));
    XCTAssertEqualObjects([self reopenedFlags], FlagsToArray(store.allFlags));
}

- (void)testLogIsCompactedIntoTheOtherSlot {
    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    [store addFeatureFlag:@"b" withVariant:@"1"];
    store.snapshotCount = 0;
    // Each change appends 10 bytes; the log is compacted at 4096 dead bytes, or sooner in smaller (4 KB page) slots
    uint64_t longestLog = 0;
    for (int i = 0; i < 1000; i++) {
        [store addFeatureFlag:(i % 2) ? @"a" : @"b" withVariant:[NSString stringWithFormat:@"%d", i % 10]];
        longestLog = MAX(longestLog, [self activeValue] >> 1);
    }
    // Live flags take 20 bytes, so the log never holds over 4096 dead bytes
    XCTAssertLessThanOrEqual(longestLog, (uint64_t)(4096 + 2 * 10 + 10));
    XCTAssertGreaterThan(store.snapshotCount, 0);
    XCTAssertLessThan(store.snapshotCount, 10, @"The log should only be rewritten once it has doubled");
    XCTAssertEqual(store.replaceFileCount, 1, @"Rewriting the log should not grow the file");
    XCTAssertLessThanOrEqual([self activeValue] >> 1, (uint64_t)(4096 + 2 * 10));
    XCTAssertEqualObjects([self reopenedFlags], FlagsToArray(store.allFlags));
}

- (void)testAddingAFlagAgainWithTheSameVariantDoesNotWrite {
    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    [store addFeatureFlag:@"b" withVariant:nil];
    const uint64_t before = [self activeValue];
    store.appendCount = 0;
    store.snapshotCount = 0;
    [store addFeatureFlag:@"b" withVariant:nil];
    XCTAssertEqual([self activeValue], before);
    XCTAssertEqual(store.appendCount, 0);
    XCTAssertEqual(store.snapshotCount, 0);
    // Nor does re-adding one that is not last: it keeps its position
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqual([self activeValue], before);
    XCTAssertEqual(store.appendCount, 0);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"], @[@"b", NSNull.null]]));
    // An empty variant is not the same as no variant
    [store addFeatureFlag:@"a" withVariant:@""];
    XCTAssertEqual(store.appendCount, 1);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @""], @[@"b", NSNull.null]]));
}

- (void)testFileGrowsOnceTheFlagsTakeUpHalfASlot {
    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    // The file is created by the first change
    [store addFeatureFlag:@"first" withVariant:nil];
    const uint32_t capacity = [self headerFieldAtOffset:SlotCapacityOffset];
    XCTAssertGreaterThan(capacity, 0);
    // Fill most of a slot one flag at a time, then keep changing one
    NSUInteger count = 0;
    while ([self activeValue] >> 1 < capacity * 3 / 4 && [self headerFieldAtOffset:SlotCapacityOffset] == capacity) {
        [store addFeatureFlag:[NSString stringWithFormat:@"flag-%05lu", (unsigned long)count++] withVariant:@"v"];
    }
    store.snapshotCount = 0;
    for (int i = 0; i < 1000; i++) {
        [store addFeatureFlag:@"flag-00000" withVariant:[NSString stringWithFormat:@"%d", i % 2]];
    }
    XCTAssertGreaterThan([self headerFieldAtOffset:SlotCapacityOffset], capacity,
                         @"The file should grow once the flags take up more than half of a slot");
    XCTAssertLessThan(store.snapshotCount, 20, @"Changes should not rewrite the log every time");
    XCTAssertEqualObjects([self reopenedFlags], FlagsToArray(store.allFlags));
}

- (void)testUnencodableFlagsAreNotPersisted {
    const unichar loneSurrogate = 0xD800;
    NSString *unencodable = [NSString stringWithCharacters:&loneSurrogate length:1];
    XCTAssertNil([unencodable dataUsingEncoding:NSUTF8StringEncoding]);
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    [store addFeatureFlag:@"b" withVariant:@"1"];
    // An unencodable variant removes the persisted record
    [store addFeatureFlag:@"a" withVariant:unencodable];
    [store addFeatureFlag:unencodable withVariant:@"1"];
    XCTAssertEqual(store.allFlags.count, 3);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"b", @"1"]]));
    // A batch mixing both
    [store addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:@"c" variant:@"1"],
                             [BugsnagFeatureFlag flagWithName:@"b" variant:unencodable],
                             [BugsnagFeatureFlag flagWithName:@"c" variant:unencodable],
                             [BugsnagFeatureFlag flagWithName:@"d" variant:nil]]];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"d", NSNull.null]]));
    // Clearing flags that were never persisted
    [store clear:unencodable];
    [store clear:@"a"];
    XCTAssertEqual(store.allFlags.count, 3);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"d", NSNull.null]]));
    // Encodable again: b must stay before c and d, so the log is rewritten (an appended record would move b to the end)
    [store addFeatureFlag:@"b" withVariant:@"2"];
    XCTAssertEqualObjects(FlagNames(store.allFlags), (@[@"b", @"c", @"d"]));
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"b", @"2"], @[@"d", NSNull.null]]));
}

- (void)testLeadingByteOrderMarksAreKept {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    [store addFeatureFlag:@"\uFEFFa" withVariant:@"\uFEFFv"];
    [store addFeatureFlag:@"\uFEFF" withVariant:@"\uFEFF\uFEFF"];
    NSArray *expected = @[@[@"a", @"1"], @[@"\uFEFFa", @"\uFEFFv"], @[@"\uFEFF", @"\uFEFF\uFEFF"]];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), expected);
    XCTAssertEqualObjects([self reopenedFlags], expected);
}

- (void)testClearingAndAddingALargeSetDoesNotReplaceTheFile {
    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    NSMutableArray *flags = [NSMutableArray array];
    for (int i = 0; i < 10000; i++) {
        [flags addObject:[BugsnagFeatureFlag flagWithName:[NSString stringWithFormat:@"flag-%05d", i] variant:@"variant"]];
    }
    [store addFeatureFlags:flags];
    const NSUInteger replacements = store.replaceFileCount;
    for (int i = 0; i < 5; i++) {
        [store clear];
        [store addFeatureFlags:flags];
    }
    XCTAssertEqual(store.replaceFileCount, replacements);
    XCTAssertEqual([self reopenedFlags].count, flags.count);
}

- (void)testMostlyEmptyLargeFileIsReplacedWithASmallerOne {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    NSMutableArray *flags = [NSMutableArray array];
    for (int i = 0; i < 20000; i++) {
        [flags addObject:[BugsnagFeatureFlag flagWithName:[NSString stringWithFormat:@"flag-%05d", i] variant:@"variant"]];
    }
    [store addFeatureFlags:flags];
    const unsigned long long largeSize = [[NSFileManager.defaultManager attributesOfItemAtPath:self.filePath error:nil] fileSize];
    XCTAssertGreaterThan(largeSize, 2 * 256 * 1024ULL);
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"only" variant:@"1"]]];
    XCTAssertEqual([[NSFileManager.defaultManager attributesOfItemAtPath:self.filePath error:nil] fileSize], largeSize,
                   @"A file is only shrunk when the log it replaces also takes up very little of it");
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"only" variant:@"1"]]];
    unsigned long long size = [[NSFileManager.defaultManager attributesOfItemAtPath:self.filePath error:nil] fileSize];
    // Shrinks to a quarter at a time, so clearing and refilling doesn't keep replacing it
    XCTAssertLessThanOrEqual(size, largeSize / 4 + (unsigned long long)getpagesize());
    XCTAssertGreaterThan(size, (unsigned long long)getpagesize());
    for (int i = 0; i < 10; i++) {
        [store clear];
        [store addFeatureFlag:@"only" withVariant:@"1"];
    }
    size = [[NSFileManager.defaultManager attributesOfItemAtPath:self.filePath error:nil] fileSize];
    XCTAssertLessThan(size, 2 * 256 * 1024ULL + (unsigned long long)getpagesize());
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"only", @"1"]]));
}

#pragma mark Replace all

- (void)testReplaceAllFlagsPublishesASingleSnapshot {
    [[self newStore] addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:@"old1" variant:@"1"],
                                        [BugsnagFeatureFlag flagWithName:@"old2" variant:@"2"]]];

    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), (@[@[@"old1", @"1"], @[@"old2", @"2"]]));
    store.snapshotCount = 0;
    store.appendCount = 0;

    const uint64_t before = [self activeValue];
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"new1" variant:@"a"],
                             [BugsnagFeatureFlag flagWithName:@"old2" variant:@"b"],
                             [BugsnagFeatureFlag flagWithName:@"new2"]]];
    const uint64_t after = [self activeValue];

    XCTAssertEqual(store.snapshotCount, 1);
    XCTAssertEqual(store.appendCount, 0);
    XCTAssertEqual(store.clearCount, 0);
    XCTAssertNotEqual(after & 1, before & 1);

    NSArray *expected = @[@[@"new1", @"a"], @[@"old2", @"b"], @[@"new2", NSNull.null]];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), expected);
    XCTAssertEqualObjects([self reopenedFlags], expected);

    [store replaceAllFlags:@[]];
    XCTAssertEqualObjects([self reopenedFlags], @[]);
}

- (void)testCompositeStoreSynchronizesWithASingleReplacement {
    [[self newStore] addFeatureFlag:@"previous" withVariant:@"run"];

    BSGCountingPersistentFeatureFlagStore *persistentStore = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    persistentStore.snapshotCount = 0;
    persistentStore.appendCount = 0;
    BSGMemoryFeatureFlagStore *memoryStore = [BSGMemoryFeatureFlagStore new];
    [memoryStore addFeatureFlag:@"config1" withVariant:@"1"];
    [memoryStore addFeatureFlag:@"config2" withVariant:nil];
    BSGCompositeFeatureFlagStore *store = [BSGCompositeFeatureFlagStore storeWithMemoryStore:memoryStore
                                                                             persistentStore:persistentStore
                                                                                 atomicStore:[BSGAtomicFeatureFlagStore store]];
    XCTAssertEqualObjects(FlagsToArray(store.persistedFlags), (@[@[@"previous", @"run"]]));

    [store synchronizeFlagsWithMemoryStore];

    XCTAssertEqual(persistentStore.clearCount, 0);
    XCTAssertEqual(persistentStore.snapshotCount, 1);
    XCTAssertEqual(persistentStore.appendCount, 0);
    NSArray *expected = @[@[@"config1", @"1"], @[@"config2", NSNull.null]];
    XCTAssertEqualObjects(FlagsToArray(store.persistedFlags), expected);
    XCTAssertEqualObjects([self reopenedFlags], expected);
    [[BSGAtomicFeatureFlagStore store] clear];
}

#pragma mark Previous launch's flags

- (void)testPreviousLaunchFlagsAreTheFlagsReadAtLaunch {
    @autoreleasepool {
        [[self newStore] addFeatureFlag:@"A" withVariant:@"1"];
    }
    BSGPersistentFeatureFlagStore *store = [self newStore];
    // A flag added after creating the client, before starting it
    [store addFeatureFlag:@"B" withVariant:@"2"];
    [store clear:@"A"];
    XCTAssertEqualObjects(FlagsToArray(store.previousLaunchFlags), (@[@[@"A", @"1"]]));
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), (@[@[@"B", @"2"]]));

    // Released once Bugsnag has started
    [store replaceAllFlags:store.allFlags];
    XCTAssertEqualObjects(store.previousLaunchFlags, @[]);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"B", @"2"]]));
}

- (void)testStoreWithoutTheLockHasNoPreviousLaunchFlags {
    BSGPersistentFeatureFlagStore *first = [self newStore];
    [first addFeatureFlag:@"A" withVariant:@"1"];
    BSGPersistentFeatureFlagStore *second = [self newStore];
    [second addFeatureFlag:@"B" withVariant:@"2"];
    XCTAssertEqualObjects(second.previousLaunchFlags, @[]);
    XCTAssertEqualObjects(FlagsToArray(first.previousLaunchFlags), @[], @"The first store found no file");
}

- (void)testCompositeStorePreviousLaunchFlagsExcludeFlagsAddedBeforeStart {
    @autoreleasepool {
        [[self newStore] addFeatureFlag:@"A" withVariant:@"1"];
    }
    BSGMemoryFeatureFlagStore *memoryStore = [BSGMemoryFeatureFlagStore new];
    BSGCompositeFeatureFlagStore *store = [BSGCompositeFeatureFlagStore storeWithMemoryStore:memoryStore
                                                                             persistentStore:[self newStore]
                                                                                 atomicStore:[BSGAtomicFeatureFlagStore store]];
    // Bugsnag.addFeatureFlag before -[BugsnagClient start]
    [store addFeatureFlag:@"B" withVariant:@"2"];
    XCTAssertEqualObjects(FlagsToArray(store.previousLaunchFlags), (@[@[@"A", @"1"]]),
                          @"The OOM or thermal kill event for the previous launch only has that launch's flags");
    XCTAssertEqualObjects(FlagsToArray(store.persistedFlags), (@[@[@"A", @"1"], @[@"B", @"2"]]));

    [store synchronizeFlagsWithMemoryStore];
    XCTAssertEqualObjects(store.previousLaunchFlags, @[]);
    [[BSGAtomicFeatureFlagStore store] clear];
}

- (void)testCompositeStoreWithAnotherPersistentStoreGivesItsCurrentFlags {
    BSGReplaceableMemoryFeatureFlagStore *persistentStore = [BSGReplaceableMemoryFeatureFlagStore new];
    [persistentStore addFeatureFlag:@"previous" withVariant:nil];
    BSGCompositeFeatureFlagStore *store = [BSGCompositeFeatureFlagStore storeWithMemoryStore:[BSGMemoryFeatureFlagStore new]
                                                                             persistentStore:persistentStore
                                                                                 atomicStore:[BSGAtomicFeatureFlagStore store]];
    XCTAssertEqualObjects(FlagsToArray(store.previousLaunchFlags), (@[@[@"previous", NSNull.null]]));
}

- (void)testCompositeStoreSynchronizesOtherPersistentStores {
    BSGReplaceableMemoryFeatureFlagStore *persistentStore = [BSGReplaceableMemoryFeatureFlagStore new];
    [persistentStore addFeatureFlag:@"previous" withVariant:nil];
    BSGMemoryFeatureFlagStore *memoryStore = [BSGMemoryFeatureFlagStore new];
    [memoryStore addFeatureFlag:@"config" withVariant:@"1"];
    BSGCompositeFeatureFlagStore *store = [BSGCompositeFeatureFlagStore storeWithMemoryStore:memoryStore
                                                                             persistentStore:persistentStore
                                                                                 atomicStore:[BSGAtomicFeatureFlagStore store]];
    [store synchronizeFlagsWithMemoryStore];
    XCTAssertEqualObjects(FlagsToArray(store.persistedFlags), (@[@[@"config", @"1"]]));
    [[BSGAtomicFeatureFlagStore store] clear];
}

- (void)testCompositeStoreChangesReachThePersistentStore {
    BSGMemoryFeatureFlagStore *memoryStore = [BSGMemoryFeatureFlagStore new];
    BSGCompositeFeatureFlagStore *store = [BSGCompositeFeatureFlagStore storeWithMemoryStore:memoryStore
                                                                             persistentStore:[self newStore]
                                                                                 atomicStore:[BSGAtomicFeatureFlagStore store]];
    XCTAssertTrue(store.isEmpty);

    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertFalse(store.isEmpty);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"]]));

    [store addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:@"b" variant:@"2"],
                             [BugsnagFeatureFlag flagWithName:@"c"]]];
    NSArray *expected = @[@[@"a", @"1"], @[@"b", @"2"], @[@"c", NSNull.null]];
    XCTAssertEqualObjects(FlagsToArray(store.persistedFlags), expected);
    XCTAssertEqualObjects([self reopenedFlags], expected);

    [store clear:@"b"];
    expected = @[@[@"a", @"1"], @[@"c", NSNull.null]];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), expected);
    XCTAssertEqualObjects([self reopenedFlags], expected);

    // At start, the memory store's flags replace the persisted ones
    [memoryStore clear];
    [memoryStore addFeatureFlag:@"d" withVariant:@"4"];
    [store synchronizeFlagsWithMemoryStore];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), (@[@[@"d", @"4"]]));
    XCTAssertEqualObjects(FlagsToArray(store.persistedFlags), (@[@[@"d", @"4"]]));
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"d", @"4"]]));

    [store clear];
    XCTAssertTrue(store.isEmpty);
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    [[BSGAtomicFeatureFlagStore store] clear];
}

- (void)testCompositeStoreSynchronizesThePersistentStoreUsingReplaceAllFlags {
    BSGRecordingFeatureFlagStore *persistentStore = [BSGRecordingFeatureFlagStore new];
    BSGRecordingFeatureFlagStore *atomicStore = [BSGRecordingFeatureFlagStore new];
    BSGMemoryFeatureFlagStore *memoryStore = [BSGMemoryFeatureFlagStore new];
    [memoryStore addFeatureFlag:@"a" withVariant:@"1"];
    [memoryStore addFeatureFlag:@"b" withVariant:nil];
    BSGCompositeFeatureFlagStore *store = [BSGCompositeFeatureFlagStore storeWithMemoryStore:memoryStore
                                                                             persistentStore:persistentStore
                                                                                 atomicStore:atomicStore];
    [store synchronizeFlagsWithMemoryStore];
    XCTAssertEqualObjects(persistentStore.calls, (@[@[@"replaceAllFlags:", @[@"a", @"b"]]]));
    // The crash-time store is also replaced in one update
    XCTAssertEqualObjects(atomicStore.calls, (@[@[@"replaceAllFlags:", @[@"a", @"b"]]]));
    XCTAssertEqualObjects(FlagsToArray(memoryStore.allFlags), (@[@[@"a", @"1"], @[@"b", NSNull.null]]));
}

#pragma mark Same order as the memory store

/// Applies each operation to a memory and a persistent store, checking both hold the same flags in order, also after a
/// reload.
- (void)assertOperationsMatchTheMemoryStore:(NSArray<void (^)(id<BSGReplaceableFeatureFlagStore> store)> *)operations {
    BSGReplaceableMemoryFeatureFlagStore *memoryStore = [BSGReplaceableMemoryFeatureFlagStore new];
    BSGPersistentFeatureFlagStore *store = [self newStore];
    NSUInteger index = 0;
    for (void (^ operation)(id<BSGReplaceableFeatureFlagStore>) in operations) {
        operation(memoryStore);
        operation(store);
        NSArray *expected = FlagsToArray(memoryStore.allFlags);
        XCTAssertEqualObjects(FlagsToArray(store.allFlags), expected, @"After operation %lu", (unsigned long)index);
        XCTAssertEqualObjects([self reopenedFlags], expected, @"After operation %lu, reloaded", (unsigned long)index);
        index++;
    }
    // Reloading by the store that writes the file
    NSArray *expected = FlagsToArray(memoryStore.allFlags);
    store = nil;
    XCTAssertEqualObjects(FlagsToArray([self newStore].allFlags), expected);
}

- (void)testOrderMatchesTheMemoryStore {
    [self assertOperationsMatchTheMemoryStore:@[
        ^(id<BSGReplaceableFeatureFlagStore> s) { [s addFeatureFlag:@"A" withVariant:@"1"]; },
        ^(id<BSGReplaceableFeatureFlagStore> s) { [s addFeatureFlag:@"B" withVariant:nil]; },
        // A:1, B, A:2 -> A:2, B
        ^(id<BSGReplaceableFeatureFlagStore> s) { [s addFeatureFlag:@"A" withVariant:@"2"]; },
        ^(id<BSGReplaceableFeatureFlagStore> s) { [s addFeatureFlag:@"C" withVariant:@"3"]; },
        // A cleared flag added again goes to the end
        ^(id<BSGReplaceableFeatureFlagStore> s) { [s clear:@"A"]; },
        ^(id<BSGReplaceableFeatureFlagStore> s) { [s addFeatureFlag:@"A" withVariant:@"4"]; },
        ^(id<BSGReplaceableFeatureFlagStore> s) { [s addFeatureFlag:@"B" withVariant:@"5"]; },
        // Duplicates in a batch
        ^(id<BSGReplaceableFeatureFlagStore> s) { [s addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:@"D" variant:@"1"],
                                                            [BugsnagFeatureFlag flagWithName:@"C" variant:nil],
                                                            [BugsnagFeatureFlag flagWithName:@"D" variant:@"2"],
                                                            [BugsnagFeatureFlag flagWithName:@"E"]]]; },
        ^(id<BSGReplaceableFeatureFlagStore> s) { [s replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"X" variant:@"1"],
                                                            [BugsnagFeatureFlag flagWithName:@"Y"],
                                                            [BugsnagFeatureFlag flagWithName:@"X" variant:@"2"]]]; },
        ^(id<BSGReplaceableFeatureFlagStore> s) { [s addFeatureFlag:@"Z" withVariant:nil]; },
        ^(id<BSGReplaceableFeatureFlagStore> s) { [s addFeatureFlag:@"X" withVariant:@"3"]; },
        ^(id<BSGReplaceableFeatureFlagStore> s) { [s clear]; },
        ^(id<BSGReplaceableFeatureFlagStore> s) { [s addFeatureFlag:@"Y" withVariant:@"1"]; },
        ^(id<BSGReplaceableFeatureFlagStore> s) { [s addFeatureFlag:@"X" withVariant:@"1"]; },
        ^(id<BSGReplaceableFeatureFlagStore> s) { [s addFeatureFlag:@"Y" withVariant:@"2"]; },
    ]];
}

- (void)testRandomOperationsMatchTheMemoryStore {
    // Enough changes to a few flags to compact the log several times
    srand48(1974);
    NSMutableArray *operations = [NSMutableArray array];
    for (int i = 0; i < 300; i++) {
        NSString *name = [NSString stringWithFormat:@"flag-%ld", lrand48() % 12];
        NSString *variant = lrand48() % 4 ? [NSString stringWithFormat:@"%ld", lrand48() % 3] : nil;
        const long kind = lrand48() % 20;
        if (kind < 12) {
            [operations addObject:^(id<BSGReplaceableFeatureFlagStore> s) { [s addFeatureFlag:name withVariant:variant]; }];
        } else if (kind < 17) {
            [operations addObject:^(id<BSGReplaceableFeatureFlagStore> s) { [s clear:name]; }];
        } else if (kind < 19) {
            [operations addObject:^(id<BSGReplaceableFeatureFlagStore> s) {
                [s addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:name variant:variant],
                                     [BugsnagFeatureFlag flagWithName:@"flag-0" variant:variant]]];
            }];
        } else {
            [operations addObject:^(id<BSGReplaceableFeatureFlagStore> s) { [s clear]; }];
        }
    }
    [self assertOperationsMatchTheMemoryStore:operations];
}

#pragma mark Size limit

- (void)testFlagsLargerThanTheLimitAreKeptInMemoryButNotPersisted {
    // Limit: just under 2 MB of flags, slots up to 4 MB (8 MB file)
    NSString *large = [@"" stringByPaddingToLength:1200 * 1024 withString:@"x" startingAtIndex:0];
    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    [store addFeatureFlag:@"small" withVariant:@"1"];
    [store addFeatureFlag:@"large-1" withVariant:large];
    NSArray *persisted = @[@[@"small", @"1"], @[@"large-1", large]];
    XCTAssertEqualObjects([self reopenedFlags], persisted);
    XCTAssertLessThanOrEqual([[NSFileManager.defaultManager attributesOfItemAtPath:self.filePath error:nil] fileSize], 8 * 1024 * 1024ULL);

    // Over the limit the persisted log is emptied; flags stay in memory
    [store addFeatureFlag:@"large-2" withVariant:large];
    XCTAssertEqual(store.allFlags.count, 3);
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    XCTAssertLessThanOrEqual([[NSFileManager.defaultManager attributesOfItemAtPath:self.filePath error:nil] fileSize], 8 * 1024 * 1024ULL);
    const NSUInteger replacements = store.replaceFileCount;
    [store addFeatureFlag:@"another" withVariant:nil];
    [store addFeatureFlag:@"small" withVariant:@"2"];
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    XCTAssertEqual(store.replaceFileCount, replacements, @"Flags over the limit are not written");

    // Back under the limit they are persisted at once, without waiting for a retry
    [store clear:@"large-1"];
    NSArray *expected = @[@[@"small", @"2"], @[@"large-2", large], @[@"another", NSNull.null]];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), expected);
    XCTAssertEqualObjects([self reopenedFlags], expected);
    [store addFeatureFlag:@"after" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], ([expected arrayByAddingObject:@[@"after", NSNull.null]]));
}

- (void)testReplaceAllFlagsOverTheLimit {
    NSString *large = [@"" stringByPaddingToLength:1200 * 1024 withString:@"x" startingAtIndex:0];
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store addFeatureFlag:@"previous" withVariant:nil];
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"a" variant:large],
                             [BugsnagFeatureFlag flagWithName:@"b" variant:large]]];
    XCTAssertEqual(store.allFlags.count, 2);
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"a" variant:large]]];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", large]]));
}

#pragma mark Retrying

#if defined(DEBUG) && DEBUG
- (void)testFailedWriteIsRetriedAfterTheRetryInterval {
    // As at Bugsnag start: flags set only then must be saved by the retry, since nothing changes them later
    BSGFailingPersistentFeatureFlagStore *store = [[BSGFailingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];
    // Long enough to cover the changes below on a slow machine
    store.retryInterval = 3600;
    store.failReplaceFile = YES;
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"a" variant:@"1"], [BugsnagFeatureFlag flagWithName:@"b"]]];
    XCTAssertEqual(scheduler.delays.count, 1);
    XCTAssertEqualWithAccuracy(scheduler.delays.firstObject.doubleValue, 3600, 60);
    // Changes within the retry interval neither write nor schedule retries
    [store addFeatureFlag:@"c" withVariant:nil];
    [store addFeatureFlag:@"d" withVariant:nil];
    XCTAssertEqual(store.replaceFileCount, 1);
    XCTAssertEqual(scheduler.delays.count, 1, @"Only one retry should have been scheduled");
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    store.failReplaceFile = NO;

    // The retry saves the flags, including later changes
    XCTAssertEqual([scheduler runPendingRetries], 1);
    NSArray *expected = @[@[@"a", @"1"], @[@"b", NSNull.null], @[@"c", NSNull.null], @[@"d", NSNull.null]];
    XCTAssertEqual(store.replaceFileCount, 2);
    XCTAssertEqualObjects([self reopenedFlags], expected);
    XCTAssertEqual(scheduler.pendingRetries.count, 0, @"Nothing more should be scheduled after a success");
}
#endif

- (void)testFailedWriteIsRetriedByTheTimer {
    // Same with the real timer (dispatch_after), with a generous wait
    BSGFailingPersistentFeatureFlagStore *store = [[BSGFailingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    store.retryInterval = 0.2;
    store.failReplaceFile = YES;
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"a" variant:@"1"]]];
    @synchronized (store) {
        store.failReplaceFile = NO;
    }
    XCTAssertTrue(BSGWaitUntilStoreHasSaved(store, 30));
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"]]));
}

#if defined(DEBUG) && DEBUG
- (void)testFailedRetryIsRetriedAgain {
    BSGFailingPersistentFeatureFlagStore *store = [[BSGFailingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];
    store.failReplaceFile = YES;
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqual(store.replaceFileCount, 1);
    // Each retry that fails schedules another
    XCTAssertEqual([scheduler runPendingRetries], 1);
    XCTAssertEqual(store.replaceFileCount, 2);
    XCTAssertEqual([scheduler runPendingRetries], 1);
    XCTAssertEqual(store.replaceFileCount, 3);
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    store.failReplaceFile = NO;
    XCTAssertEqual([scheduler runPendingRetries], 1);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"]]));
    XCTAssertEqual(scheduler.pendingRetries.count, 0);
}

- (void)testScheduledRetryDoesNotKeepTheStoreAlive {
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    __weak BSGFailingPersistentFeatureFlagStore *weakStore = nil;
    @autoreleasepool {
        BSGFailingPersistentFeatureFlagStore *store = [[BSGFailingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
        [scheduler attachToStore:store];
        store.failReplaceFile = YES;
        [store addFeatureFlag:@"a" withVariant:@"1"];
        weakStore = store;
    }
    XCTAssertEqual(scheduler.pendingRetries.count, 1);
    XCTAssertNil(weakStore);
    // The retry does nothing once the store has gone
    XCTAssertEqual([scheduler runPendingRetries], 1);
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:self.filePath]);
}
#endif

- (void)testReplaceAllFlagsIsNotDelayedByAnEarlierFailure {
    BSGFailingPersistentFeatureFlagStore *store = [[BSGFailingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    store.failReplaceFile = YES;
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqual(store.replaceFileCount, 1);
    store.failReplaceFile = NO;
    // Within the retry interval a change does not write the file...
    [store addFeatureFlag:@"b" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    // ...but replaceAllFlags (at Bugsnag start) does
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"start" variant:@"1"]]];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"start", @"1"]]));
}

- (void)testFailureBeforeBugsnagStartsIsRetriedWhenItStarts {
    XCTSkipIf(geteuid() == 0, @"File permissions are not enforced for root");
    [self writeLegacyFlag:@"legacy" variant:@"1" index:0];
    // Create the lock file before making the directory read-only
    int fd = open([self.directory stringByAppendingPathComponent:@"featureflag.lock"].fileSystemRepresentation, O_RDONLY | O_CREAT, 0600);
    XCTAssertNotEqual(fd, -1);
    close(fd);
    XCTAssertEqual(chmod(self.directory.fileSystemRepresentation, 0500), 0);
    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), (@[@[@"legacy", @"1"]]));
    // The imported flags are not written when the store is created
    XCTAssertEqual(store.replaceFileCount, 0);
    // A write to the read-only directory fails and is retried after the interval...
    [store addFeatureFlag:@"before-start" withVariant:nil];
    XCTAssertEqual(store.replaceFileCount, 1);
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:self.filePath]);
    XCTAssertEqual(chmod(self.directory.fileSystemRepresentation, 0700), 0);

    // ...or when Bugsnag starts
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"start" variant:nil]]];
    XCTAssertEqual(store.replaceFileCount, 2);
    // The next write deletes the leftover JSON files so the next launch won't find both kinds; the imported flag stays
    // first.
    XCTAssertEqual([self jsonFiles].count, 0);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"legacy", @"1"], @[@"start", NSNull.null]]));
}

#pragma mark Legacy files

- (void)testLegacyFilesAreImportedAndDeleted {
    [self writeLegacyFlag:@"third" variant:nil index:7];
    [self writeLegacyFlag:@"first" variant:@"1" index:0];
    [self writeLegacyFlag:@"second flag/ü" variant:@"" index:3];
    XCTAssertEqual([self jsonFiles].count, 3);

    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    NSArray *expected = @[@[@"first", @"1"], @[@"second flag/ü", @""], @[@"third", NSNull.null]];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), expected);
    // The JSON files stay until the flags are written
    XCTAssertEqual(store.replaceFileCount, 0);
    XCTAssertEqual([self jsonFiles].count, 3);
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:self.filePath]);
    // At start the flags are written once, then the JSON files deleted
    [store replaceAllFlags:store.allFlags];
    XCTAssertEqual(store.replaceFileCount, 1);
    XCTAssertEqualObjects([self jsonFiles], @[]);
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:self.filePath]);
    XCTAssertEqualObjects([self reopenedFlags], expected);
}

- (void)testLegacyFlagsAreKeptAheadOfTheAppsFlagsWhenBugsnagStarts {
    [self writeLegacyFlag:@"old-a" variant:@"1" index:0];
    [self writeLegacyFlag:@"shared" variant:@"old" index:1];
    [self writeLegacyFlag:@"old-b" variant:nil index:2];

    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"app" variant:@"x"],
                             [BugsnagFeatureFlag flagWithName:@"shared" variant:@"new"]]];
    // A flag the app also sets keeps its imported position with the app's variant
    NSArray *expected = @[@[@"old-a", @"1"], @[@"shared", @"new"], @[@"old-b", NSNull.null], @[@"app", @"x"]];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), expected);
    XCTAssertEqualObjects([self jsonFiles], @[]);
    XCTAssertEqualObjects([self reopenedFlags], expected);

    // Later changes apply to them like any flag
    [store clear:@"old-a"];
    [store addFeatureFlag:@"later" withVariant:nil];
    expected = @[@[@"shared", @"new"], @[@"old-b", NSNull.null], @[@"app", @"x"], @[@"later", NSNull.null]];
    XCTAssertEqualObjects([self reopenedFlags], expected);
    store = nil;

    // The next launch replaces them
    BSGPersistentFeatureFlagStore *next = [self newStore];
    XCTAssertEqualObjects(FlagsToArray(next.previousLaunchFlags), expected);
    [next replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"app" variant:@"y"]]];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"app", @"y"]]));
}

- (void)testLegacyFlagsClearedBeforeBugsnagStartsAreNotKept {
    [self writeLegacyFlag:@"keep" variant:@"1" index:0];
    [self writeLegacyFlag:@"drop" variant:@"2" index:1];

    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store clear:@"drop"];
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"app"]]];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"keep", @"1"], @[@"app", NSNull.null]]));
    XCTAssertEqualObjects([self jsonFiles], @[]);
}

- (void)testLegacyFlagsAreNotKeptAfterClearingAllFlagsBeforeBugsnagStarts {
    [self writeLegacyFlag:@"old" variant:@"1" index:0];

    BSGPersistentFeatureFlagStore *store = [self newStore];
    // The previous launch's flags are still reported
    XCTAssertEqualObjects(FlagsToArray(store.previousLaunchFlags), (@[@[@"old", @"1"]]));
    [store clear];
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"app"]]];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"app", NSNull.null]]));
    XCTAssertEqualObjects([self jsonFiles], @[]);
}

- (void)testLegacyFlagWithAnEmptyNameIsImportedAndDeleted {
    // Saved as ".json", which has no path extension
    [self writeLegacyFlag:@"" variant:@"empty name" index:1];
    [self writeLegacyFlag:@"a" variant:nil index:0];
    XCTAssertEqual([self jsonFiles].count, 2);

    NSArray *expected = @[@[@"a", NSNull.null], @[@"", @"empty name"]];
    XCTAssertEqualObjects(FlagsToArray([self newStartedStore].allFlags), expected);
    XCTAssertEqualObjects([self jsonFiles], @[]);
    XCTAssertEqualObjects([self reopenedFlags], expected);
}

- (void)testInvalidLegacyFilesAreIgnored {
    [self writeLegacyFlag:@"valid" variant:@"v" index:1];
    [[@"not json" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:[self.directory stringByAppendingPathComponent:@"bad.json"] atomically:YES];
    [[@"[1,2]" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:[self.directory stringByAppendingPathComponent:@"array.json"] atomically:YES];
    XCTAssertEqualObjects(FlagsToArray([self newStartedStore].allFlags), (@[@[@"valid", @"v"]]));
    XCTAssertEqualObjects([self jsonFiles], @[]);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"valid", @"v"]]));
}

- (void)testLegacyFilesWithInvalidTypesAreIgnored {
    [self writeLegacyFlag:@"valid" variant:@"v" index:1];
    [self writeLegacyFlag:@"no variant" variant:nil index:2];
    [self writeLegacyJSON:@"{\"featureFlag\": 123}" toFile:@"number.json"];
    [self writeLegacyJSON:@"{\"featureFlag\": [\"a\"], \"index\": 0}" toFile:@"array.json"];
    [self writeLegacyJSON:@"{\"featureFlag\": \"dict variant\", \"variant\": {}}" toFile:@"dict.json"];
    [self writeLegacyJSON:@"{\"featureFlag\": \"number variant\", \"variant\": 1}" toFile:@"variant.json"];
    [self writeLegacyJSON:@"{\"featureFlag\": \"null variant\", \"variant\": null}" toFile:@"null.json"];
    [self writeLegacyJSON:@"{\"featureFlag\": \"string index\", \"index\": \"3\"}" toFile:@"index.json"];
    [self writeLegacyJSON:@"{\"variant\": \"no name\"}" toFile:@"noname.json"];
    XCTAssertEqual([self jsonFiles].count, 9);

    NSArray *expected = @[@[@"valid", @"v"], @[@"no variant", NSNull.null]];
    XCTAssertEqualObjects(FlagsToArray([self newStartedStore].allFlags), expected);
    XCTAssertEqualObjects([self jsonFiles], @[]);
    XCTAssertEqualObjects([self reopenedFlags], expected);
}

- (void)testFileAndLegacyFilesAreBothDiscardedWhenFoundTogether {
    [[self newStore] addFeatureFlag:@"current" withVariant:@"1"];
    // Both exist only after a failed delete; which is current is unknown
    [self writeLegacyFlag:@"stale" variant:@"old" index:0];
    [self writeLegacyFlag:@"current" variant:@"old" index:1];
    XCTAssertEqual([self jsonFiles].count, 2);

    BSGPersistentFeatureFlagStore *store = [self newStore];
    XCTAssertEqualObjects(store.allFlags, @[]);
    XCTAssertEqualObjects([self jsonFiles], @[]);
    XCTAssertEqualObjects([self reopenedFlags], @[]);

    // The file is still used for new flags
    [store addFeatureFlag:@"new" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"new", NSNull.null]]));
}

#pragma mark Corruption

- (void)testCorruptHeader {
    [[@"this is not a feature flag file, but it is longer than the header" dataUsingEncoding:NSUTF8StringEncoding]
     writeToFile:self.filePath atomically:YES];
    BSGPersistentFeatureFlagStore *store = [self newStore];
    XCTAssertEqualObjects(store.allFlags, @[]);

    [store addFeatureFlag:@"a" withVariant:@"1"];
    NSData *data = [NSData dataWithContentsOfFile:self.filePath];
    XCTAssertEqualObjects([data subdataWithRange:NSMakeRange(0, 4)], [@"BSFF" dataUsingEncoding:NSASCIIStringEncoding]);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"]]));
}

- (void)testWrongMagic {
    [[self newStore] addFeatureFlag:@"a" withVariant:@"1"];
    const uint32_t magic = 0x46465341;
    [self replaceFileBytesAtOffset:MagicOffset withBytes:&magic length:sizeof(magic)];
    XCTAssertEqual([self headerFieldAtOffset:VersionOffset], 1);

    BSGPersistentFeatureFlagStore *store = [self newStore];
    XCTAssertEqualObjects(store.allFlags, @[]);
    [self assertUnusableFileWasRemoved];
    [store addFeatureFlag:@"b" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"b", NSNull.null]]));
}

- (void)testUnknownVersion {
    [[self newStore] addFeatureFlag:@"a" withVariant:@"1"];
    const uint32_t version = 2;
    [self replaceFileBytesAtOffset:VersionOffset withBytes:&version length:sizeof(version)];
    XCTAssertEqual([self headerFieldAtOffset:MagicOffset], 0x46465342);

    BSGPersistentFeatureFlagStore *store = [self newStore];
    XCTAssertEqualObjects(store.allFlags, @[]);
    [self assertUnusableFileWasRemoved];
    [store addFeatureFlag:@"b" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"b", NSNull.null]]));
}

- (void)testSlotCapacityTooLargeToRead {
    [[self newStore] addFeatureFlag:@"a" withVariant:@"1"];
    // A capacity over the read limit (16 MB), in a sparse file big enough to hold it, so only the capacity check
    // rejects it
    const uint32_t slotCapacity = 16 * 1024 * 1024 + 1;
    [self replaceFileBytesAtOffset:SlotCapacityOffset withBytes:&slotCapacity length:sizeof(slotCapacity)];
    XCTAssertEqual(truncate(self.filePath.fileSystemRepresentation, (off_t)(HeaderSize + 2 * (uint64_t)slotCapacity)), 0);

    BSGPersistentFeatureFlagStore *store = [self newStore];
    XCTAssertEqualObjects(store.allFlags, @[]);
    [self assertUnusableFileWasRemoved];
    [store addFeatureFlag:@"b" withVariant:nil];
    XCTAssertLessThan([self headerFieldAtOffset:SlotCapacityOffset], slotCapacity);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"b", NSNull.null]]));
}

- (void)testSlotCapacityLargerThanWrittenIsRead {
    // Larger slots from a later version are read if within the read limit
    [[self newStore] addFeatureFlag:@"a" withVariant:@"1"];
    NSMutableData *data = [NSMutableData dataWithContentsOfFile:self.filePath];
    uint32_t oldCapacity = [self headerFieldAtOffset:SlotCapacityOffset];
    uint64_t active = [self activeValue];
    NSData *log = [data subdataWithRange:NSMakeRange(HeaderSize + (active & 1) * oldCapacity, (NSUInteger)(active >> 1))];
    const uint32_t slotCapacity = 8 * 1024 * 1024;
    NSMutableData *file = [NSMutableData dataWithLength:HeaderSize + 2 * (NSUInteger)slotCapacity];
    [file replaceBytesInRange:NSMakeRange(0, HeaderSize) withBytes:data.bytes];
    [file replaceBytesInRange:NSMakeRange(SlotCapacityOffset, sizeof(slotCapacity)) withBytes:&slotCapacity];
    [file replaceBytesInRange:NSMakeRange(HeaderSize + (active & 1) * slotCapacity, log.length) withBytes:log.bytes];
    XCTAssertTrue([file writeToFile:self.filePath atomically:NO]);

    BSGPersistentFeatureFlagStore *store = [self newStore];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), (@[@[@"a", @"1"]]));
    [store addFeatureFlag:@"b" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"], @[@"b", NSNull.null]]));
}

- (void)testHugeSlotCapacities {
    // On 32-bit, a size_t file size would wrap and pass the size check
    const uint32_t capacities[] = {0x80000000, 0x80000001, 0xFFFFFFF0, UINT32_MAX};
    for (size_t i = 0; i < sizeof(capacities) / sizeof(capacities[0]); i++) {
        [[self newStore] addFeatureFlag:@"a" withVariant:@"1"];
        [self replaceFileBytesAtOffset:SlotCapacityOffset withBytes:&capacities[i] length:sizeof(capacities[i])];

        BSGPersistentFeatureFlagStore *store = [self newStore];
        XCTAssertEqualObjects(store.allFlags, @[]);
        [self assertUnusableFileWasRemoved];
        [store addFeatureFlag:@"b" withVariant:nil];
        XCTAssertEqualObjects([self reopenedFlags], (@[@[@"b", NSNull.null]]));
        [store clear];
    }
}

- (void)testTruncatedFile {
    [[self newStore] addFeatureFlag:@"a" withVariant:@"1"];
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:self.filePath];
    [handle truncateFileAtOffset:HeaderSize + 4];
    [handle closeFile];

    BSGPersistentFeatureFlagStore *store = [self newStore];
    XCTAssertEqualObjects(store.allFlags, @[]);
    [store addFeatureFlag:@"b" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"b", NSNull.null]]));
}

- (void)testTruncatedLargeFile {
    BSGPersistentFeatureFlagStore *original = [self newStore];
    for (NSUInteger i = 0; i < 10000; i++) {
        [original addFeatureFlag:[NSString stringWithFormat:@"flag-%lu", (unsigned long)i] withVariant:@"variant"];
    }
    original = nil;
    const uint32_t slotCapacity = [self headerFieldAtOffset:SlotCapacityOffset];
    XCTAssertGreaterThan(slotCapacity, 4 * (uint32_t)getpagesize());
    // The slots would touch pages past the end of the file
    XCTAssertEqual(truncate(self.filePath.fileSystemRepresentation, 64), 0);

    BSGPersistentFeatureFlagStore *store = [self newStore];
    XCTAssertEqualObjects(store.allFlags, @[]);
    [self assertUnusableFileWasRemoved];
    [store addFeatureFlag:@"b" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"b", NSNull.null]]));
}

- (void)testEmptyFile {
    [[NSData data] writeToFile:self.filePath atomically:YES];
    BSGPersistentFeatureFlagStore *store = [self newStore];
    XCTAssertEqualObjects(store.allFlags, @[]);
    [store addFeatureFlag:@"b" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"b", NSNull.null]]));
}

- (void)testCorruptEntries {
    BSGPersistentFeatureFlagStore *original = [self newStore];
    [original addFeatureFlag:@"a" withVariant:@"1"];
    [original addFeatureFlag:@"b" withVariant:@"2"];
    original = nil;

    NSMutableData *data = [NSMutableData dataWithContentsOfFile:self.filePath];
    uint32_t slotCapacity = 0;
    uint64_t active = 0;
    [data getBytes:&slotCapacity range:NSMakeRange(SlotCapacityOffset, sizeof(slotCapacity))];
    [data getBytes:&active range:NSMakeRange(ActiveOffset, sizeof(active))];
    // The second entry's name runs past the snapshot's end
    const size_t secondEntry = HeaderSize + (active & 1) * slotCapacity + 8 + 1 + 1;
    const uint32_t badLength = 0x7FFFFFF0;
    [data replaceBytesInRange:NSMakeRange(secondEntry, sizeof(badLength)) withBytes:&badLength];
    [data writeToFile:self.filePath atomically:NO];

    BSGPersistentFeatureFlagStore *store = [self newStore];
    XCTAssertEqualObjects(store.allFlags, @[], @"A corrupt snapshot should be discarded entirely");

    // New flags must not be appended to the corrupt snapshot
    [store addFeatureFlag:@"c" withVariant:@"3"];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"c", @"3"]]));
}

- (void)testInvalidUTF8 {
    [[self newStore] addFeatureFlag:@"ab" withVariant:nil];
    NSMutableData *data = [NSMutableData dataWithContentsOfFile:self.filePath];
    uint32_t slotCapacity = 0;
    uint64_t active = 0;
    [data getBytes:&slotCapacity range:NSMakeRange(SlotCapacityOffset, sizeof(slotCapacity))];
    [data getBytes:&active range:NSMakeRange(ActiveOffset, sizeof(active))];
    const uint8_t invalid[] = {0xFF, 0xFE};
    [data replaceBytesInRange:NSMakeRange(HeaderSize + (active & 1) * slotCapacity + 8, 2) withBytes:invalid];
    [data writeToFile:self.filePath atomically:NO];

    BSGPersistentFeatureFlagStore *store = [self newStore];
    XCTAssertEqualObjects(store.allFlags, @[]);
    [store addFeatureFlag:@"c" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"c", NSNull.null]]));
}

- (void)testCorruptFileIsRebuiltOnOpen {
    BSGPersistentFeatureFlagStore *original = [self newStore];
    [original addFeatureFlag:@"a" withVariant:@"1"];
    [original addFeatureFlag:@"b" withVariant:@"2"];
    original = nil;
    const uint32_t badLength = 0x7FFFFFF0;
    [self replaceFileBytesAtOffset:[self activeSlotOffset] withBytes:&badLength length:sizeof(badLength)];

    // With no changes, the corrupt snapshot must be replaced on open
    BSGPersistentFeatureFlagStore *store = [self newStore];
    XCTAssertEqualObjects(store.allFlags, @[]);
    [self assertFileIsAValidEmptySnapshot];
}

- (void)testInvalidUTF8InVariant {
    [[self newStore] addFeatureFlag:@"ab" withVariant:@"cd"];
    const uint8_t invalid[] = {0xFF, 0xFE};
    [self replaceFileBytesAtOffset:[self activeSlotOffset] + 8 + 2 withBytes:invalid length:sizeof(invalid)];

    BSGPersistentFeatureFlagStore *store = [self newStore];
    XCTAssertEqualObjects(store.allFlags, @[]);
    [store addFeatureFlag:@"c" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"c", NSNull.null]]));
}

- (void)testActiveLengthExceedsSlotCapacity {
    [[self newStore] addFeatureFlag:@"a" withVariant:@"1"];
    NSMutableData *data = [NSMutableData dataWithContentsOfFile:self.filePath];
    const uint64_t active = (uint64_t)UINT32_MAX << 1;
    [data replaceBytesInRange:NSMakeRange(ActiveOffset, sizeof(active)) withBytes:&active];
    [data writeToFile:self.filePath atomically:NO];

    BSGPersistentFeatureFlagStore *store = [self newStore];
    XCTAssertEqualObjects(store.allFlags, @[]);
    [store addFeatureFlag:@"b" withVariant:@"2"];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"b", @"2"]]));
}

#pragma mark Unwritable storage

- (void)testEmptyDirectoryAtFilePathIsReplaced {
    XCTAssertTrue([NSFileManager.defaultManager createDirectoryAtPath:self.filePath withIntermediateDirectories:NO attributes:nil error:nil]);

    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqual(store.replaceFileCount, 1);
    XCTAssertFalse(store.directoryAtFilePath);
    // The empty directory was replaced by the file
    struct stat st;
    XCTAssertEqual(lstat(self.filePath.fileSystemRepresentation, &st), 0);
    XCTAssertTrue(S_ISREG(st.st_mode));
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"]]));
    [store addFeatureFlag:@"b" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"], @[@"b", NSNull.null]]));
}

- (void)testDirectoryAtFilePath {
    // A non-empty directory is never removed, so no file can replace it
    XCTAssertTrue([NSFileManager.defaultManager createDirectoryAtPath:self.filePath withIntermediateDirectories:NO attributes:nil error:nil]);
    NSString *contents = [self.filePath stringByAppendingPathComponent:@"contents"];
    XCTAssertTrue([[@"keep" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:contents atomically:NO]);

    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    for (int i = 0; i < 20; i++) {
        [store addFeatureFlag:[NSString stringWithFormat:@"flag-%d", i] withVariant:nil];
    }
    [store addFeatureFlag:@"flag-0" withVariant:@"x"];
    [store clear:@"flag-1"];
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"a" variant:@"1"],
                             [BugsnagFeatureFlag flagWithName:@"b"]]];
    [store addFeatureFlag:@"c" withVariant:@"3"];

    // Flags still work in memory
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), (@[@[@"a", @"1"], @[@"b", NSNull.null], @[@"c", @"3"]]));
    // Replacing the file is tried once only, not even again by replaceAllFlags at start
    XCTAssertEqual(store.replaceFileCount, 1);
    XCTAssertTrue(store.directoryAtFilePath);
    XCTAssertFalse([store hasPendingWork], @"Nothing is retried");

    BOOL isDirectory = NO;
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:self.filePath isDirectory:&isDirectory]);
    XCTAssertTrue(isDirectory);
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:contents], [@"keep" dataUsingEncoding:NSUTF8StringEncoding]);
    NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.directory error:nil];
    XCTAssertEqualObjects([files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"pathExtension == 'tmp'"]], @[]);
    XCTAssertEqualObjects([self reopenedFlags], @[]);
}

- (void)testUnusableFileAndLegacyFilesAreBothDiscarded {
    [[self newStore] addFeatureFlag:@"binary" withVariant:@"1"];
    uint32_t version = 99;
    [self replaceFileBytesAtOffset:VersionOffset withBytes:&version length:sizeof(version)];
    [self writeLegacyFlag:@"legacy" variant:@"1" index:0];
    BSGPersistentFeatureFlagStore *store = [self newStore];
    XCTAssertEqualObjects(store.allFlags, @[]);
    XCTAssertEqualObjects([self jsonFiles], @[]);
    [self assertUnusableFileWasRemoved];
}

- (void)testEmptyDirectoryAtFilePathWithLegacyFiles {
    [NSFileManager.defaultManager createDirectoryAtPath:self.filePath withIntermediateDirectories:NO attributes:nil error:nil];
    [self writeLegacyFlag:@"legacy" variant:@"1" index:0];
    BSGPersistentFeatureFlagStore *store = [self newStartedStore];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), (@[@[@"legacy", @"1"]]));
    // Legacy files are deleted once flags are written
    XCTAssertEqualObjects([self jsonFiles], @[]);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"legacy", @"1"]]));
}

- (void)testDirectoryAtFilePathWithLegacyFiles {
    [NSFileManager.defaultManager createDirectoryAtPath:self.filePath withIntermediateDirectories:NO attributes:nil error:nil];
    XCTAssertTrue([NSData.data writeToFile:[self.filePath stringByAppendingPathComponent:@"contents"] atomically:NO]);
    [self writeLegacyFlag:@"legacy" variant:@"1" index:0];
    BSGPersistentFeatureFlagStore *store = [self newStartedStore];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), (@[@[@"legacy", @"1"]]));
    // The first write deletes the legacy files even though saving failed, so stale flags aren't imported next launch
    XCTAssertEqualObjects([self jsonFiles], @[]);
    XCTAssertEqualObjects([self reopenedFlags], @[]);
}

- (void)testGrowthFailureWithAnExistingFile {
    BSGFailingPersistentFeatureFlagStore *store = [[BSGFailingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    store.retryInterval = 0;
    [store addFeatureFlag:@"a" withVariant:@"1"];
    [store addFeatureFlag:@"b" withVariant:@"2"];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"], @[@"b", @"2"]]));

    store.failReplaceFile = YES;
    NSString *large = [@"" stringByPaddingToLength:4 * (NSUInteger)getpagesize() withString:@"x" startingAtIndex:0];
    [store addFeatureFlag:@"large" withVariant:large];
    // The log stays empty until the larger file exists, so changed or cleared flags are never reported
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    [store addFeatureFlag:@"c" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    [store clear:@"a"];
    XCTAssertEqualObjects([self reopenedFlags], @[], @"Nothing is appended to the emptied log");

    NSArray *expected = @[@[@"b", @"2"], @[@"large", large], @[@"c", NSNull.null]];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), expected);

    store.failReplaceFile = NO;
    [store addFeatureFlag:@"d" withVariant:nil];
    expected = @[@[@"b", @"2"], @[@"large", large], @[@"c", NSNull.null], @[@"d", NSNull.null]];
    XCTAssertEqualObjects([self reopenedFlags], expected);
}

- (void)testUnwritableDirectoryAfterTheFileIsCreated {
    XCTSkipIf(geteuid() == 0, @"File permissions are not enforced for root");
    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqual(chmod(self.directory.fileSystemRepresentation, 0500), 0);

    NSString *large = [@"" stringByPaddingToLength:4 * (NSUInteger)getpagesize() withString:@"x" startingAtIndex:0];
    [store addFeatureFlag:@"large" withVariant:large];
    [store addFeatureFlag:@"b" withVariant:nil];
    [store clear:@"a"];
    XCTAssertEqual(store.replaceFileCount, 2, @"Growing the file should not be retried");
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), (@[@[@"large", large], @[@"b", NSNull.null]]));
    XCTAssertEqualObjects([self reopenedFlags], @[], @"The log is emptied until the larger file can be created");
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:[self.filePath stringByAppendingString:@".tmp"]]);

    XCTAssertEqual(chmod(self.directory.fileSystemRepresentation, 0700), 0);
}

- (void)testWritingIsRetriedAfterTheRetryInterval {
    XCTSkipIf(geteuid() == 0, @"File permissions are not enforced for root");
    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqual(chmod(self.directory.fileSystemRepresentation, 0500), 0);
    NSString *large = [@"" stringByPaddingToLength:4 * (NSUInteger)getpagesize() withString:@"x" startingAtIndex:0];
    [store addFeatureFlag:@"large" withVariant:large];
    XCTAssertEqualObjects([self reopenedFlags], @[], @"The log is emptied until the larger file can be created");
    XCTAssertEqual(chmod(self.directory.fileSystemRepresentation, 0700), 0);

    // Within the retry interval the file is not written
    [store addFeatureFlag:@"b" withVariant:nil];
    XCTAssertEqual(store.replaceFileCount, 2);
    XCTAssertEqualObjects([self reopenedFlags], @[]);

    // After it, the next change writes all the flags
    store.retryTime = 0;
    [store clear:@"a"];
    [store addFeatureFlag:@"c" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"large", large], @[@"b", NSNull.null], @[@"c", NSNull.null]]));
}

#if defined(DEBUG) && DEBUG
- (void)testFileThatCannotBeOpenedIsKeptAndRetried {
    XCTSkipIf(geteuid() == 0, @"File permissions are not enforced for root");
    [[self newStore] addFeatureFlag:@"previous-launch" withVariant:@"1"];
    NSData *contents = [NSData dataWithContentsOfFile:self.filePath];
    // The file cannot be opened (EACCES), as while protected data is unavailable
    XCTAssertEqual(chmod(self.filePath.fileSystemRepresentation, 0), 0);

    BSGPersistentFeatureFlagStore *store = [self newStore];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];
    XCTAssertNotEqual(store.lockFd, -1, @"The store should hold the lock");
    XCTAssertEqualObjects(store.allFlags, @[], @"The flags are not available for this launch");
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:self.filePath], @"The file may hold good flags");

    // Start with no flags: the file still can't be opened, so it is kept and a retry scheduled
    [store replaceAllFlags:@[]];
    XCTAssertEqual(scheduler.pendingRetries.count, 1);
    XCTAssertEqual(chmod(self.filePath.fileSystemRepresentation, 0600), 0);
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:self.filePath], contents, @"The file must not be changed");

    // Once openable, the retry empties it in place so a later launch doesn't report its flags
    XCTAssertEqual([scheduler runPendingRetries], 1);
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:self.filePath]);
    XCTAssertEqual(scheduler.pendingRetries.count, 0);
    store = nil;
    XCTAssertEqualObjects([self reopenedFlags], @[]);
}
#endif

- (void)testFileThatCannotBeOpenedIsReplacedByTheNextFlagsSaved {
    XCTSkipIf(geteuid() == 0, @"File permissions are not enforced for root");
    [[self newStore] addFeatureFlag:@"previous-launch" withVariant:@"1"];
    XCTAssertEqual(chmod(self.filePath.fileSystemRepresentation, 0), 0);

    BSGPersistentFeatureFlagStore *store = [self newStore];
    XCTAssertEqualObjects(store.allFlags, @[]);
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:self.filePath]);
    // A new file holds this launch's flags
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"a" variant:@"1"]]];
    store = nil;
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"]]));
}

/// Runs the block with the descriptor table full (open fails with EMFILE), leaving one free if `leaveOneFree`. Returns
/// NO if that can't be arranged.
static BOOL BSGWithDescriptorsExhausted(BOOL leaveOneFree, void (^ block)(void)) {
    struct rlimit original;
    if (getrlimit(RLIMIT_NOFILE, &original) != 0) {
        return NO;
    }
    int highest = 0;
    for (int fd = 0; fd < 4096; fd++) {
        if (fcntl(fd, F_GETFD) != -1) {
            highest = fd;
        }
    }
    const struct rlimit limited = {(rlim_t)highest + 64, original.rlim_max};
    if (setrlimit(RLIMIT_NOFILE, &limited) != 0) {
        return NO;
    }
    NSMutableArray<NSNumber *> *filler = [NSMutableArray array];
    int fd;
    while ((fd = dup(STDIN_FILENO)) != -1) {
        [filler addObject:@(fd)];
    }
    const BOOL exhausted = errno == EMFILE && filler.count > 0;
    if (exhausted && leaveOneFree) {
        close(filler.lastObject.intValue);
        [filler removeLastObject];
    }
    @try {
        if (exhausted) {
            block();
        }
    } @finally {
        for (NSNumber *descriptor in filler) {
            close(descriptor.intValue);
        }
        setrlimit(RLIMIT_NOFILE, &original);
    }
    return exhausted;
}

- (void)testFileIsKeptWhenTooManyFilesAreOpen {
    // The descriptor table is process-wide and other threads can take or free descriptors, so this retries until the
    // case under test is reached.
    __block BSGPersistentFeatureFlagStore *store = nil;
    NSData *contents = nil;
    BOOL reached = NO;
    for (int attempt = 0; attempt < 20 && !reached; attempt++) {
        store = nil;
        [NSFileManager.defaultManager removeItemAtPath:self.directory error:nil];
        [NSFileManager.defaultManager createDirectoryAtPath:self.directory withIntermediateDirectories:YES attributes:nil error:nil];
        [[self newStore] addFeatureFlag:@"previous-launch" withVariant:@"1"];
        contents = [NSData dataWithContentsOfFile:self.filePath];
        // Only featureflag.lock gets a descriptor; featureflag.bin fails with EMFILE
        const BOOL arranged = BSGWithDescriptorsExhausted(YES, ^{
            store = [self newStore];
        });
        if (!arranged) {
            XCTSkip(@"The descriptor table could not be filled");
        }
        reached = store.lockFd != -1 && store.fd == -1;
    }
    if (!reached) {
        XCTSkip(@"Other threads kept opening or closing descriptors, so featureflag.bin never failed with EMFILE");
    }
    XCTAssertEqualObjects(store.allFlags, @[]);
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:self.filePath], contents, @"The file must be kept as it was");
    // With descriptors free again, flags are saved as usual
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"start"]]];
    store = nil;
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"start", NSNull.null]]));
}

- (void)testTooLargeToPersist {
    BSGFailingPersistentFeatureFlagStore *store = [[BSGFailingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqual(store.replaceFileCount, 1);

    // Reserved but never touched, so it uses no memory
    const size_t length = UINT32_MAX / 8 + 1;
    void *bytes = mmap(NULL, length, PROT_READ, MAP_PRIVATE | MAP_ANON, -1, 0);
    XCTAssertNotEqual(bytes, MAP_FAILED);
    store.replacementSnapshot = [NSData dataWithBytesNoCopy:bytes length:length freeWhenDone:NO];

    NSString *large = [@"" stringByPaddingToLength:4 * (NSUInteger)getpagesize() withString:@"x" startingAtIndex:0];
    [store addFeatureFlag:@"large" withVariant:large];
    XCTAssertEqual(store.replaceFileCount, 2);
    XCTAssertEqualObjects([self reopenedFlags], @[], @"The log is emptied until the larger file can be created");

    // Within the retry interval later changes don't replace the file, even if they'd fit
    store.replacementSnapshot = nil;
    munmap(bytes, length);
    [store addFeatureFlag:@"b" withVariant:nil];
    [store addFeatureFlag:@"large" withVariant:[large stringByAppendingString:@"y"]];
    XCTAssertEqual(store.replaceFileCount, 2);
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    XCTAssertEqual(store.allFlags.count, 3);
}

- (void)testStaleTemporaryFileIsRemovedOnOpen {
    [[self newStore] addFeatureFlag:@"a" withVariant:@"1"];
    NSString *tempPath = [self.filePath stringByAppendingString:@".tmp"];
    XCTAssertTrue([[@"partial" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:tempPath atomically:NO]);

    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"]]));
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:tempPath]);
}

#pragma mark Concurrency

- (void)testConcurrentWriters {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    dispatch_apply(4, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t thread) {
        for (int i = 0; i < 500; i++) {
            NSString *name = [NSString stringWithFormat:@"flag-%d", i % 150];
            NSString *variant = [NSString stringWithFormat:@"thread-%zu-%d", thread, i];
            switch ((i + (int)thread) % 7) {
                case 0:
                    [store clear:name];
                    break;
                case 1:
                    [store addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:name variant:variant],
                                             [BugsnagFeatureFlag flagWithName:[name stringByAppendingString:@"-batch"]]]];
                    break;
                default:
                    [store addFeatureFlag:[NSString stringWithFormat:@"%@-%zu", name, thread] withVariant:variant];
                    break;
            }
            (void)store.allFlags;
        }
    });
    NSArray *expected = FlagsToArray(store.allFlags);
    XCTAssertGreaterThan(expected.count, 0);
    XCTAssertEqualObjects([self reopenedFlags], expected);
}

#pragma mark Several stores using one directory

/// Adds enough flags (variant = name) to force a larger file.
static void BSGGrowStore(BSGPersistentFeatureFlagStore *store, NSString *prefix, int count) {
    NSMutableArray *flags = [NSMutableArray array];
    for (int i = 0; i < count; i++) {
        NSString *name = [NSString stringWithFormat:@"%@-%05d-%@", prefix, i, [@"" stringByPaddingToLength:64 withString:@"x" startingAtIndex:0]];
        [flags addObject:[BugsnagFeatureFlag flagWithName:name variant:name]];
    }
    [store addFeatureFlags:flags];
}

- (NSDictionary<NSString *, NSData *> *)directoryContents {
    NSMutableDictionary *contents = [NSMutableDictionary dictionary];
    for (NSString *file in [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.directory error:nil]) {
        contents[file] = [NSData dataWithContentsOfFile:[self.directory stringByAppendingPathComponent:file]] ?: NSNull.null;
    }
    return contents;
}

- (void)testStoresSharingADirectoryCanGrowConcurrently {
    // Two clients (or macOS app instances) share a directory; only the lock holder writes, so the file holds only its
    // flags.
    BSGPersistentFeatureFlagStore *first = [self newStore];
    // The first store takes the lock and writes before the second is created
    [first addFeatureFlag:@"first" withVariant:nil];
    BSGPersistentFeatureFlagStore *second = [self newStore];
    dispatch_apply(2, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t index) {
        BSGPersistentFeatureFlagStore *store = index ? second : first;
        for (int round = 1; round <= 12; round++) {
            BSGGrowStore(store, [NSString stringWithFormat:@"store%zu-round%d", index, round], round * 200);
            [store clear];
        }
        BSGGrowStore(store, [NSString stringWithFormat:@"store%zu-final", index], 3000);
    });
    XCTAssertEqual(second.allFlags.count, 3000, @"The second store keeps its flags in memory");
    XCTAssertEqualObjects([self reopenedFlags], FlagsToArray(first.allFlags));
    NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.directory error:nil];
    XCTAssertEqualObjects([files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"pathExtension == 'tmp'"]], @[]);
}

- (void)testSecondStoreUsingTheDirectoryDoesNotWriteOrDelete {
    BSGPersistentFeatureFlagStore *first = [self newStore];
    [first addFeatureFlag:@"first" withVariant:@"1"];
    // Files the second store would otherwise delete or replace
    [NSData.data writeToFile:[self.directory stringByAppendingPathComponent:@"featureflag.bin.6F9619FF-8B86-D011-B42D-00CF4FC964FF.tmp"] atomically:NO];
    NSDictionary *contents = [self directoryContents];

    BSGCountingPersistentFeatureFlagStore *second = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    // Without the lock: no persisted flags, file never opened
    XCTAssertTrue(second.isEmpty);
    XCTAssertEqual(second.fd, -1);
    [second addFeatureFlag:@"second" withVariant:nil];
    [second addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:@"first" variant:@"2"]]];
    [second clear:@"first"];
    [second replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"replaced"]]];
    [second clear];
    [second addFeatureFlag:@"last" withVariant:@"x"];
    XCTAssertEqualObjects(FlagsToArray(second.allFlags), (@[@[@"last", @"x"]]));
    XCTAssertEqual(second.replaceFileCount, 0);
    XCTAssertEqualObjects([self directoryContents], contents);
    second = nil;
    XCTAssertEqualObjects([self directoryContents], contents);

    // The first store still writes
    [first addFeatureFlag:@"more" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"first", @"1"], @[@"more", NSNull.null]]));

    // Once it is gone, a new store takes the lock and writes
    first = nil;
    BSGPersistentFeatureFlagStore *third = [self newStore];
    [third addFeatureFlag:@"third" withVariant:@"3"];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"first", @"1"], @[@"more", NSNull.null], @[@"third", @"3"]]));
    NSArray *files = [[NSFileManager.defaultManager contentsOfDirectoryAtPath:self.directory error:nil] sortedArrayUsingSelector:@selector(compare:)];
    XCTAssertEqualObjects(files, (@[@"featureflag.bin", @"featureflag.lock"]));
}

- (void)testStoreWithoutTheLockReportsNoPersistedFlags {
    BSGPersistentFeatureFlagStore *first = [self newStore];
    [first addFeatureFlag:@"first" withVariant:@"1"];
    // A legacy JSON file, which a lock holder would import
    [self writeLegacyFlag:@"legacy" variant:@"2" index:0];
    NSDictionary *contents = [self directoryContents];

    BSGPersistentFeatureFlagStore *second = [self newStore];
    XCTAssertEqual(second.lockFd, -1);
    XCTAssertTrue(second.isEmpty, @"Neither featureflag.bin nor the JSON files are read without the lock");
    XCTAssertEqual(second.fd, -1);
    XCTAssertEqualObjects([self directoryContents], contents);
    [second addFeatureFlag:@"second" withVariant:nil];
    XCTAssertEqualObjects([self directoryContents], contents);
    (void)first;
}

- (void)testLeftoverTemporaryFilesAreDeleted {
    NSArray *leftovers = @[@"featureflag.bin.tmp", @"featureflag.bin.6F9619FF-8B86-D011-B42D-00CF4FC964FF.tmp"];
    for (NSString *file in [leftovers arrayByAddingObject:@"other.tmp"]) {
        [NSData.data writeToFile:[self.directory stringByAppendingPathComponent:file] atomically:NO];
    }
    [[self newStore] addFeatureFlag:@"a" withVariant:@"1"];
    NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.directory error:nil];
    XCTAssertEqualObjects([files sortedArrayUsingSelector:@selector(compare:)], (@[@"featureflag.bin", @"featureflag.lock", @"other.tmp"]));
}

- (void)testSlotCapacityChangedByAnotherProcessIsIgnored {
    // Offsets use the slot capacity read at open, not the header, which another process could change.
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    // Clearing writes to the other slot, whose address depends on the capacity
    [store clear];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqual([self activeValue] & 1, 1);
    const uint32_t slotCapacity = UINT32_MAX / 4;
    int fd = open(self.filePath.fileSystemRepresentation, O_RDWR);
    XCTAssertNotEqual(fd, -1);
    XCTAssertEqual(pwrite(fd, &slotCapacity, sizeof(slotCapacity), SlotCapacityOffset), (ssize_t)sizeof(slotCapacity));
    close(fd);
    for (int i = 0; i < 10; i++) {
        [store addFeatureFlag:[NSString stringWithFormat:@"small-%d", i] withVariant:@"1"];
    }
    BSGGrowStore(store, @"after", 1000);
    XCTAssertEqual(store.allFlags.count, 1011);
    XCTAssertEqual([self reopenedFlags].count, 1011);
}

- (void)testTemporaryFileLeftByAnotherProcessDoesNotStopTheFileBeingReplaced {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    // As if another process was killed while replacing the file
    [NSData.data writeToFile:[self.filePath stringByAppendingString:@".tmp"] atomically:NO];
    BSGGrowStore(store, @"after", 1000);
    XCTAssertEqual([self reopenedFlags].count, 1001);
}

#pragma mark Write errors

#if defined(DEBUG) && DEBUG
- (void)testAppendFailureEmptiesTheLogAndIsRetried {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqual([self activeValue], 10 << 1, @"One 10-byte record in slot 0");

    // Record "b" (10 bytes at 42) crosses the limit: part-written, then EFBIG as on a full disk. The header is below
    // it, so the log can be emptied.
    XCTAssertTrue(BSGWithFileSizeLimit(HeaderSize + 10 + 4, ^{
        [store addFeatureFlag:@"b" withVariant:@"2"];
    }));
    NSArray *expected = @[@[@"a", @"1"], @[@"b", @"2"]];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), expected, @"The flags stay in memory");
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:self.filePath]);
    XCTAssertEqualObjects([self reopenedFlags], @[], @"The file must not hold flags that have since changed");
    [self assertFileIsAValidEmptySnapshot];

    // A change within the interval is not written; the retry saves everything
    [store addFeatureFlag:@"c" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    expected = [expected arrayByAddingObject:@[@"c", NSNull.null]];
    XCTAssertEqual([scheduler runPendingRetries], 1);
    XCTAssertEqualObjects([self reopenedFlags], expected);
    [store addFeatureFlag:@"d" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], ([expected arrayByAddingObject:@[@"d", NSNull.null]]));
}

- (void)testSnapshotFailureEmptiesTheLogAndIsRetried {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    [store addFeatureFlag:@"b" withVariant:@"2"];
    XCTAssertEqual([self activeValue] & 1, 0);
    const uint32_t slotCapacity = [self headerFieldAtOffset:SlotCapacityOffset];

    // The new log goes to slot 1, past the limit
    XCTAssertTrue(BSGWithFileSizeLimit(HeaderSize + slotCapacity, ^{
        [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"c" variant:@"3"]]];
    }));
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), (@[@[@"c", @"3"]]));
    XCTAssertEqualObjects([self reopenedFlags], @[], @"The file must not hold the replaced flags");
    XCTAssertEqual([scheduler runPendingRetries], 1);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"c", @"3"]]));
}

- (void)testVersion1FileWrittenByHandIsRead {
    // A version 1 file built by hand (little-endian), not by the encoder, so a format change that breaks released files
    // fails here.
    const uint8_t header[32] = {
        'B', 'S', 'F', 'F',                         // magic
        0x01, 0x00, 0x00, 0x00,                     // version 1
        0x40, 0x00, 0x00, 0x00,                     // slot capacity: 64 bytes
        0x00, 0x00, 0x00, 0x00,                     // reserved
        0x63, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // active: length 49 << 1 | slot 1
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // reserved
    };
    const uint8_t log[49] = {
        0x01, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 'a', '1',      // add a, variant "1"
        0x01, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 'b',           // add b, no variant
        0x01, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 'a', '2', '2', // a again, variant "22"
        0x01, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 'c', 'x',      // add c, variant "x"
        0x01, 0x00, 0x00, 0x00, 0xFE, 0xFF, 0xFF, 0xFF, 'b',           // remove b
    };
    // Slot 0's valid log must be ignored: slot 1 is active
    const uint8_t inactive[10] = {0x01, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 'z', 'z'};
    NSMutableData *file = [NSMutableData dataWithLength:32 + 2 * 64];
    [file replaceBytesInRange:NSMakeRange(0, sizeof(header)) withBytes:header];
    [file replaceBytesInRange:NSMakeRange(32, sizeof(inactive)) withBytes:inactive];
    [file replaceBytesInRange:NSMakeRange(32 + 64, sizeof(log)) withBytes:log];
    XCTAssertTrue([file writeToFile:[self.directory stringByAppendingPathComponent:@"featureflag.bin"] atomically:NO]);

    // Re-added flags keep their first position and last variant; removed flags are gone
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"22"], @[@"c", @"x"]]));
}

- (void)testCompactionFailureKeepsTheCurrentLog {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    [store addFeatureFlag:@"b" withVariant:@"2"];
    XCTAssertEqual([self activeValue] & 1, 0);
    const uint32_t slotCapacity = [self headerFieldAtOffset:SlotCapacityOffset];
    // Compaction happens at 4,096 bytes over the flags; slot 0 must fit that
    if (slotCapacity < 4096 + 1024) {
        XCTSkip(@"The file's slots (%u bytes) fill up before the log would be compacted", slotCapacity);
    }

    // Changes append in slot 0 until compacted into slot 1, past the limit (a full disk)
    __block NSString *variant = nil;
    XCTAssertTrue(BSGWithFileSizeLimit(HeaderSize + slotCapacity, ^{
        for (int i = 0; i < 1000 && ([self activeValue] >> 1) <= 4096 + 256; i++) {
            variant = [NSString stringWithFormat:@"%d", i];
            [store addFeatureFlag:@"a" withVariant:variant];
        }
    }));
    XCTAssertEqual([self activeValue] & 1, 0, @"Slot 0 should still be the active one");
    XCTAssertGreaterThan([self activeValue] >> 1, 4096, @"The log should have been kept");
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", variant], @[@"b", @"2"]]),
                          @"The file should still hold the current flags");

    // Nothing to save, so no retry
    XCTAssertEqualObjects(scheduler.delays, @[]);

    // After the retry interval the next change compacts into slot 1
    store.compactionRetryTime = 0;
    [store addFeatureFlag:@"c" withVariant:@"3"];
    XCTAssertEqual([self activeValue] & 1, 1, @"The log should have been compacted into slot 1");
    XCTAssertLessThan([self activeValue] >> 1, 256u, @"The compacted log should hold only the live flags");
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", variant], @[@"b", @"2"], @[@"c", @"3"]]));

    // A later failure gets the usual first delay, not a doubled one
    XCTAssertTrue(BSGWithFileSizeLimit(ActiveOffset, ^{
        [store addFeatureFlag:@"d" withVariant:nil];
    }));
    XCTAssertEqual(scheduler.delays.count, 1u);
    XCTAssertEqualWithAccuracy(scheduler.delays.firstObject.doubleValue, store.retryInterval, 1);
}

- (void)testHeaderWriteFailureDeletesTheFile {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];
    [store addFeatureFlag:@"a" withVariant:@"1"];

    // Neither record nor header (offset 16) can be written, so this store deletes its file instead
    XCTAssertTrue(BSGWithFileSizeLimit(ActiveOffset, ^{
        [store addFeatureFlag:@"b" withVariant:@"2"];
    }));
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:self.filePath]);
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    XCTAssertEqual(store.allFlags.count, 2);

    // The retry creates a new file
    XCTAssertEqual([scheduler runPendingRetries], 1);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"], @[@"b", @"2"]]));
}
#endif

- (void)testClearFailureDeletesTheFile {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    store.retryInterval = 0;
    [store addFeatureFlag:@"a" withVariant:@"1"];

    // The empty log is only a header write, which fails
    XCTAssertTrue(BSGWithFileSizeLimit(ActiveOffset, ^{
        [store clear];
    }));
    XCTAssertTrue(store.isEmpty);
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:self.filePath],
                   @"Flags that were cleared must not be reported later");

    // The file is created again by the next change
    [store addFeatureFlag:@"b" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"b", NSNull.null]]));
}

#if defined(DEBUG) && DEBUG
- (void)testHeaderWriteFailureAfterTheRecordsWereWritten {
    BSGHeaderFailingPersistentFeatureFlagStore *store =
    [[BSGHeaderFailingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];
    [store addFeatureFlag:@"a" withVariant:@"1"];

    // Records written but not the length that commits them: the log is emptied
    store.failHeaderWrites = 1;
    [store addFeatureFlag:@"b" withVariant:@"2"];
    XCTAssertEqual(store.failHeaderWrites, 0);
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:self.filePath]);
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    XCTAssertEqual([scheduler runPendingRetries], 1);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"], @[@"b", @"2"]]));

    // If the log cannot be emptied either, the file is deleted
    store.retryInterval = 0;
    store.failHeaderWrites = 2;
    [store clear:@"a"];
    XCTAssertEqual(store.failHeaderWrites, 0);
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:self.filePath]);
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), (@[@[@"b", @"2"]]));
    [store addFeatureFlag:@"c" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"b", @"2"], @[@"c", NSNull.null]]));
}

- (void)testFileThatCannotBeExtendedIsNotCreated {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];

    // The temporary file can't reach full size (ftruncate fails with EFBIG)
    XCTAssertTrue(BSGWithFileSizeLimit(HeaderSize, ^{
        [store addFeatureFlag:@"a" withVariant:@"1"];
    }));
    NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.directory error:nil];
    XCTAssertEqualObjects(files, @[@"featureflag.lock"], @"The temporary file must be deleted");
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), (@[@[@"a", @"1"]]));

    XCTAssertEqual([scheduler runPendingRetries], 1);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"]]));
    files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.directory error:nil];
    XCTAssertEqualObjects([files sortedArrayUsingSelector:@selector(compare:)], (@[@"featureflag.bin", @"featureflag.lock"]));
}
#endif

#pragma mark Lock and open errors

- (void)testLockCannotBeCreatedInAnUnwritableDirectory {
    XCTSkipIf(geteuid() == 0, @"File permissions are not enforced for root");
    [[self newStore] addFeatureFlag:@"previous" withVariant:@"1"];
    NSString *lockPath = [self.directory stringByAppendingPathComponent:@"featureflag.lock"];
    XCTAssertEqual(unlink(lockPath.fileSystemRepresentation), 0);
    NSData *contents = [NSData dataWithContentsOfFile:self.filePath];
    XCTAssertEqual(chmod(self.directory.fileSystemRepresentation, 0500), 0);

    // Without the lock the store reads and changes nothing
    BSGPersistentFeatureFlagStore *store = [self newStore];
    XCTAssertTrue(store.isEmpty);
    [store addFeatureFlag:@"a" withVariant:nil];
    [store clear:@"previous"];
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"b"]]];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), (@[@[@"b", NSNull.null]]));
    XCTAssertEqual(chmod(self.directory.fileSystemRepresentation, 0700), 0);
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:lockPath]);
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:self.filePath], contents);
}

- (void)testStoreWithoutTheLockThatCannotOpenTheFileChangesNothing {
    XCTSkipIf(geteuid() == 0, @"File permissions are not enforced for root");
    BSGPersistentFeatureFlagStore *owner = [self newStore];
    [owner addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqual(chmod(self.filePath.fileSystemRepresentation, 0), 0);

    BSGPersistentFeatureFlagStore *other = [self newStore];
    XCTAssertTrue(other.isEmpty, @"A store without the lock reports no persisted flags");
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:self.filePath], @"A store without the lock deletes nothing");
    other = nil;

    // The lock holder still writes through its open descriptor
    [owner addFeatureFlag:@"b" withVariant:nil];
    XCTAssertEqual(chmod(self.filePath.fileSystemRepresentation, 0600), 0);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"], @[@"b", NSNull.null]]));
}

#pragma mark Size limit and decoding

- (void)testSizeLimitAtTheExactBoundary {
    // The limit is on encoded flags: 8 bytes of lengths plus name and variant per record
    const NSUInteger maxSlotCapacity = 2 * 1024 * 1024 - 16;
    // The largest slot is twice the limit, so a full log can still double
    const NSUInteger largestSlotCapacity = 4 * 1024 * 1024 - 16;
    NSString *(^variant)(NSUInteger) = ^(NSUInteger recordLength) {
        return [@"" stringByPaddingToLength:recordLength - 8 - 1 withString:@"x" startingAtIndex:0];
    };
    BSGPersistentFeatureFlagStore *store = [self newStore];
    store.retryInterval = 0;

    [store addFeatureFlag:@"a" withVariant:variant(maxSlotCapacity)];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", variant(maxSlotCapacity)]]));
    XCTAssertEqual([self headerFieldAtOffset:SlotCapacityOffset], largestSlotCapacity);
    XCTAssertEqual([[NSFileManager.defaultManager attributesOfItemAtPath:self.filePath error:nil] fileSize],
                   HeaderSize + 2 * largestSlotCapacity, @"The largest file is 8 MB");
    XCTAssertEqual(HeaderSize + 2 * largestSlotCapacity, 8 * 1024 * 1024);

    // One byte more is kept in memory but not persisted
    [store addFeatureFlag:@"a" withVariant:variant(maxSlotCapacity + 1)];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), (@[@[@"a", variant(maxSlotCapacity + 1)]]));
    XCTAssertEqualObjects([self reopenedFlags], @[]);

    // Back at the limit, they are persisted in the same file
    [store addFeatureFlag:@"a" withVariant:variant(maxSlotCapacity)];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", variant(maxSlotCapacity)]]));
    XCTAssertEqual([self activeValue] & 1, 1);

    // Two flags that just fit, then just don't
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"a" variant:variant(maxSlotCapacity / 2)],
                             [BugsnagFeatureFlag flagWithName:@"b" variant:variant(maxSlotCapacity / 2)]]];
    XCTAssertEqual([self reopenedFlags].count, 2);
    [store addFeatureFlag:@"c" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    XCTAssertEqual(store.allFlags.count, 3);
}

- (void)testRecordCutShortAtTheEndOfTheLog {
    [[self newStore] addFeatureFlag:@"a" withVariant:@"1"];
    // The log ends 3 bytes into a next record's lengths (the slot is zero-filled)
    const uint64_t active = (10 + 3) << 1;
    [self replaceFileBytesAtOffset:ActiveOffset withBytes:&active length:sizeof(active)];

    XCTAssertEqualObjects([self reopenedFlags], @[]);
    [self assertFileIsAValidEmptySnapshot];
}

#pragma mark Legacy file errors

- (void)testLegacyFilesThatCannotBeReadOrDeleted {
    XCTSkipIf(geteuid() == 0, @"File permissions are not enforced for root");
    [self writeLegacyFlag:@"valid" variant:@"v" index:1];
    // A file that cannot be read
    [self writeLegacyJSON:@"{\"featureFlag\": \"unreadable\", \"index\": 0}" toFile:@"unreadable.json"];
    NSString *unreadable = [self.directory stringByAppendingPathComponent:@"unreadable.json"];
    XCTAssertEqual(chmod(unreadable.fileSystemRepresentation, 0), 0);
    // Something that cannot be read as a file or deleted
    NSString *stuck = [self.directory stringByAppendingPathComponent:@"stuck.json"];
    XCTAssertTrue([NSFileManager.defaultManager createDirectoryAtPath:stuck withIntermediateDirectories:NO attributes:nil error:nil]);
    XCTAssertTrue([NSData.data writeToFile:[stuck stringByAppendingPathComponent:@"file"] atomically:NO]);
    XCTAssertEqual(chmod(stuck.fileSystemRepresentation, 0500), 0);

    BSGPersistentFeatureFlagStore *store = [self newStartedStore];
    XCTAssertEqual(chmod(stuck.fileSystemRepresentation, 0700), 0);
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), (@[@[@"valid", @"v"]]));
    XCTAssertEqualObjects([self jsonFiles], @[@"stuck.json"], @"The unreadable file is deleted, the directory is not");
}

- (void)testLegacyFilesWithTheSameIndexAreAllImported {
    [self writeLegacyFlag:@"same-1" variant:nil index:4];
    [self writeLegacyFlag:@"first" variant:@"1" index:0];
    [self writeLegacyFlag:@"same-2" variant:@"2" index:4];
    [self writeLegacyFlag:@"last" variant:nil index:9];

    NSArray *flags = FlagsToArray([self newStore].allFlags);
    XCTAssertEqual(flags.count, 4);
    XCTAssertEqualObjects(flags.firstObject, (@[@"first", @"1"]));
    XCTAssertEqualObjects(flags.lastObject, (@[@"last", NSNull.null]));
    // Equal indexes keep directory listing order
    NSSet *middle = [NSSet setWithArray:[flags subarrayWithRange:NSMakeRange(1, 2)]];
    XCTAssertEqualObjects(middle, ([NSSet setWithArray:@[@[@"same-1", NSNull.null], @[@"same-2", @"2"]]]));
    XCTAssertEqualObjects([self reopenedFlags], flags);
}

#pragma mark Growing the file while the device is locked

// Calls to SimulatedLockedCreateFile for the test's directory
#if defined(DEBUG) && DEBUG
static NSUInteger gLockedCreateFileCount;
static BSGFileProtectionFunctions gUnlockedFunctions;

/// Fails file creation in the test's directory with EPERM, as on a locked device with default class
/// NSFileProtectionComplete.
static BOOL SimulatedLockedCreateFile(NSString *path) {
    if (!BSGIsInTestDirectory(path)) {
        return gUnlockedFunctions.createFile(path);
    }
    gLockedCreateFileCount++;
    errno = EPERM;
    return NO;
}

/// Makes file creation fail as on a locked device until the test ends or the returned block is called.
- (dispatch_block_t)simulateLockedDevice {
    gLockedCreateFileCount = 0;
    // Set before installing the simulated function, which other threads may call at once
    gUnlockedFunctions = BSGSetFileProtectionFunctions((BSGFileProtectionFunctions){0});
    const BSGFileProtectionFunctions previous = BSGSetFileProtectionFunctions((BSGFileProtectionFunctions){
        .createFile = SimulatedLockedCreateFile,
    });
    __block BOOL restored = NO;
    dispatch_block_t unlock = ^{
        if (!restored) {
            restored = YES;
            BSGSetFileProtectionFunctions(previous);
        }
    };
    [self addTeardownBlock:unlock];
    return unlock;
}
#endif

- (NSArray<NSString *> *)temporaryFiles {
    NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.directory error:nil];
    return [files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.tmp'"]];
}

#if defined(DEBUG) && DEBUG
- (void)testGrowthWhileTheDeviceIsLockedEmptiesTheLogAndIsRetried {
    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];
    // Long enough to cover the changes below on a slow machine
    store.retryInterval = 3600;
    [store addFeatureFlag:@"a" withVariant:@"1"];
    [store addFeatureFlag:@"b" withVariant:@"2"];
    NSArray *earlier = @[@[@"a", @"1"], @[@"b", @"2"]];
    XCTAssertEqualObjects([self reopenedFlags], earlier);
    const uint32_t slotCapacity = [self headerFieldAtOffset:SlotCapacityOffset];
    struct stat before;
    XCTAssertEqual(lstat(self.filePath.fileSystemRepresentation, &before), 0);

    // Device locked: records still fit in the open, writable file...
    dispatch_block_t unlock = [self simulateLockedDevice];
    [store addFeatureFlag:@"b" withVariant:@"3"];
    earlier = @[@[@"a", @"1"], @[@"b", @"3"]];
    XCTAssertEqualObjects([self reopenedFlags], earlier);
    XCTAssertEqual(gLockedCreateFileCount, 0);

    // ...but a flag needing a larger file can't be saved: the new file can't be created
    NSString *large = [@"" stringByPaddingToLength:slotCapacity withString:@"x" startingAtIndex:0];
    [store addFeatureFlag:@"large" withVariant:large];
    XCTAssertEqual(gLockedCreateFileCount, 1);
    XCTAssertEqualObjects([self reopenedFlags], @[], @"The log is emptied until the larger file can be created");
    XCTAssertEqual(scheduler.delays.count, 1, @"A retry should have been scheduled");
    XCTAssertEqualWithAccuracy(scheduler.delays.firstObject.doubleValue, 3600, 60);
    XCTAssertEqualObjects([self temporaryFiles], @[]);
    struct stat after;
    XCTAssertEqual(lstat(self.filePath.fileSystemRepresentation, &after), 0);
    XCTAssertEqual(after.st_ino, before.st_ino, @"The file should not have been replaced");

    // Changes within the interval are not appended to the emptied log
    [store addFeatureFlag:@"c" withVariant:nil];
    [store clear:@"a"];
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    XCTAssertEqual(gLockedCreateFileCount, 1);

    // A retry while still locked leaves the log empty and schedules another
    XCTAssertEqual([scheduler runPendingRetries], 1);
    XCTAssertEqual(gLockedCreateFileCount, 2);
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    XCTAssertEqual(scheduler.pendingRetries.count, 1);

    // After unlock the retry creates the larger file
    unlock();
    XCTAssertEqual([scheduler runPendingRetries], 1);
    NSArray *expected = @[@[@"b", @"3"], @[@"large", large], @[@"c", NSNull.null]];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), expected);
    XCTAssertEqualObjects([self reopenedFlags], expected);
    XCTAssertGreaterThan([self headerFieldAtOffset:SlotCapacityOffset], slotCapacity);
    XCTAssertEqual(scheduler.pendingRetries.count, 0, @"Nothing more should be scheduled after a success");
    XCTAssertEqualObjects([self temporaryFiles], @[]);

    // And records are appended to the new file again
    [store addFeatureFlag:@"d" withVariant:@"4"];
    XCTAssertEqualObjects([self reopenedFlags], ([expected arrayByAddingObject:@[@"d", @"4"]]));
}

- (void)testFlagsThatShrinkWhileTheDeviceIsLockedAreWrittenInPlace {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];
    store.retryInterval = 3600;
    [store addFeatureFlag:@"a" withVariant:@"1"];
    const uint32_t slotCapacity = [self headerFieldAtOffset:SlotCapacityOffset];

    [self simulateLockedDevice];
    NSString *large = [@"" stringByPaddingToLength:slotCapacity withString:@"x" startingAtIndex:0];
    [store addFeatureFlag:@"large" withVariant:large];
    XCTAssertEqualObjects([self reopenedFlags], @[], @"The log is emptied until the larger file can be created");

    // Flags that fit again are written at once, without waiting for the retry or unlock
    [store clear:@"large"];
    [store addFeatureFlag:@"b" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"], @[@"b", NSNull.null]]));
    [store addFeatureFlag:@"large" withVariant:large];
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    // Clearing all of the flags leaves the log empty
    [store clear];
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    XCTAssertEqual(gLockedCreateFileCount, 1, @"The file is not replaced again within the retry interval");
}

- (void)testAnotherStoresLogIsNotKeptWhenTheFileCannotBeGrown {
    BSGPersistentFeatureFlagStore *first = [self newStore];
    [first addFeatureFlag:@"previous" withVariant:@"1"];
    const uint32_t slotCapacity = [self headerFieldAtOffset:SlotCapacityOffset];
    // The second store can't open featureflag.lock at creation, so it takes the lock later
    XCTSkipUnless(BSGMakeLockFileUnopenable(self.directory), @"File permissions are not enforced for root");
    BSGPersistentFeatureFlagStore *second = [self newStore];
    BSGRestoreLockFile(self.directory);
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:second];
    first = nil;

    // The second store takes the lock and file but can't grow it, so the log is emptied as for flags that don't fit.
    [self simulateLockedDevice];
    second.retryTime = 0;
    NSString *large = [@"" stringByPaddingToLength:slotCapacity withString:@"x" startingAtIndex:0];
    [second addFeatureFlag:@"large" withVariant:large];
    XCTAssertEqual(gLockedCreateFileCount, 1);
    XCTAssertEqualObjects(FlagsToArray(second.allFlags), (@[@[@"large", large]]));
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:self.filePath]);
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    XCTAssertEqual(scheduler.pendingRetries.count, 1);
}
#endif

#pragma mark Flags near the size limit

/// Counts whole-log rewrites (slot switches or file replacements) the changes caused, as seen in the file.
- (NSUInteger)countRewritesDuring:(void (^)(void))changes
                    maximumFileSize:(uint64_t)maximumFileSize
                            changes:(NSUInteger)count {
    NSUInteger rewrites = 0;
    struct stat st;
    XCTAssertEqual(lstat(self.filePath.fileSystemRepresentation, &st), 0);
    ino_t inode = st.st_ino;
    uint64_t slot = [self activeValue] & 1;
    for (NSUInteger i = 0; i < count; i++) {
        changes();
        XCTAssertEqual(lstat(self.filePath.fileSystemRepresentation, &st), 0);
        XCTAssertLessThanOrEqual((uint64_t)st.st_size, maximumFileSize);
        const uint64_t activeSlot = [self activeValue] & 1;
        if (st.st_ino != inode || activeSlot != slot) {
            rewrites++;
        }
        inode = st.st_ino;
        slot = activeSlot;
    }
    return rewrites;
}

- (void)testSmallChangesToFlagsAtTheLimitDoNotRewriteThem {
    // Flags at the limit (just under 2 MB): with slots no larger, every change would rewrite all of them
    const uint64_t limit = 2 * 1024 * 1024 - 16;
    const uint64_t maximumFileSize = 8 * 1024 * 1024;
    const NSUInteger smallRecordLength = 8 + 5 + 4; // "small" and a 4-character variant
    NSString *big = [@"" stringByPaddingToLength:(NSUInteger)(limit - smallRecordLength - 8 - 3) withString:@"x" startingAtIndex:0];
    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"big" variant:big],
                             [BugsnagFeatureFlag flagWithName:@"small" variant:@"0000"]]];
    XCTAssertEqual([self activeValue] >> 1, limit, @"The flags should be exactly at the limit");
    XCTAssertEqual([self headerFieldAtOffset:SlotCapacityOffset], 4 * 1024 * 1024 - 16);
    const NSUInteger snapshots = store.snapshotCount;
    const NSUInteger replacements = store.replaceFileCount;

    __block NSUInteger i = 0;
    const NSUInteger changes = 1000;
    const NSUInteger rewrites = [self countRewritesDuring:^{
        [store addFeatureFlag:@"small" withVariant:[NSString stringWithFormat:@"%04lu", (unsigned long)(++i % 10000)]];
    } maximumFileSize:maximumFileSize changes:changes];
    // 1000 records of 17 bytes fit after the flags, so nothing is rewritten
    XCTAssertEqual(rewrites, 0);
    XCTAssertEqual(store.snapshotCount, snapshots);
    XCTAssertEqual(store.replaceFileCount, replacements);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"big", big], @[@"small", [NSString stringWithFormat:@"%04lu", (unsigned long)changes]]]));
}

- (void)testLargeChangesToFlagsNearTheLimitAreRewrittenOnlyWhenTheLogDoubles {
    // 19 flags of 100 KB: just under 2 MB
    const uint64_t maximumFileSize = 8 * 1024 * 1024;
    const NSUInteger variantLength = 100 * 1024;
    NSString *(^variant)(NSUInteger) = ^(NSUInteger n) {
        return [@"" stringByPaddingToLength:variantLength withString:[NSString stringWithFormat:@"%lu", (unsigned long)(n % 10)] startingAtIndex:0];
    };
    NSMutableArray<BugsnagFeatureFlag *> *flags = [NSMutableArray array];
    for (NSUInteger i = 0; i < 19; i++) {
        [flags addObject:[BugsnagFeatureFlag flagWithName:[NSString stringWithFormat:@"large-%02lu", (unsigned long)i] variant:variant(0)]];
    }
    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    [store replaceAllFlags:flags];
    const uint64_t liveLength = [self activeValue] >> 1;
    XCTAssertGreaterThan(liveLength, 1900 * 1024);
    XCTAssertLessThanOrEqual(liveLength, 2 * 1024 * 1024 - 16);
    const NSUInteger replacements = store.replaceFileCount;

    // 40 changes of 100 KB append about twice the flags' size, so expect about two rewrites, not one per change.
    __block NSUInteger i = 0;
    const NSUInteger changes = 40;
    const NSUInteger rewrites = [self countRewritesDuring:^{
        i++;
        // Never variant(0), so that every change is written
        [store addFeatureFlag:[NSString stringWithFormat:@"large-%02lu", (unsigned long)(i % 19)] withVariant:variant(i % 9 + 1)];
    } maximumFileSize:maximumFileSize changes:changes];
    XCTAssertGreaterThan(rewrites, 0, @"The log should still be compacted");
    XCTAssertLessThanOrEqual(rewrites, 3);
    XCTAssertEqual(store.replaceFileCount, replacements, @"The file already has room for the log to double");
    XCTAssertEqualObjects([self reopenedFlags], FlagsToArray(store.allFlags));
}

@end

#pragma mark - Lock, backoff and files created

@interface BSGPersistentFeatureFlagStore (RetryState)
@property (nonatomic) NSTimeInterval maximumRetryInterval;
@property (nonatomic) NSTimeInterval retryDelay;
@end

@interface BSGPersistentFeatureFlagStoreLockAndRetryTests : BSGTestCase
@property (nonatomic) NSString *directory;
@end

// SimulatedLockFailure's error and call count
#if defined(DEBUG) && DEBUG
static int gLockErrno;
static NSUInteger gLockCallCount;

/// Stands in for flock(), failing with gLockErrno, for the test's directory.
static int SimulatedLockFailure(int fd, int operation) {
    if (!BSGDescriptorIsInTestDirectory(fd)) {
        return flock(fd, operation);
    }
    gLockCallCount++;
    errno = gLockErrno;
    return -1;
}

/// Counts calls to flock() for the test's directory.
static int CountingLock(int fd, int operation) {
    if (BSGDescriptorIsInTestDirectory(fd)) {
        gLockCallCount++;
    }
    return flock(fd, operation);
}
#endif

@implementation BSGPersistentFeatureFlagStoreLockAndRetryTests

- (void)setUp {
    [super setUp];
    self.directory = [NSTemporaryDirectory() stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"BSGPersistentFeatureFlagStoreLockAndRetryTests-%@", NSUUID.UUID.UUIDString]];
    [NSFileManager.defaultManager createDirectoryAtPath:self.directory withIntermediateDirectories:YES attributes:nil error:nil];
    gTestDirectory = self.directory;
}

- (void)tearDown {
#if defined(DEBUG) && DEBUG
    BSGSetFeatureFlagLockFunction(NULL);
#endif
    gTestDirectory = nil;
    chmod(self.directory.fileSystemRepresentation, 0700);
    [NSFileManager.defaultManager removeItemAtPath:self.directory error:nil];
    [super tearDown];
}

- (NSString *)filePath {
    return [self.directory stringByAppendingPathComponent:@"featureflag.bin"];
}

#if defined(DEBUG) && DEBUG
/// Makes flock() fail with `error` for featureflag.lock.
- (void)simulateLockFailure:(int)error {
    gLockErrno = error;
    gLockCallCount = 0;
    BSGSetFeatureFlagLockFunction(SimulatedLockFailure);
}
#endif

/// Named "new" so ARC returns it retained: a store holds the lock until deallocated.
- (BSGPersistentFeatureFlagStore *)newStore {
    return [[BSGPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
}

- (NSArray<NSString *> *)files {
    return [[NSFileManager.defaultManager contentsOfDirectoryAtPath:self.directory error:nil] sortedArrayUsingSelector:@selector(compare:)];
}

- (NSArray<NSString *> *)jsonFiles {
    return [[self files] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.json'"]];
}

/// The flags the next launch reads (see BSGReopenedFlags).
- (NSArray *)reopenedFlags {
    return BSGReopenedFlags(self.directory);
}

static NSArray * BSGFlagsArray(NSArray<BugsnagFeatureFlag *> *flags) {
    NSMutableArray *result = [NSMutableArray array];
    for (BugsnagFeatureFlag *flag in flags) {
        [result addObject:@[flag.name, flag.variant ?: NSNull.null]];
    }
    return result;
}

- (void)writeLegacyFlag:(NSString *)name variant:(NSString *)variant index:(uint64_t)index {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    json[@"featureFlag"] = name;
    json[@"index"] = @(index);
    if (variant) {
        json[@"variant"] = variant;
    }
    NSString *path = [self.directory stringByAppendingPathComponent:[name stringByAppendingString:@".json"]];
    [[NSJSONSerialization dataWithJSONObject:json options:0 error:nil] writeToFile:path atomically:YES];
}

#pragma mark Nothing is created without flags

- (void)testReplaceAllFlagsWithNoFlagsCreatesNoFiles {
    // Bugsnag starting with no configured flags
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store replaceAllFlags:@[]];
    XCTAssertEqualObjects([self files], @[], @"Neither featureflag.bin nor featureflag.lock should be created");
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    XCTAssertEqualObjects([self files], @[]);
}

- (void)testClearOnAnEmptyDirectoryCreatesNoFiles {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store clear];
    [store clear:nil];
    [store clear:@"missing"];
    XCTAssertEqualObjects([self files], @[]);

    // Unpersistable flags don't create the file either
    const unichar loneSurrogate = 0xD800;
    [store addFeatureFlag:[NSString stringWithCharacters:&loneSurrogate length:1] withVariant:nil];
    XCTAssertEqualObjects([self files], @[]);
}

- (void)testFilesAreCreatedByTheFirstFlag {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store replaceAllFlags:@[]];
    XCTAssertEqualObjects([self files], @[]);
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqualObjects([self files], (@[@"featureflag.bin", @"featureflag.lock"]));
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"]]));
}

- (void)testClearedFlagsAreNotReportedAtTheNextLaunch {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    [store addFeatureFlag:@"b" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"], @[@"b", NSNull.null]]));
    [store clear];
    store = nil;
    // The existing file is emptied in place, not left with the earlier flags
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:self.filePath]);
    XCTAssertEqualObjects([self reopenedFlags], @[]);
}

- (void)testFlagsReplacedWithNoFlagsAreNotReportedAtTheNextLaunch {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store addFeatureFlag:@"previous-launch" withVariant:@"1"];
    store = nil;

    // The next launch starts with no flags
    store = [self newStore];
    XCTAssertEqualObjects(BSGFlagsArray(store.allFlags), (@[@[@"previous-launch", @"1"]]));
    [store replaceAllFlags:@[]];
    store = nil;
    XCTAssertEqualObjects([self reopenedFlags], @[]);
}

- (void)testTheLockIsTakenByTheFirstStoreToWrite {
    BSGPersistentFeatureFlagStore *first = [self newStore];
    BSGPersistentFeatureFlagStore *second = [self newStore];
    XCTAssertEqualObjects([self files], @[]);
    [second addFeatureFlag:@"second" withVariant:nil];
    [first addFeatureFlag:@"first" withVariant:nil];
    [first replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"first-replaced"]]];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"second", NSNull.null]]), @"Only one store writes");
    XCTAssertEqualObjects(BSGFlagsArray(first.allFlags), (@[@[@"first-replaced", NSNull.null]]));
}

#pragma mark Missing directory

#if defined(DEBUG) && DEBUG
- (void)testMissingDirectoryIsCreatedWhenTheLockIsTaken {
    // The directory can be removed while the app runs, which won't clear by itself, so the store recreates it rather
    // than retrying.
    NSString *directory = [self.directory stringByAppendingPathComponent:@"removed/featureFlags"];
    BSGPersistentFeatureFlagStore *store = [[BSGPersistentFeatureFlagStore alloc] initWithStorageDirectory:directory];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:directory], @"Nothing is created without flags");

    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertNotEqual(store.lockFd, -1);
    XCTAssertFalse(store.lockGivenUp);
    XCTAssertEqual(scheduler.pendingRetries.count, 0);
    NSArray *files = [[NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:nil] sortedArrayUsingSelector:@selector(compare:)];
    XCTAssertEqualObjects(files, (@[@"featureflag.bin", @"featureflag.lock"]));
    store = nil;
    XCTAssertEqualObjects(BSGReopenedFlags(directory), (@[@[@"a", @"1"]]));
}

- (void)testDirectoryThatCannotBeCreatedIsNotRetried {
    XCTSkipIf(geteuid() == 0, @"File permissions are not enforced for root");
    NSString *parent = [self.directory stringByAppendingPathComponent:@"read-only"];
    XCTAssertTrue([NSFileManager.defaultManager createDirectoryAtPath:parent withIntermediateDirectories:NO attributes:nil error:nil]);
    XCTAssertEqual(chmod(parent.fileSystemRepresentation, 0500), 0);
    [self addTeardownBlock:^{ chmod(parent.fileSystemRepresentation, 0700); }];
    NSString *directory = [parent stringByAppendingPathComponent:@"featureFlags"];
    BSGPersistentFeatureFlagStore *store = [[BSGPersistentFeatureFlagStore alloc] initWithStorageDirectory:directory];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];

    [store addFeatureFlag:@"a" withVariant:@"1"];
    // ENOENT for an uncreatable directory won't clear, so it is not retried
    XCTAssertTrue(store.lockGivenUp);
    XCTAssertEqual(scheduler.pendingRetries.count, 0);
    store.retryTime = 0;
    [store addFeatureFlag:@"b" withVariant:nil];
    XCTAssertEqual(scheduler.pendingRetries.count, 0);
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:directory]);
    XCTAssertEqualObjects(BSGFlagsArray(store.allFlags), (@[@[@"a", @"1"], @[@"b", NSNull.null]]));
}
#endif

#pragma mark Backoff

#if defined(DEBUG) && DEBUG
- (void)testRetryDelayDoublesUpToTheMaximum {
    BSGFailingPersistentFeatureFlagStore *store = [[BSGFailingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];
    store.retryInterval = 60;
    store.maximumRetryInterval = 240;
    store.failReplaceFile = YES;
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqual(store.retryDelay, 60);
    NSArray<NSNumber *> *expectedDelays = @[@120, @240, @240, @240];
    for (NSNumber *expected in expectedDelays) {
        XCTAssertEqual([scheduler runPendingRetries], 1);
        XCTAssertEqual(store.retryDelay, expected.doubleValue, @"The delay doubles and is capped");
    }
    XCTAssertEqual(store.replaceFileCount, 1 + expectedDelays.count);
    // The retries are scheduled with those delays
    XCTAssertEqual(scheduler.delays.count, 1 + expectedDelays.count);
    XCTAssertEqualWithAccuracy(scheduler.delays.firstObject.doubleValue, 60, 30);
    XCTAssertEqualWithAccuracy(scheduler.delays.lastObject.doubleValue, 240, 30);

    store.failReplaceFile = NO;
    XCTAssertEqual([scheduler runPendingRetries], 1);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"]]));
    XCTAssertEqual(store.retryDelay, 0, @"Success resets the delay");
    XCTAssertEqual(scheduler.pendingRetries.count, 0);

    // The next failure waits for the retry interval again
    store.failReplaceFile = YES;
    NSString *large = [@"" stringByPaddingToLength:4 * (NSUInteger)getpagesize() withString:@"x" startingAtIndex:0];
    [store addFeatureFlag:@"large" withVariant:large];
    XCTAssertEqual(store.retryDelay, 60);
}

- (void)testPermanentFailureIsRetriedLessOften {
    // A file that can never be replaced (e.g. read-only volume) never clears
    BSGFailingPersistentFeatureFlagStore *store = [[BSGFailingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    store.failReplaceFile = YES;
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];
    store.retryInterval = 60;
    store.maximumRetryInterval = 3600;
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqual(store.replaceFileCount, 1);
    // Each failure doubles the delay, up to an hour, rather than retrying every minute
    NSArray<NSNumber *> *expectedDelays = @[@120, @240, @480, @960, @1920, @3600, @3600];
    for (NSNumber *expected in expectedDelays) {
        XCTAssertEqual([scheduler runPendingRetries], 1);
        XCTAssertEqual(store.retryDelay, expected.doubleValue);
        XCTAssertEqualWithAccuracy(scheduler.delays.lastObject.doubleValue, expected.doubleValue, 30);
    }
    XCTAssertEqual(store.replaceFileCount, 1 + expectedDelays.count);
    NSArray *temporaryFiles = [[self files] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"pathExtension == 'tmp'"]];
    XCTAssertEqualObjects(temporaryFiles, @[]);
}

- (void)testFailedReplacementAndFailedWriteInPlaceScheduleOneRetry {
    BSGDoublyFailingPersistentFeatureFlagStore *store = [[BSGDoublyFailingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];
    store.retryInterval = 60;
    store.maximumRetryInterval = 3600;
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqual(scheduler.delays.count, 0);

    // Flags over half a slot: replacing with a larger file fails, then writing in place fails too
    NSString *variant = [@"" stringByPaddingToLength:(NSUInteger)(store.slotCapacity * 3 / 4) withString:@"x" startingAtIndex:0];
    store.failReplaceFile = YES;
    store.failHeaderWrites = 1;
    const NSUInteger replaceCount = store.replaceFileCount;
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"large" variant:variant]]];
    XCTAssertEqual(store.replaceFileCount, replaceCount + 1, @"The file should have been replaced first");
    XCTAssertEqual(store.failHeaderWrites, 0, @"The log should then have been written in place");
    XCTAssertEqual(scheduler.delays.count, 1, @"Only one retry should be scheduled per attempt");
    XCTAssertEqualWithAccuracy(scheduler.delays.firstObject.doubleValue, 60, 1);
    XCTAssertEqual(store.retryDelay, 60, @"The first delay is the retry interval, not twice it");

    // The retry saves the flags once the file can be replaced
    store.failReplaceFile = NO;
    XCTAssertEqual([scheduler runPendingRetries], 1);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"large", variant]]));
}
#endif

#pragma mark JSON files that could not be deleted

/// Writes a JSON file that cannot be deleted until the returned block is called (or the test ends).
- (dispatch_block_t)writeUndeletableLegacyFlag:(NSString *)name variant:(NSString *)variant {
    [self writeLegacyFlag:name variant:variant index:0];
    NSString *path = [self.directory stringByAppendingPathComponent:[name stringByAppendingString:@".json"]];
    XCTAssertEqual(chflags(path.fileSystemRepresentation, UF_IMMUTABLE), 0);
    dispatch_block_t allowDeletion = ^{
        chflags(path.fileSystemRepresentation, 0);
    };
    [self addTeardownBlock:allowDeletion];
    return allowDeletion;
}

- (void)testJSONFileThatCouldNotBeDeletedIsDeletedByTheNextAppend {
    dispatch_block_t allowDeletion = [self writeUndeletableLegacyFlag:@"legacy" variant:@"1"];
    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    // The upgrade write saves imported flags but can't delete the JSON file
    [store replaceAllFlags:store.allFlags];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"legacy", @"1"]]));
    XCTAssertEqualObjects([self jsonFiles], @[@"legacy.json"]);
    XCTAssertTrue(store.fileIsCurrent);
    XCTAssertTrue([store hasPendingWork], @"A JSON file left over is pending work even though the file is current");

    allowDeletion();
    const NSUInteger snapshots = store.snapshotCount;
    [store addFeatureFlag:@"b" withVariant:@"2"];
    XCTAssertEqual(store.snapshotCount, snapshots, @"The change should have been appended, not written as a new log");
    XCTAssertEqualObjects([self jsonFiles], @[]);
    XCTAssertFalse([store hasPendingWork]);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"legacy", @"1"], @[@"b", @"2"]]));
}

#if defined(DEBUG) && DEBUG
- (void)testJSONFileThatCouldNotBeDeletedIsDeletedByARetry {
    dispatch_block_t allowDeletion = [self writeUndeletableLegacyFlag:@"legacy" variant:@"1"];
    BSGFailingPersistentFeatureFlagStore *store = [[BSGFailingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];
    store.retryInterval = 60;
    [store replaceAllFlags:store.allFlags];
    XCTAssertEqualObjects([self jsonFiles], @[@"legacy.json"]);

    // A larger file can't be created, so a retry is scheduled, but the log is written in place and current when it runs
    NSString *variant = [@"" stringByPaddingToLength:(NSUInteger)(store.slotCapacity * 3 / 4) withString:@"x" startingAtIndex:0];
    store.failReplaceFile = YES;
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"large" variant:variant]]];
    XCTAssertTrue(store.fileIsCurrent);
    XCTAssertEqual(scheduler.pendingRetries.count, 1);
    XCTAssertEqualObjects([self jsonFiles], @[@"legacy.json"]);

    allowDeletion();
    store.failReplaceFile = NO;
    XCTAssertEqual([scheduler runPendingRetries], 1);
    XCTAssertEqualObjects([self jsonFiles], @[], @"The retry should have deleted the JSON file");
    XCTAssertFalse([store hasPendingWork]);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"large", variant]]));
}
#endif

#pragma mark Folders with JSON file names

- (void)testFoldersNamedLikeJSONFilesAreNotDeleted {
    NSString *emptyFolder = [self.directory stringByAppendingPathComponent:@"x.json"];
    NSString *folder = [self.directory stringByAppendingPathComponent:@"y.json"];
    NSString *file = [self.directory stringByAppendingPathComponent:@"z.json"];
    NSString *missing = [self.directory stringByAppendingPathComponent:@"missing.json"];
    XCTAssertTrue([NSFileManager.defaultManager createDirectoryAtPath:emptyFolder withIntermediateDirectories:NO attributes:nil error:nil]);
    XCTAssertTrue([NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:NO attributes:nil error:nil]);
    NSString *contents = [folder stringByAppendingPathComponent:@"contents"];
    XCTAssertTrue([NSData.data writeToFile:contents atomically:NO]);
    XCTAssertTrue([NSData.data writeToFile:file atomically:NO]);

    // Only the regular file is deleted; folders are not reported as still to delete
    XCTAssertEqualObjects(BSGRemoveLegacyFeatureFlagFiles(@[emptyFolder, folder, file, missing]), @[]);
    BOOL isDirectory = NO;
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:emptyFolder isDirectory:&isDirectory] && isDirectory);
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:contents]);
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:file]);
}

- (void)testStoreLeavesAFolderNamedLikeAJSONFileAlone {
    NSString *folder = [self.directory stringByAppendingPathComponent:@"x.json"];
    XCTAssertTrue([NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:NO attributes:nil error:nil]);
    [self writeLegacyFlag:@"legacy" variant:@"1" index:0];

    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store replaceAllFlags:store.allFlags];
    XCTAssertEqualObjects(BSGFlagsArray(store.allFlags), (@[@[@"legacy", @"1"]]));
    XCTAssertEqualObjects([self jsonFiles], @[@"x.json"], @"The JSON file is deleted, the folder is not");
    XCTAssertEqualObjects(store.pendingLegacyPaths, @[], @"The folder is not tried again");
    XCTAssertFalse([store hasPendingWork]);
    BOOL isDirectory = NO;
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:folder isDirectory:&isDirectory] && isDirectory);
}

#pragma mark Directory at the file's path

#if defined(DEBUG) && DEBUG
- (void)testNonEmptyDirectoryAtFilePathIsNotRetried {
    XCTAssertTrue([NSFileManager.defaultManager createDirectoryAtPath:self.filePath withIntermediateDirectories:NO attributes:nil error:nil]);
    XCTAssertTrue([NSData.data writeToFile:[self.filePath stringByAppendingPathComponent:@"contents"] atomically:NO]);
    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];
    store.retryInterval = 60;
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqual(store.replaceFileCount, 1);
    XCTAssertEqual(scheduler.delays.count, 0, @"A permanent failure should not be retried");
    [store protectedDataDidBecomeAvailable];
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"b" variant:@"2"]]];
    [store addFeatureFlag:@"c" withVariant:@"3"];
    XCTAssertEqual(store.replaceFileCount, 1);
    XCTAssertEqual(scheduler.delays.count, 0);
    XCTAssertEqualObjects([self files], (@[@"featureflag.bin", @"featureflag.lock"]));
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:[self.filePath stringByAppendingPathComponent:@"contents"]]);
}

- (void)testEmptyDirectoryAtFilePathIsReplacedWithoutARetry {
    XCTAssertTrue([NSFileManager.defaultManager createDirectoryAtPath:self.filePath withIntermediateDirectories:NO attributes:nil error:nil]);
    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];
    store.retryInterval = 60;
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqual(store.replaceFileCount, 1);
    XCTAssertEqual(scheduler.delays.count, 0);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"]]));
}

- (void)testAFlagChangeResetsTheDelay {
    BSGFailingPersistentFeatureFlagStore *store = [[BSGFailingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];
    store.retryInterval = 60;
    store.failReplaceFile = YES;
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqual(scheduler.pendingRetries.count, 1);
    // As after many failures, with the next retry a long way off
    store.retryDelay = 3600;
    store.retryTime = NSProcessInfo.processInfo.systemUptime + 3600;
    store.failReplaceFile = NO;

    // Adding the same flag again is not a change
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqual(store.retryDelay, 3600);
    XCTAssertEqual(scheduler.pendingRetries.count, 1);

    [store addFeatureFlag:@"b" withVariant:@"2"];
    XCTAssertEqual(store.retryDelay, 0);
    XCTAssertLessThanOrEqual(store.retryTime, NSProcessInfo.processInfo.systemUptime + 60);
    // The retry comes after the retry interval, not in an hour
    XCTAssertEqual(scheduler.pendingRetries.count, 2);
    XCTAssertLessThanOrEqual(scheduler.delays.lastObject.doubleValue, 60);
    XCTAssertEqualObjects([self reopenedFlags], @[]);

    // The superseded retry does nothing; the new one saves the flags
    dispatch_block_t superseded = scheduler.pendingRetries.firstObject;
    [scheduler.pendingRetries removeObjectAtIndex:0];
    superseded();
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    XCTAssertEqual([scheduler runPendingRetries], 1);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"], @[@"b", @"2"]]));
}
#endif

#pragma mark The lock is tried again

/// A store created while featureflag.lock can't be opened, so it takes the lock later (one finding it held never
/// retries). Call BSGRestoreLockFile only after the lock holder releases it.
- (BSGCountingPersistentFeatureFlagStore *)newStoreThatTakesTheLockLater {
    if (!BSGMakeLockFileUnopenable(self.directory)) {
        return nil;
    }
    NSString *directory = self.directory;
    [self addTeardownBlock:^{ BSGRestoreLockFile(directory); }];
    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    XCTAssertEqual(store.lockFd, -1);
    XCTAssertFalse(store.lockGivenUp);
    return store;
}

- (void)testStoreThatTakesTheLockLaterPersistsItsOwnFlags {
    BSGPersistentFeatureFlagStore *first = [self newStore];
    [first addFeatureFlag:@"previous" withVariant:@"1"];

    BSGCountingPersistentFeatureFlagStore *second = [self newStoreThatTakesTheLockLater];
    XCTSkipUnless(second, @"File permissions are not enforced for root");
    // Without the lock the previous launch's flags aren't read (its OOM event has none)
    XCTAssertTrue(second.isEmpty);
    [second addFeatureFlag:@"second" withVariant:@"2"];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"previous", @"1"]]));

    // With the first store gone, the second takes the lock at its next write after the interval and replaces the flags
    first = nil;
    BSGRestoreLockFile(self.directory);
    second.retryTime = 0;
    [second addFeatureFlag:@"third" withVariant:@"3"];
    NSArray *expected = @[@[@"second", @"2"], @[@"third", @"3"]];
    XCTAssertEqualObjects(BSGFlagsArray(second.allFlags), expected);
    XCTAssertEqualObjects([self reopenedFlags], expected);

    // From then on it writes like any lock holder
    [second clear:@"second"];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"third", @"3"]]));
    [second clear];
    XCTAssertEqualObjects([self reopenedFlags], @[]);
}

- (void)testJSONFilesAreNotReadWithoutTheLockAndAreDeletedOnceItIsTaken {
    [[self newStore] addFeatureFlag:@"previous" withVariant:@"1"];
    [self writeLegacyFlag:@"legacy" variant:@"2" index:0];
    BSGCountingPersistentFeatureFlagStore *store = [self newStoreThatTakesTheLockLater];
    XCTSkipUnless(store, @"File permissions are not enforced for root");
    XCTAssertTrue(store.isEmpty);
    XCTAssertEqualObjects([self jsonFiles], @[@"legacy.json"]);

    BSGRestoreLockFile(self.directory);
    store.retryTime = 0;
    [store addFeatureFlag:@"own" withVariant:nil];
    XCTAssertNotEqual(store.lockFd, -1);
    // The JSON file and the previous launch's file are stale once this store writes
    XCTAssertEqualObjects([self jsonFiles], @[]);
    store = nil;
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"own", NSNull.null]]));
}

#if defined(DEBUG) && DEBUG
- (void)testRetryTimerTakesTheLockOnceItIsReleased {
    BSGPersistentFeatureFlagStore *first = [self newStore];
    [first addFeatureFlag:@"first" withVariant:@"1"];
    BSGPersistentFeatureFlagStore *second = [self newStoreThatTakesTheLockLater];
    XCTSkipUnless(second, @"File permissions are not enforced for root");
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:second];
    second.retryTime = 0;
    // Nothing changes the flags after start, so only the retry saves them
    [second replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"start" variant:@"2"]]];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"first", @"1"]]));
    XCTAssertEqual(scheduler.pendingRetries.count, 1);
    first = nil;
    BSGRestoreLockFile(self.directory);
    XCTAssertEqual([scheduler runPendingRetries], 1);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"start", @"2"]]));
}
#endif

- (void)testStoreThatTakesTheLockLaterEmptiesTheFileWhenItHasNoFlags {
    BSGPersistentFeatureFlagStore *first = [self newStore];
    [first addFeatureFlag:@"previous" withVariant:@"1"];
    BSGPersistentFeatureFlagStore *second = [self newStoreThatTakesTheLockLater];
    XCTSkipUnless(second, @"File permissions are not enforced for root");
    [second replaceAllFlags:@[]];
    first = nil;
    BSGRestoreLockFile(self.directory);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"previous", @"1"]]));
    // Earlier flags must go once this store can write
    second.retryTime = 0;
    [second clear];
    XCTAssertEqualObjects([self reopenedFlags], @[]);
}

- (void)testStoreThatTakesTheLockLaterReplacesAnUnusableFile {
    BSGPersistentFeatureFlagStore *first = [self newStore];
    [first addFeatureFlag:@"previous" withVariant:@"1"];
    BSGPersistentFeatureFlagStore *second = [self newStoreThatTakesTheLockLater];
    XCTSkipUnless(second, @"File permissions are not enforced for root");
    first = nil;
    BSGRestoreLockFile(self.directory);
    // Another process left an unusable file and a temp file
    XCTAssertTrue([[@"not a feature flag file" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:self.filePath atomically:YES]);
    NSString *temporaryPath = [self.filePath stringByAppendingString:@".6F9619FF-8B86-D011-B42D-00CF4FC964FF.tmp"];
    XCTAssertTrue([NSData.data writeToFile:temporaryPath atomically:NO]);
    second.retryTime = 0;
    [second addFeatureFlag:@"second" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"second", NSNull.null]]));
    XCTAssertEqualObjects([self files], (@[@"featureflag.bin", @"featureflag.lock"]));
}

#pragma mark File systems without flock()

#if defined(DEBUG) && DEBUG
- (void)testFlagsArePersistedWhenTheFileSystemDoesNotSupportLocking {
    for (NSNumber *error in @[@(ENOTSUP), @(EOPNOTSUPP)]) {
        [NSFileManager.defaultManager removeItemAtPath:self.directory error:nil];
        [NSFileManager.defaultManager createDirectoryAtPath:self.directory withIntermediateDirectories:YES attributes:nil error:nil];
        [self simulateLockFailure:error.intValue];
        BSGPersistentFeatureFlagStore *store = [self newStore];
        BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
        [scheduler attachToStore:store];
        [store addFeatureFlag:@"a" withVariant:@"1"];
        [store addFeatureFlag:@"b" withVariant:nil];
        [store clear:@"a"];
        // The store acts as the only writer: one lock attempt, writes without retries
        XCTAssertEqual(gLockCallCount, 1, @"errno %@", error);
        XCTAssertEqual(scheduler.pendingRetries.count, 0, @"errno %@", error);
        XCTAssertEqualObjects([self files], (@[@"featureflag.bin", @"featureflag.lock"]));
        store = nil;
        // The next launch reads them and also writes without the lock
        store = [self newStore];
        XCTAssertEqualObjects(BSGFlagsArray(store.allFlags), (@[@[@"b", NSNull.null]]), @"errno %@", error);
        [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"start"]]];
        store = nil;
        XCTAssertEqualObjects([self reopenedFlags], (@[@[@"start", NSNull.null]]), @"errno %@", error);
    }
}

- (void)testFlagsAreNotPersistedWhileAnotherStoreHoldsTheLock {
    // Unlike ENOTSUP, EWOULDBLOCK means another store owns the directory for its lifetime, so the lock is tried and
    // logged once.
    [self simulateLockFailure:EWOULDBLOCK];
    BSGPersistentFeatureFlagStore *store = [self newStore];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqual(gLockCallCount, 1);
    XCTAssertTrue(store.lockGivenUp);
    XCTAssertEqualObjects([self files], (@[@"featureflag.lock"]));
    XCTAssertEqual(scheduler.pendingRetries.count, 0, @"The lock should not be tried again");
    XCTAssertEqualObjects(BSGFlagsArray(store.allFlags), (@[@[@"a", @"1"]]));

    // Not on later changes, at start, after the interval or on unlock, even once lockable
    BSGSetFeatureFlagLockFunction(NULL);
    store.retryTime = 0;
    [store addFeatureFlag:@"b" withVariant:nil];
    [store addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:@"c"]]];
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"start"]]];
    [store clear:@"start"];
    [store clear];
    [store protectedDataDidBecomeAvailable];
    [store addFeatureFlag:@"d" withVariant:nil];
    XCTAssertEqual(gLockCallCount, 1, @"Only one attempt (and so one log message) is expected");
    XCTAssertEqual(scheduler.pendingRetries.count, 0);
    XCTAssertEqualObjects([self files], (@[@"featureflag.lock"]));
    XCTAssertEqualObjects(BSGFlagsArray(store.allFlags), (@[@[@"d", NSNull.null]]));
}

- (void)testStoreThatFindsTheLockHeldTriesOnlyOnce {
    // As above, with a real lock held by another store
    BSGPersistentFeatureFlagStore *first = [self newStore];
    [first addFeatureFlag:@"first" withVariant:@"1"];
    [self simulateLockFailure:0];
    BSGSetFeatureFlagLockFunction(CountingLock);
    BSGCountingPersistentFeatureFlagStore *second = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:second];
    XCTAssertEqual(gLockCallCount, 1);
    for (int i = 0; i < 20; i++) {
        second.retryTime = 0;
        [second addFeatureFlag:[NSString stringWithFormat:@"flag-%d", i] withVariant:nil];
    }
    [second replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"start"]]];
    first = nil;
    second.retryTime = 0;
    [second addFeatureFlag:@"after-release" withVariant:nil];
    XCTAssertEqual(gLockCallCount, 1);
    XCTAssertEqual(scheduler.pendingRetries.count, 0);
    XCTAssertEqual(second.writeCount, 0);
}

- (void)testOtherLockFailuresAreRetried {
    [self simulateLockFailure:EIO];
    BSGPersistentFeatureFlagStore *store = [self newStore];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqual(gLockCallCount, 1);
    XCTAssertFalse(store.lockGivenUp);
    XCTAssertEqualObjects([self files], (@[@"featureflag.lock"]));
    XCTAssertEqual(scheduler.pendingRetries.count, 1, @"The lock should be tried again later");
    // Not on every change within the retry interval
    [store addFeatureFlag:@"b" withVariant:@"2"];
    XCTAssertEqual(gLockCallCount, 1);

    // Once the lock can be taken, the retry saves the flags
    BSGSetFeatureFlagLockFunction(NULL);
    XCTAssertEqual([scheduler runPendingRetries], 1);
    store = nil;
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"], @[@"b", @"2"]]));
}

- (void)testLockFileThatCannotBeOpenedIsRetried {
    BSGPersistentFeatureFlagStore *first = [self newStore];
    [first addFeatureFlag:@"first" withVariant:@"1"];
    first = nil;
    // As while protected data is unavailable
    XCTSkipUnless(BSGMakeLockFileUnopenable(self.directory), @"File permissions are not enforced for root");
    NSString *directory = self.directory;
    [self addTeardownBlock:^{ BSGRestoreLockFile(directory); }];
    BSGPersistentFeatureFlagStore *store = [self newStore];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];
    XCTAssertEqual(store.lockFd, -1);
    XCTAssertFalse(store.lockGivenUp);
    XCTAssertTrue(store.isEmpty, @"Without the lock, the previous launch's flags are not read");
    store.retryTime = 0;
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"start"]]];
    XCTAssertEqual(scheduler.pendingRetries.count, 1);

    BSGRestoreLockFile(self.directory);
    XCTAssertEqual([scheduler runPendingRetries], 1);
    XCTAssertNotEqual(store.lockFd, -1);
    store = nil;
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"start", NSNull.null]]));
}
#endif

#pragma mark Protected data becoming available

#if defined(DEBUG) && DEBUG
- (void)testProtectedDataBecomingAvailableOnlyActsOnPendingWork {
    // A store whose file is current has nothing to do
    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    const NSUInteger writes = store.writeCount;
    [store protectedDataDidBecomeAvailable];
    XCTAssertEqual(store.writeCount, writes);

    // Nor does one with no flags and no file
    store = nil;
    [NSFileManager.defaultManager removeItemAtPath:self.directory error:nil];
    [NSFileManager.defaultManager createDirectoryAtPath:self.directory withIntermediateDirectories:YES attributes:nil error:nil];
    store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    [store protectedDataDidBecomeAvailable];
    XCTAssertEqual(store.writeCount, 0);
    XCTAssertEqualObjects([self files], @[]);

    // Nor one whose flags are over the size limit
    NSString *huge = [@"" stringByPaddingToLength:2 * 1024 * 1024 withString:@"x" startingAtIndex:0];
    [self simulateLockFailure:0];
    BSGSetFeatureFlagLockFunction(CountingLock);
    [store addFeatureFlag:@"huge" withVariant:huge];
    [store protectedDataDidBecomeAvailable];
    XCTAssertEqual(store.writeCount, 0);
    XCTAssertEqual(gLockCallCount, 0, @"The lock is not needed for flags that cannot be saved");
    XCTAssertEqualObjects([self files], @[]);
}

- (void)testProtectedDataBecomingAvailableRespectsTheBackoffForOtherFailures {
    // A file that can't be replaced for a reason other than protected data
    BSGFailingPersistentFeatureFlagStore *store = [[BSGFailingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    store.failReplaceFile = YES;
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqual(store.replaceFileCount, 1);
    [store protectedDataDidBecomeAvailable];
    [store protectedDataDidBecomeAvailable];
    XCTAssertEqual(store.replaceFileCount, 1, @"The file should not be replaced again before the retry time");
}
#endif

- (void)testProtectedDataBecomingAvailableTakesTheLock {
    BSGPersistentFeatureFlagStore *first = [self newStore];
    [first addFeatureFlag:@"first" withVariant:@"1"];
    // featureflag.lock cannot be opened, as while protected data is unavailable
    XCTSkipUnless(BSGMakeLockFileUnopenable(self.directory), @"File permissions are not enforced for root");
    NSString *directory = self.directory;
    [self addTeardownBlock:^{ BSGRestoreLockFile(directory); }];
    BSGPersistentFeatureFlagStore *second = [self newStore];
    second.retryTime = 0;
    [second replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"second" variant:@"2"]]];
    first = nil;
    BSGRestoreLockFile(self.directory);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"first", @"1"]]));
    // Within the retry interval, but an unlock is reason to retry
    [second protectedDataDidBecomeAvailable];
    XCTAssertNotEqual(second.lockFd, -1);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"second", @"2"]]));
}

#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION
- (void)testProtectedDataNotificationTakesTheLock {
    BSGPersistentFeatureFlagStore *first = [self newStore];
    [first addFeatureFlag:@"first" withVariant:@"1"];
    XCTSkipUnless(BSGMakeLockFileUnopenable(self.directory), @"File permissions are not enforced for root");
    NSString *directory = self.directory;
    [self addTeardownBlock:^{ BSGRestoreLockFile(directory); }];
    BSGPersistentFeatureFlagStore *second = [self newStore];
    second.retryTime = 0;
    [second replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"second" variant:@"2"]]];
    first = nil;
    BSGRestoreLockFile(self.directory);
    // The save runs in the background, so wait on the store rather than open the directory
    [NSNotificationCenter.defaultCenter postNotificationName:@"UIApplicationProtectedDataDidBecomeAvailable" object:nil];
    XCTAssertTrue(BSGWaitUntilStoreHasSaved(second, 30));
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"second", @"2"]]));
    (void)second;
}
#endif

#pragma mark Flags over the size limit

#if defined(DEBUG) && DEBUG
- (void)testChangesOverTheLimitOnlyCostTheEncoding {
    [self simulateLockFailure:0];
    BSGSetFeatureFlagLockFunction(CountingLock);
    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    NSString *huge = [@"" stringByPaddingToLength:2 * 1024 * 1024 withString:@"x" startingAtIndex:0];
    // With no file, over-limit flags take no lock and create nothing
    [store addFeatureFlag:@"huge" withVariant:huge];
    for (int i = 0; i < 10; i++) {
        [store addFeatureFlag:[NSString stringWithFormat:@"flag-%d", i] withVariant:nil];
    }
    XCTAssertEqual(gLockCallCount, 0);
    XCTAssertEqual(store.writeCount, 0);
    XCTAssertEqualObjects([self files], @[]);

    // With a file, the log is emptied once, then nothing is written while over the limit
    [store clear];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqual(gLockCallCount, 1);
    [store addFeatureFlag:@"huge" withVariant:huge];
    const NSUInteger writes = store.writeCount;
    for (int i = 0; i < 10; i++) {
        [store addFeatureFlag:[NSString stringWithFormat:@"flag-%d", i] withVariant:nil];
    }
    [store clear:@"flag-0"];
    XCTAssertEqual(store.writeCount, writes);
    XCTAssertEqualObjects([self reopenedFlags], @[]);

    // Back under the limit, they are saved
    [store clear:@"huge"];
    XCTAssertEqual([self reopenedFlags].count, 10);
}
#endif

#pragma mark Writes that are not needed

- (void)testStartingWithTheSameFlagsWritesNothing {
    BSGPersistentFeatureFlagStore *previous = [self newStore];
    [previous addFeatureFlag:@"a" withVariant:@"1"];
    [previous addFeatureFlag:@"b" withVariant:nil];
    [previous addFeatureFlag:@"a" withVariant:@"2"];
    previous = nil;
    NSData *contents = [NSData dataWithContentsOfFile:self.filePath];

    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    XCTAssertEqual(store.writeCount, 0, @"Nothing is written when the store is created");
    // Starting with the previous launch's flags
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"a" variant:@"2"], [BugsnagFeatureFlag flagWithName:@"b"]]];
    XCTAssertEqual(store.writeCount, 0);
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:self.filePath], contents);
    // Records are still appended to the file afterwards
    [store addFeatureFlag:@"c" withVariant:nil];
    XCTAssertEqual(store.writeCount, 1);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"2"], @[@"b", NSNull.null], @[@"c", NSNull.null]]));

    // Different flags, or a new order, are written
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"b"], [BugsnagFeatureFlag flagWithName:@"a" variant:@"2"]]];
    XCTAssertEqual(store.writeCount, 2);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"b", NSNull.null], @[@"a", @"2"]]));
}

- (void)testUpgradeFromJSONFilesWritesOnce {
    [self writeLegacyFlag:@"legacy" variant:@"1" index:0];
    [self writeLegacyFlag:@"other" variant:nil index:1];
    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    XCTAssertEqualObjects(BSGFlagsArray(store.allFlags), (@[@[@"legacy", @"1"], @[@"other", NSNull.null]]));
    XCTAssertEqual(store.writeCount, 0, @"Nothing is written when the store is created");
    XCTAssertEqual([self jsonFiles].count, 2, @"The JSON files are kept until the flags have been written");

    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"start" variant:@"2"]]];
    XCTAssertEqual(store.writeCount, 1);
    XCTAssertEqualObjects([self jsonFiles], @[], @"featureflag.bin and JSON files must not both be kept");
    XCTAssertEqualObjects([self files], (@[@"featureflag.bin", @"featureflag.lock"]));
    store = nil;
    // The imported flags are kept ahead of the app's flags
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"legacy", @"1"], @[@"other", NSNull.null], @[@"start", @"2"]]));
}

#pragma mark featureflag.lock removed while it is created

// LockFileRemovingSetProtection's removal count and the functions it wraps
#if defined(DEBUG) && DEBUG
static NSUInteger gLockFileRemovals;
static BSGFileProtectionFunctions gRealProtectionFunctions;
#endif

static BOOL IsTestLockFile(NSString *path) {
    return BSGIsInTestDirectory(path) && [path.lastPathComponent isEqualToString:@"featureflag.lock"];
}

#if defined(DEBUG) && DEBUG
/// Reports NSFileProtectionComplete for the test's featureflag.lock, so it is reopened after the class change.
static NSString *_Nullable LockFileIsCompleteGetProtection(NSString *path) {
    if (IsTestLockFile(path)) {
        return NSURLFileProtectionComplete;
    }
    return gRealProtectionFunctions.getProtection(path);
}

/// Removes the test's featureflag.lock on its first class change, between BSGOpenFileWithoutCompleteProtection's two
/// opens, as if the directory were cleared then.
static BOOL LockFileRemovingSetProtection(NSString *path, NSString *protection, NSError **error) {
    if (IsTestLockFile(path)) {
        if (gLockFileRemovals == 0) {
            gLockFileRemovals++;
            unlink(path.fileSystemRepresentation);
        }
        return YES;
    }
    return gRealProtectionFunctions.setProtection(path, protection, error);
}

- (void)testLockFileRemovedWhileItIsCreatedIsOpenedAgain {
    gLockFileRemovals = 0;
    // Set before installing the simulated functions, which other threads may call at once
    gRealProtectionFunctions = BSGSetFileProtectionFunctions((BSGFileProtectionFunctions){0});
    gRealProtectionFunctions = BSGSetFileProtectionFunctions((BSGFileProtectionFunctions){
        .getProtection = LockFileIsCompleteGetProtection,
        .setProtection = LockFileRemovingSetProtection,
    });
    [self addTeardownBlock:^{
        BSGSetFileProtectionFunctions(gRealProtectionFunctions);
    }];
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqual(gLockFileRemovals, 1);
    XCTAssertNotEqual(store.lockFd, -1, @"The lock file should have been opened again at once, not retried later");

    // The lock is on the file now at the path, not the removed one, so no other store can take it
    NSString *lockPath = [self.directory stringByAppendingPathComponent:@"featureflag.lock"];
    struct stat byDescriptor, byPath;
    XCTAssertEqual(fstat(store.lockFd, &byDescriptor), 0);
    XCTAssertEqual(lstat(lockPath.fileSystemRepresentation, &byPath), 0);
    XCTAssertEqual(byDescriptor.st_ino, byPath.st_ino);
    errno = 0;
    const int other = open(lockPath.fileSystemRepresentation, O_RDONLY | O_EXLOCK | O_NONBLOCK);
    XCTAssertEqual(other, -1);
    XCTAssertEqual(errno, EWOULDBLOCK);
    if (other != -1) {
        close(other);
    }
    XCTAssertEqualObjects(BSGFlagsInFeatureFlagFile(self.directory), (@[@[@"a", @"1"]]));
}
#endif

#pragma mark Protection classes and backup

#if defined(DEBUG) && DEBUG
static NSUInteger gProtectionCallCount;
static BSGFileProtectionFunctions gCountedProtectionFunctions;

// Only calls for the test's directory are counted
static NSString *_Nullable CountingGetProtection(NSString *path) {
    if (BSGIsInTestDirectory(path)) {
        gProtectionCallCount++;
    }
    return gCountedProtectionFunctions.getProtection(path);
}

static BOOL CountingSetProtection(NSString *path, NSString *protection, NSError **error) {
    if (BSGIsInTestDirectory(path)) {
        gProtectionCallCount++;
    }
    return gCountedProtectionFunctions.setProtection(path, protection, error);
}

- (void)testChangesMakeNoProtectionClassCalls {
    gProtectionCallCount = 0;
    // Set before installing the counting functions, which other threads may call at once
    gCountedProtectionFunctions = BSGSetFileProtectionFunctions((BSGFileProtectionFunctions){0});
    gCountedProtectionFunctions = BSGSetFileProtectionFunctions((BSGFileProtectionFunctions){
        .getProtection = CountingGetProtection,
        .setProtection = CountingSetProtection,
    });
    [self addTeardownBlock:^{
        BSGSetFileProtectionFunctions(gCountedProtectionFunctions);
    }];
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    // The class is set when the files are created
    XCTAssertGreaterThan(gProtectionCallCount, 0);
    XCTAssertLessThanOrEqual(gProtectionCallCount, 2);

    gProtectionCallCount = 0;
    for (int i = 0; i < 100; i++) {
        [store addFeatureFlag:@"a" withVariant:[NSString stringWithFormat:@"%d", i]];
    }
    [store clear:@"a"];
    [store addFeatureFlag:@"b" withVariant:nil];
    XCTAssertEqual(gProtectionCallCount, 0, @"Changes should not read or set protection classes");

    // Nor on reopening next launch: rename() kept the class set at creation
    store = nil;
    store = [self newStore];
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"c"]]];
    XCTAssertEqual(gProtectionCallCount, 0);
}
#endif

#pragma mark Symbolic links

/// Creates featureflag.bin with flag "elsewhere" in another directory, symlinked from the store's. Returns its
/// contents.
- (NSData *)linkToFileElsewhere {
    NSString *elsewhere = [self.directory stringByAppendingPathComponent:@"elsewhere"];
    [NSFileManager.defaultManager createDirectoryAtPath:elsewhere withIntermediateDirectories:NO attributes:nil error:nil];
    BSGPersistentFeatureFlagStore *store = [[BSGPersistentFeatureFlagStore alloc] initWithStorageDirectory:elsewhere];
    [store addFeatureFlag:@"elsewhere" withVariant:@"1"];
    store = nil;
    NSString *target = [elsewhere stringByAppendingPathComponent:@"featureflag.bin"];
    XCTAssertEqual(symlink(target.fileSystemRepresentation, self.filePath.fileSystemRepresentation), 0);
    NSData *contents = [NSData dataWithContentsOfFile:target];
    XCTAssertGreaterThan(contents.length, 0);
    return contents;
}

- (NSData *)contentsOfFileElsewhere {
    return [NSData dataWithContentsOfFile:[self.directory stringByAppendingPathComponent:@"elsewhere/featureflag.bin"]];
}

- (void)testSymbolicLinkIsNotFollowedByTheStoreThatHoldsTheLock {
    NSData *contents = [self linkToFileElsewhere];
    BSGPersistentFeatureFlagStore *store = [self newStore];
    XCTAssertTrue(store.isEmpty, @"The flags of the file the link points to must not be read");
    [store addFeatureFlag:@"a" withVariant:nil];
    XCTAssertEqualObjects([self contentsOfFileElsewhere], contents, @"The file the link points to must not be changed");
    // The link is replaced by the store's own file
    struct stat st;
    XCTAssertEqual(lstat(self.filePath.fileSystemRepresentation, &st), 0);
    XCTAssertTrue(S_ISREG(st.st_mode));
    store = nil;
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", NSNull.null]]));
}

- (void)testSymbolicLinkIsNotFollowedByAStoreWithoutTheLock {
    BSGPersistentFeatureFlagStore *owner = [self newStore];
    [owner addFeatureFlag:@"owner" withVariant:nil];
    XCTAssertEqual(unlink(self.filePath.fileSystemRepresentation), 0);
    NSData *contents = [self linkToFileElsewhere];

    BSGPersistentFeatureFlagStore *other = [self newStore];
    XCTAssertTrue(other.isEmpty, @"The flags of the file the link points to must not be read");
    [other addFeatureFlag:@"other" withVariant:nil];
    other = nil;
    XCTAssertEqualObjects([self contentsOfFileElsewhere], contents);
    struct stat st;
    XCTAssertEqual(lstat(self.filePath.fileSystemRepresentation, &st), 0);
    XCTAssertTrue(S_ISLNK(st.st_mode), @"A store without the lock changes nothing");
}

- (void)testSymbolicLinkIsNotTreatedAsAFileNextToJSONFiles {
    // A link holds no flags, so the JSON files beside it are imported, not discarded as if both kinds existed
    NSData *contents = [self linkToFileElsewhere];
    [self writeLegacyFlag:@"legacy" variant:@"1" index:0];
    BSGPersistentFeatureFlagStore *store = [self newStore];
    XCTAssertEqualObjects(BSGFlagsArray(store.allFlags), (@[@[@"legacy", @"1"]]));
    store = nil;
    XCTAssertEqualObjects([self contentsOfFileElsewhere], contents);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"legacy", @"1"]]));
}

- (void)testSymbolicLinkToAJSONFileIsNotFollowed {
    NSString *elsewhere = [self.directory stringByAppendingPathComponent:@"elsewhere"];
    [NSFileManager.defaultManager createDirectoryAtPath:elsewhere withIntermediateDirectories:NO attributes:nil error:nil];
    NSString *target = [elsewhere stringByAppendingPathComponent:@"linked.json"];
    XCTAssertTrue([[@"{\"featureFlag\":\"linked\",\"index\":0}" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:target atomically:NO]);
    XCTAssertEqual(symlink(target.fileSystemRepresentation, [self.directory stringByAppendingPathComponent:@"linked.json"].fileSystemRepresentation), 0);
    [self writeLegacyFlag:@"legacy" variant:@"1" index:1];

    BSGPersistentFeatureFlagStore *store = [self newStore];
    XCTAssertEqualObjects(BSGFlagsArray(store.allFlags), (@[@[@"legacy", @"1"]]));
    [store replaceAllFlags:store.allFlags];
    // The link is deleted with the JSON files; its target is not
    XCTAssertEqualObjects([self jsonFiles], @[]);
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:target]);
}

#pragma mark JSON files that could not be deleted

- (void)testLegacyFilesThatCouldNotBeDeletedAreDeletedByTheNextWrite {
    XCTSkipIf(geteuid() == 0, @"File permissions are not enforced for root");
    [self writeLegacyFlag:@"legacy" variant:@"1" index:0];
    int fd = open([self.directory stringByAppendingPathComponent:@"featureflag.lock"].fileSystemRepresentation, O_RDONLY | O_CREAT, 0600);
    XCTAssertNotEqual(fd, -1);
    close(fd);
    // JSON files can't be deleted nor featureflag.bin created
    XCTAssertEqual(chmod(self.directory.fileSystemRepresentation, 0500), 0);
    BSGPersistentFeatureFlagStore *store = [self newStore];
    XCTAssertEqualObjects(BSGFlagsArray(store.allFlags), (@[@[@"legacy", @"1"]]));
    XCTAssertEqual([self jsonFiles].count, 1);
    XCTAssertEqual(chmod(self.directory.fileSystemRepresentation, 0700), 0);

    // The next write deletes them, even within the retry interval
    [store addFeatureFlag:@"a" withVariant:nil];
    XCTAssertEqualObjects([self jsonFiles], @[]);
    store.retryTime = 0;
    [store addFeatureFlag:@"b" withVariant:nil];
    store = nil;
    // So the next launch finds one kind of file and reports the flags
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"legacy", @"1"], @[@"a", NSNull.null], @[@"b", NSNull.null]]));
}

- (void)testLegacyFilesThatCouldNotBeDeletedAreDeletedWhenTheFlagsAreCleared {
    XCTSkipIf(geteuid() == 0, @"File permissions are not enforced for root");
    [self writeLegacyFlag:@"legacy" variant:@"1" index:0];
    int fd = open([self.directory stringByAppendingPathComponent:@"featureflag.lock"].fileSystemRepresentation, O_RDONLY | O_CREAT, 0600);
    XCTAssertNotEqual(fd, -1);
    close(fd);
    XCTAssertEqual(chmod(self.directory.fileSystemRepresentation, 0500), 0);
    BSGPersistentFeatureFlagStore *store = [self newStore];
    XCTAssertEqual(chmod(self.directory.fileSystemRepresentation, 0700), 0);
    // Clearing all flags drops the imported ones too; nothing to write
    [store clear];
    [store replaceAllFlags:@[]];
    XCTAssertEqualObjects([self files], (@[@"featureflag.lock"]));
    store = nil;
    XCTAssertEqualObjects([self reopenedFlags], @[]);
}

@end
