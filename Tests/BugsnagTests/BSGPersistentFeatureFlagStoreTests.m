//
//  BSGPersistentFeatureFlagStoreTests.m
//  Bugsnag
//
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import "BSGTestCase.h"

#import "BSGAtomicFeatureFlagStore.h"
#import "BSGCompositeFeatureFlagStore.h"
#import "BSGMemoryFeatureFlagStore.h"
#import "BSGPersistentFeatureFlagStore.h"
#import "BSGUtils.h"
#import "BugsnagFeatureFlag.h"

#import <errno.h>
#import <fcntl.h>
#import <signal.h>
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
@end

/// Waits until the store holds the lock and has saved its current flags, as a retry that runs in the background
/// does. Unlike reading the file from another store, this does not take the lock, so it never competes with the
/// retry it is waiting for.
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

/// Records the retries that stores schedule instead of running them after their delay, so that a test decides when
/// they run and does not depend on timing. It does not retain the stores: the retries hold them weakly.
@interface BSGManualRetryScheduler : NSObject
/// The delay of each retry scheduled so far, in order.
@property (nonatomic, readonly) NSMutableArray<NSNumber *> *delays;
@property (nonatomic, readonly) NSMutableArray<dispatch_block_t> *pendingRetries;
- (void)attachToStore:(BSGPersistentFeatureFlagStore *)store;
/// Runs the retries scheduled so far, in order, and returns how many were run. Only the most recently scheduled
/// one does anything. Retries that they schedule are left pending.
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

/// Counts calls to the store's private methods.
/// A store whose file can never be replaced, as when the disk is full.
@interface BSGUnreplaceablePersistentFeatureFlagStore : BSGPersistentFeatureFlagStore
@end

@implementation BSGUnreplaceablePersistentFeatureFlagStore

- (BOOL)replaceFileWithSnapshot:(__unused NSData *)snapshot {
    return NO;
}

@end

@interface BSGCountingPersistentFeatureFlagStore : BSGPersistentFeatureFlagStore
@property (nonatomic) NSUInteger snapshotCount;
@property (nonatomic) NSUInteger appendCount;
@property (nonatomic) NSUInteger replaceFileCount;
@property (nonatomic) NSUInteger clearCount;
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

@end

/// Fails to replace the file while failReplaceFile is set, or passes a different snapshot to it.
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

/// Fails the next failHeaderWrites writes of the header's active value, as an I/O error would. Writes of the
/// log itself are not affected, so this reaches the case where the records were written but the header was not.
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

/// Runs the block with the process's file size limit (RLIMIT_FSIZE) set to `limit` bytes, so that writing or
/// extending any file past that offset fails with EFBIG, as writes fail when the disk is full. A write that
/// crosses the limit is cut short. SIGXFSZ, which would otherwise end the process, is ignored meanwhile.
/// Returns NO if the limit could not be set.
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
    block();
    setrlimit(RLIMIT_FSIZE, &original);
    signal(SIGXFSZ, previousHandler);
    return YES;
}

static NSArray * FlagNames(NSArray<BugsnagFeatureFlag *> *flags) {
    return [flags valueForKey:@"name"];
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

/// A memory store that can stand in for the persistent store, or act as the reference that a persistent store's
/// order is checked against. The SDK's memory store does not implement replaceAllFlags: because nothing calls it.
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
}

- (void)tearDown {
    // Restored in case testUnwritableDirectoryAfterTheFileIsCreated failed part way through
    chmod(self.directory.fileSystemRepresentation, 0700);
    [NSFileManager.defaultManager removeItemAtPath:self.directory error:nil];
    [super tearDown];
}

#pragma mark Helpers

- (NSString *)filePath {
    return [self.directory stringByAppendingPathComponent:@"featureflag.bin"];
}

/// Named "new" so that ARC returns it retained rather than autoreleased: a store keeps the directory's
/// lock until it is deallocated, so a store that is used once must be released straight away.
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
    return FlagsToArray([self newStore].allFlags);
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

/// The offset in the file of the active snapshot.
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
    // A file that cannot be used holds no flags that can be read, and there is nothing to save, so it is
    // removed rather than replaced
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
    // The file is not created until there is something to save
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
    // An entry with an empty name and no variant is just the two lengths
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
    // The file is created whole (it is not preallocated, so it can be sparse), and grows by being replaced
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
    // Each entry is two uint32 lengths followed by the name and variant
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
    // A removal record is the name length, UINT32_MAX - 1 and the name
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
    // Each change appends 10 bytes; the log is rewritten once it holds 4096 bytes of records it no longer
    // needs, or sooner if the slot is smaller than that (4 KB pages)
    uint64_t longestLog = 0;
    for (int i = 0; i < 1000; i++) {
        [store addFeatureFlag:(i % 2) ? @"a" : @"b" withVariant:[NSString stringWithFormat:@"%d", i % 10]];
        longestLog = MAX(longestLog, [self activeValue] >> 1);
    }
    // The current flags take 20 bytes, so the log never holds more than 4096 bytes it doesn't need
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
    // A flag that is not last changes nothing either, because it keeps its position
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
    // Add flags one at a time until they take up most of a slot, then keep changing one of them
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
    // Replacing a persisted variant with one that cannot be encoded removes the persisted record
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
    // Encodable again: b keeps its position before c and d, as in the memory store, so the log is rewritten
    // (a record appended to it would put b at the end when it is replayed)
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
    // It shrinks to a quarter of its size at a time, so that clearing and refilling flags doesn't keep replacing it
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

    // As when Bugsnag starts: the memory store's flags replace the persisted ones
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

- (void)testCompositeStoreSynchronizesUsingReplaceAllFlags {
    BSGRecordingFeatureFlagStore *persistentStore = [BSGRecordingFeatureFlagStore new];
    BSGRecordingFeatureFlagStore *atomicStore = [BSGRecordingFeatureFlagStore new];
    BSGMemoryFeatureFlagStore *memoryStore = [BSGMemoryFeatureFlagStore new];
    [memoryStore addFeatureFlag:@"a" withVariant:@"1"];
    [memoryStore addFeatureFlag:@"b" withVariant:nil];
    BSGCompositeFeatureFlagStore *store = [BSGCompositeFeatureFlagStore storeWithMemoryStore:memoryStore
                                                                             persistentStore:persistentStore
                                                                                 atomicStore:atomicStore];
    [store synchronizeFlagsWithMemoryStore];
    NSArray *expected = @[@[@"replaceAllFlags:", @[@"a", @"b"]]];
    XCTAssertEqualObjects(persistentStore.calls, expected);
    XCTAssertEqualObjects(atomicStore.calls, expected);
    XCTAssertEqualObjects(FlagsToArray(memoryStore.allFlags), (@[@[@"a", @"1"], @[@"b", NSNull.null]]));
}

#pragma mark Same order as the memory store

/// Applies operations to a memory store and a persistent store, checking after each that both hold the
/// same flags in the same order, also after the persistent store is reloaded.
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
        // A flag that is cleared and added again goes to the end
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
    // Enough changes to the same few flags that the log is also rewritten (compacted) several times
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
    // The limit is just under 2 MB of flags, in slots of up to 4 MB (an 8 MB file)
    NSString *large = [@"" stringByPaddingToLength:1200 * 1024 withString:@"x" startingAtIndex:0];
    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    [store addFeatureFlag:@"small" withVariant:@"1"];
    [store addFeatureFlag:@"large-1" withVariant:large];
    NSArray *persisted = @[@[@"small", @"1"], @[@"large-1", large]];
    XCTAssertEqualObjects([self reopenedFlags], persisted);
    XCTAssertLessThanOrEqual([[NSFileManager.defaultManager attributesOfItemAtPath:self.filePath error:nil] fileSize], 8 * 1024 * 1024ULL);

    // Crossing the limit empties the persisted log, and the flags stay in memory
    [store addFeatureFlag:@"large-2" withVariant:large];
    XCTAssertEqual(store.allFlags.count, 3);
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    XCTAssertLessThanOrEqual([[NSFileManager.defaultManager attributesOfItemAtPath:self.filePath error:nil] fileSize], 8 * 1024 * 1024ULL);
    const NSUInteger replacements = store.replaceFileCount;
    [store addFeatureFlag:@"another" withVariant:nil];
    [store addFeatureFlag:@"small" withVariant:@"2"];
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    XCTAssertEqual(store.replaceFileCount, replacements, @"Flags over the limit are not written");

    // Dropping back under the limit persists them again, without waiting for a retry interval
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

- (void)testFailedWriteIsRetriedAfterTheRetryInterval {
    // As when Bugsnag starts: flags set only at start must be saved even though nothing changes them later
    BSGFailingPersistentFeatureFlagStore *store = [[BSGFailingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];
    // Long enough that the changes below are always within it, however slowly the test runs
    store.retryInterval = 3600;
    store.failReplaceFile = YES;
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"a" variant:@"1"], [BugsnagFeatureFlag flagWithName:@"b"]]];
    XCTAssertEqual(scheduler.delays.count, 1);
    XCTAssertEqualWithAccuracy(scheduler.delays.firstObject.doubleValue, 3600, 60);
    // Changes within the retry interval neither write the file nor schedule more retries
    [store addFeatureFlag:@"c" withVariant:nil];
    [store addFeatureFlag:@"d" withVariant:nil];
    XCTAssertEqual(store.replaceFileCount, 1);
    XCTAssertEqual(scheduler.delays.count, 1, @"Only one retry should have been scheduled");
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    store.failReplaceFile = NO;

    // The retry saves the flags, including the changes made since the failure
    XCTAssertEqual([scheduler runPendingRetries], 1);
    NSArray *expected = @[@[@"a", @"1"], @[@"b", NSNull.null], @[@"c", NSNull.null], @[@"d", NSNull.null]];
    XCTAssertEqual(store.replaceFileCount, 2);
    XCTAssertEqualObjects([self reopenedFlags], expected);
    XCTAssertEqual(scheduler.pendingRetries.count, 0, @"Nothing more should be scheduled after a success");
}

- (void)testFailedWriteIsRetriedByTheTimer {
    // The same with the real timer (dispatch_after), waiting for as long as a slow machine could need
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

- (void)testReplaceAllFlagsIsNotDelayedByAnEarlierFailure {
    BSGFailingPersistentFeatureFlagStore *store = [[BSGFailingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    store.failReplaceFile = YES;
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqual(store.replaceFileCount, 1);
    store.failReplaceFile = NO;
    // Within the retry interval a change does not write the file...
    [store addFeatureFlag:@"b" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    // ...but replacing all of the flags, which Bugsnag does when it starts, does
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"start" variant:@"1"]]];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"start", @"1"]]));
}

- (void)testFailureWhenCreatedIsRetriedWhenBugsnagStarts {
    XCTSkipIf(geteuid() == 0, @"File permissions are not enforced for root");
    [self writeLegacyFlag:@"legacy" variant:@"1" index:0];
    // The lock file is created before the directory becomes read-only
    int fd = open([self.directory stringByAppendingPathComponent:@"featureflag.lock"].fileSystemRepresentation, O_RDONLY | O_CREAT, 0600);
    XCTAssertNotEqual(fd, -1);
    close(fd);
    XCTAssertEqual(chmod(self.directory.fileSystemRepresentation, 0500), 0);
    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), (@[@[@"legacy", @"1"]]));
    XCTAssertEqual(store.replaceFileCount, 1);
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:self.filePath]);
    XCTAssertEqual(chmod(self.directory.fileSystemRepresentation, 0700), 0);

    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"start" variant:nil]]];
    XCTAssertEqual(store.replaceFileCount, 2);
    // The JSON files that could not be deleted when the store was created are deleted by the next write, so
    // the next launch does not find both kinds of file
    XCTAssertEqual([self jsonFiles].count, 0);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"start", NSNull.null]]));
}

#pragma mark Legacy files

- (void)testLegacyFilesAreImportedAndDeleted {
    [self writeLegacyFlag:@"third" variant:nil index:7];
    [self writeLegacyFlag:@"first" variant:@"1" index:0];
    [self writeLegacyFlag:@"second flag/ü" variant:@"" index:3];
    XCTAssertEqual([self jsonFiles].count, 3);

    BSGPersistentFeatureFlagStore *store = [self newStore];
    NSArray *expected = @[@[@"first", @"1"], @[@"second flag/ü", @""], @[@"third", NSNull.null]];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), expected);
    XCTAssertEqualObjects([self jsonFiles], @[]);
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:self.filePath]);
    XCTAssertEqualObjects([self reopenedFlags], expected);
}

- (void)testLegacyFlagWithAnEmptyNameIsImportedAndDeleted {
    // Saved as ".json", which has no path extension
    [self writeLegacyFlag:@"" variant:@"empty name" index:1];
    [self writeLegacyFlag:@"a" variant:nil index:0];
    XCTAssertEqual([self jsonFiles].count, 2);

    NSArray *expected = @[@[@"a", NSNull.null], @[@"", @"empty name"]];
    XCTAssertEqualObjects(FlagsToArray([self newStore].allFlags), expected);
    XCTAssertEqualObjects([self jsonFiles], @[]);
    XCTAssertEqualObjects([self reopenedFlags], expected);
}

- (void)testInvalidLegacyFilesAreIgnored {
    [self writeLegacyFlag:@"valid" variant:@"v" index:1];
    [[@"not json" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:[self.directory stringByAppendingPathComponent:@"bad.json"] atomically:YES];
    [[@"[1,2]" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:[self.directory stringByAppendingPathComponent:@"array.json"] atomically:YES];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"valid", @"v"]]));
    XCTAssertEqualObjects([self jsonFiles], @[]);
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
    XCTAssertEqualObjects(FlagsToArray([self newStore].allFlags), expected);
    XCTAssertEqualObjects([self jsonFiles], @[]);
    XCTAssertEqualObjects([self reopenedFlags], expected);
}

- (void)testFileAndLegacyFilesAreBothDiscardedWhenFoundTogether {
    [[self newStore] addFeatureFlag:@"current" withVariant:@"1"];
    // Only left together when a file could not be deleted; which of them is current is unknown
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
    // A capacity larger than the store reads (16 MB), in a file large enough to hold it so that only
    // the capacity limit can reject it. The file is sparse, so it does not use much disk space.
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
    // A later version may write larger slots than this one; they are read as long as they are within
    // the read limit
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
    // On 32-bit platforms, a file size calculated in size_t would wrap and pass the size check
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
    // Accessing the slots would touch pages past the end of the file
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
    // Make the second entry's name length run past the end of the snapshot
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

    // No changes are made, so the corrupt snapshot must be replaced when the store is opened
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

- (void)testDirectoryAtFilePath {
    XCTAssertTrue([NSFileManager.defaultManager createDirectoryAtPath:self.filePath withIntermediateDirectories:NO attributes:nil error:nil]);

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
    // Writing the file is not retried on every change; only replaceAllFlags (called when Bugsnag starts)
    // tries again within the retry interval
    XCTAssertEqual(store.replaceFileCount, 2);

    BOOL isDirectory = NO;
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:self.filePath isDirectory:&isDirectory]);
    XCTAssertTrue(isDirectory);
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

- (void)testDirectoryAtFilePathWithLegacyFiles {
    [NSFileManager.defaultManager createDirectoryAtPath:self.filePath withIntermediateDirectories:NO attributes:nil error:nil];
    [self writeLegacyFlag:@"legacy" variant:@"1" index:0];
    BSGPersistentFeatureFlagStore *store = [self newStore];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), (@[@[@"legacy", @"1"]]));
    // The legacy files are deleted even though the flags could not be saved, so that they are not
    // imported again at the next launch when they would be stale
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
    // The file is intact, so it keeps the flags as they were when they last fitted, never a partial set
    NSArray *earlier = @[@[@"a", @"1"], @[@"b", @"2"]];
    XCTAssertEqualObjects([self reopenedFlags], earlier);
    [store addFeatureFlag:@"c" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], earlier);
    [store clear:@"a"];
    XCTAssertEqualObjects([self reopenedFlags], earlier, @"Nothing is appended to the earlier log");

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
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"]]), @"The flags that last fitted are kept");
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
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"]]), @"The flags that last fitted are kept");
    XCTAssertEqual(chmod(self.directory.fileSystemRepresentation, 0700), 0);

    // Within the retry interval the file is not written
    [store addFeatureFlag:@"b" withVariant:nil];
    XCTAssertEqual(store.replaceFileCount, 2);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"]]));

    // Once it has passed, the next change writes all of the flags
    store.retryTime = 0;
    [store clear:@"a"];
    [store addFeatureFlag:@"c" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"large", large], @[@"b", NSNull.null], @[@"c", NSNull.null]]));
}

- (void)testUnreadableFileIsDeletedWhenItCannotBeReplaced {
    XCTSkipIf(geteuid() == 0, @"File permissions are not enforced for root");
    [[self newStore] addFeatureFlag:@"previous-launch" withVariant:@"1"];
    // The file cannot be opened, and a new file cannot be written
    XCTAssertEqual(chmod(self.filePath.fileSystemRepresentation, 0), 0);

    BSGPersistentFeatureFlagStore *store = [[BSGUnreplaceablePersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    XCTAssertEqualObjects(store.allFlags, @[]);
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:self.filePath],
                   @"The flags of an earlier launch must not be left to be reported in a later OOM event");
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), (@[@[@"a", @"1"]]));
}

- (void)testTooLargeToPersist {
    BSGFailingPersistentFeatureFlagStore *store = [[BSGFailingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqual(store.replaceFileCount, 1);

    // Reserved but never touched, so this does not use the memory
    const size_t length = UINT32_MAX / 8 + 1;
    void *bytes = mmap(NULL, length, PROT_READ, MAP_PRIVATE | MAP_ANON, -1, 0);
    XCTAssertNotEqual(bytes, MAP_FAILED);
    store.replacementSnapshot = [NSData dataWithBytesNoCopy:bytes length:length freeWhenDone:NO];

    NSString *large = [@"" stringByPaddingToLength:4 * (NSUInteger)getpagesize() withString:@"x" startingAtIndex:0];
    [store addFeatureFlag:@"large" withVariant:large];
    XCTAssertEqual(store.replaceFileCount, 2);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"]]), @"The file keeps the flags that last fitted");

    // Within the retry interval the file is not replaced on later changes, even though they would now fit
    store.replacementSnapshot = nil;
    munmap(bytes, length);
    [store addFeatureFlag:@"b" withVariant:nil];
    [store addFeatureFlag:@"large" withVariant:[large stringByAppendingString:@"y"]];
    XCTAssertEqual(store.replaceFileCount, 2);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"]]));
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

/// Adds enough flags to replace the file with a larger one, with each flag's variant equal to its name.
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
    // Two clients, or two instances of a macOS app, use the same directory. Only the store that holds the
    // lock writes to it, so the file holds exactly that store's flags.
    BSGPersistentFeatureFlagStore *first = [self newStore];
    // The lock is taken before the first write, so the first store writes before the second is created
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
    [NSData.data writeToFile:[self.directory stringByAppendingPathComponent:@"flags.bin"] atomically:NO];
    NSDictionary *contents = [self directoryContents];

    BSGCountingPersistentFeatureFlagStore *second = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    // The flags of the previous launch can still be read
    XCTAssertEqualObjects(FlagsToArray(second.allFlags), (@[@[@"first", @"1"]]));
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

    // Once it is deallocated, a new store takes the lock and writes
    first = nil;
    BSGPersistentFeatureFlagStore *third = [self newStore];
    [third addFeatureFlag:@"third" withVariant:@"3"];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"first", @"1"], @[@"more", NSNull.null], @[@"third", @"3"]]));
    NSArray *files = [[NSFileManager.defaultManager contentsOfDirectoryAtPath:self.directory error:nil] sortedArrayUsingSelector:@selector(compare:)];
    XCTAssertEqualObjects(files, (@[@"featureflag.bin", @"featureflag.lock"]));
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

- (void)testFilesWrittenByPrereleaseBuildsAreDeleted {
    // Pre-release builds used flags.bin; the file is not read, just deleted
    NSString *prerelease = [self.directory stringByAppendingPathComponent:@"flags.bin"];
    [[self newStore] addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertTrue([NSFileManager.defaultManager moveItemAtPath:self.filePath toPath:prerelease error:nil]);
    [NSData.data writeToFile:[prerelease stringByAppendingString:@".6F9619FF-8B86-D011-B42D-00CF4FC964FF.tmp"] atomically:NO];
    [NSData.data writeToFile:[self.directory stringByAppendingPathComponent:@"flags.binary"] atomically:NO];

    BSGPersistentFeatureFlagStore *store = [self newStore];
    XCTAssertEqualObjects(store.allFlags, @[]);
    NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.directory error:nil];
    XCTAssertEqualObjects([files sortedArrayUsingSelector:@selector(compare:)], (@[@"featureflag.lock", @"flags.binary"]));
}

- (void)testSlotCapacityChangedByAnotherProcessIsIgnored {
    // Offsets come from the slot capacity read when the file was opened or created, not from the header,
    // which another process could change.
    BSGPersistentFeatureFlagStore *store = [self newStore];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    // Clearing writes the log into the other slot, whose address depends on the slot capacity
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
    // As if another process using this directory was killed while replacing the file
    [NSData.data writeToFile:[self.filePath stringByAppendingString:@".tmp"] atomically:NO];
    BSGGrowStore(store, @"after", 1000);
    XCTAssertEqual([self reopenedFlags].count, 1001);
}

#pragma mark Write errors

- (void)testAppendFailureEmptiesTheLogAndIsRetried {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqual([self activeValue], 10 << 1, @"One 10-byte record in slot 0");

    // The record for "b" (10 bytes at offset 42) crosses the limit, so it is written in part and then fails
    // with EFBIG, like a write to a full disk. The header is below the limit, so the log can be emptied.
    XCTAssertTrue(BSGWithFileSizeLimit(HeaderSize + 10 + 4, ^{
        [store addFeatureFlag:@"b" withVariant:@"2"];
    }));
    NSArray *expected = @[@[@"a", @"1"], @[@"b", @"2"]];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), expected, @"The flags stay in memory");
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:self.filePath]);
    XCTAssertEqualObjects([self reopenedFlags], @[], @"The file must not hold flags that have since changed");
    [self assertFileIsAValidEmptySnapshot];

    // A change within the retry interval is not written, and the scheduled retry saves everything
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

    // The new log fits in the file, so it is written to slot 1, which is past the limit
    XCTAssertTrue(BSGWithFileSizeLimit(HeaderSize + slotCapacity, ^{
        [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"c" variant:@"3"]]];
    }));
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), (@[@[@"c", @"3"]]));
    XCTAssertEqualObjects([self reopenedFlags], @[], @"The file must not hold the replaced flags");
    XCTAssertEqual([scheduler runPendingRetries], 1);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"c", @"3"]]));
}

- (void)testHeaderWriteFailureDeletesTheFile {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];
    [store addFeatureFlag:@"a" withVariant:@"1"];

    // Neither the record nor the header (at offset 16) can be written, so the log cannot be emptied and
    // the file, which this store owns, is deleted instead
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

- (void)testHeaderWriteFailureAfterTheRecordsWereWritten {
    BSGHeaderFailingPersistentFeatureFlagStore *store =
    [[BSGHeaderFailingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];
    [store addFeatureFlag:@"a" withVariant:@"1"];

    // The records are written but the length that makes them part of the log is not; the log is emptied
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

    // The temporary file cannot be extended to its full size (ftruncate fails with EFBIG)
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

#pragma mark Lock and open errors

- (void)testLockCannotBeCreatedInAnUnwritableDirectory {
    XCTSkipIf(geteuid() == 0, @"File permissions are not enforced for root");
    [[self newStore] addFeatureFlag:@"previous" withVariant:@"1"];
    NSString *lockPath = [self.directory stringByAppendingPathComponent:@"featureflag.lock"];
    XCTAssertEqual(unlink(lockPath.fileSystemRepresentation), 0);
    NSData *contents = [NSData dataWithContentsOfFile:self.filePath];
    XCTAssertEqual(chmod(self.directory.fileSystemRepresentation, 0500), 0);

    // Without the lock the store reads the flags but changes nothing
    BSGPersistentFeatureFlagStore *store = [self newStore];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), (@[@[@"previous", @"1"]]));
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
    XCTAssertTrue(other.isEmpty, @"The file cannot be read");
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:self.filePath], @"A store without the lock deletes nothing");
    other = nil;

    // The store that holds the lock still writes through the descriptor it has open
    [owner addFeatureFlag:@"b" withVariant:nil];
    XCTAssertEqual(chmod(self.filePath.fileSystemRepresentation, 0600), 0);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"], @[@"b", NSNull.null]]));
}

#pragma mark Size limit and decoding

- (void)testSizeLimitAtTheExactBoundary {
    // The limit applies to the encoded flags: each record is 8 bytes of lengths, then the name and variant
    const NSUInteger maxSlotCapacity = 2 * 1024 * 1024 - 16;
    // The largest slot is twice as large, so that a log of flags at the limit can still double
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

    // Back at the limit, the flags are persisted again in the same file
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
    // The log ends 3 bytes into what would be the next record's lengths (the slot is zero-filled)
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

    BSGPersistentFeatureFlagStore *store = [self newStore];
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
    // Files with the same index keep the order in which the directory was listed
    NSSet *middle = [NSSet setWithArray:[flags subarrayWithRange:NSMakeRange(1, 2)]];
    XCTAssertEqualObjects(middle, ([NSSet setWithArray:@[@[@"same-1", NSNull.null], @[@"same-2", @"2"]]]));
    XCTAssertEqualObjects([self reopenedFlags], flags);
}

#pragma mark Growing the file while the device is locked

// How many times SimulatedLockedCreateFile has been called
static NSUInteger gLockedCreateFileCount;

/// Stands in for creating a file while the device is locked for an app whose default protection class is
/// NSFileProtectionComplete, which open() refuses with EPERM.
static BOOL SimulatedLockedCreateFile(__unused NSString *path) {
    gLockedCreateFileCount++;
    errno = EPERM;
    return NO;
}

/// Makes creating files fail as they do while the device is locked, until the test ends or the returned block is called.
- (dispatch_block_t)simulateLockedDevice {
    gLockedCreateFileCount = 0;
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

- (NSArray<NSString *> *)temporaryFiles {
    NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.directory error:nil];
    return [files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.tmp'"]];
}

- (void)testGrowthWhileTheDeviceIsLockedKeepsTheExistingLogAndIsRetried {
    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];
    // Long enough that the changes below are always within it, however slowly the test runs
    store.retryInterval = 3600;
    [store addFeatureFlag:@"a" withVariant:@"1"];
    [store addFeatureFlag:@"b" withVariant:@"2"];
    NSArray *earlier = @[@[@"a", @"1"], @[@"b", @"2"]];
    XCTAssertEqualObjects([self reopenedFlags], earlier);
    const uint32_t slotCapacity = [self headerFieldAtOffset:SlotCapacityOffset];
    struct stat before;
    XCTAssertEqual(lstat(self.filePath.fileSystemRepresentation, &before), 0);

    // The device locks. Records still fit in the open file, which stays writable...
    dispatch_block_t unlock = [self simulateLockedDevice];
    [store addFeatureFlag:@"b" withVariant:@"3"];
    earlier = @[@[@"a", @"1"], @[@"b", @"3"]];
    XCTAssertEqualObjects([self reopenedFlags], earlier);
    XCTAssertEqual(gLockedCreateFileCount, 0);

    // ...but a flag that needs a larger file cannot be saved, because the new file cannot be created
    NSString *large = [@"" stringByPaddingToLength:slotCapacity withString:@"x" startingAtIndex:0];
    [store addFeatureFlag:@"large" withVariant:large];
    XCTAssertEqual(gLockedCreateFileCount, 1);
    XCTAssertEqualObjects([self reopenedFlags], earlier, @"The log must not be emptied");
    XCTAssertEqual(scheduler.delays.count, 1, @"A retry should have been scheduled");
    XCTAssertEqualWithAccuracy(scheduler.delays.firstObject.doubleValue, 3600, 60);
    XCTAssertEqualObjects([self temporaryFiles], @[]);
    struct stat after;
    XCTAssertEqual(lstat(self.filePath.fileSystemRepresentation, &after), 0);
    XCTAssertEqual(after.st_ino, before.st_ino, @"The file should not have been replaced");

    // Changes within the retry interval neither empty the log nor are appended to it
    [store addFeatureFlag:@"c" withVariant:nil];
    [store clear:@"a"];
    XCTAssertEqualObjects([self reopenedFlags], earlier);
    XCTAssertEqual(gLockedCreateFileCount, 1);

    // A retry while the device is still locked keeps the log too, and schedules another
    XCTAssertEqual([scheduler runPendingRetries], 1);
    XCTAssertEqual(gLockedCreateFileCount, 2);
    XCTAssertEqualObjects([self reopenedFlags], earlier);
    XCTAssertEqual(scheduler.pendingRetries.count, 1);

    // Once the device is unlocked, the retry creates the larger file with the current flags
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
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"]]));

    // Flags that fit in the file again are written to it, without waiting for the retry or the unlock
    [store clear:@"large"];
    [store addFeatureFlag:@"b" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"], @[@"b", NSNull.null]]));
    [store addFeatureFlag:@"large" withVariant:large];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"], @[@"b", NSNull.null]]));
    // Clearing all of the flags empties the kept log
    [store clear];
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    XCTAssertEqual(gLockedCreateFileCount, 1, @"The file is not replaced again within the retry interval");
}

- (void)testAnotherStoresLogIsNotKeptWhenTheFileCannotBeGrown {
    BSGPersistentFeatureFlagStore *first = [self newStore];
    [first addFeatureFlag:@"previous" withVariant:@"1"];
    const uint32_t slotCapacity = [self headerFieldAtOffset:SlotCapacityOffset];
    BSGPersistentFeatureFlagStore *second = [self newStore];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:second];
    first = nil;

    // The second store takes the lock and the first store's file, but cannot grow it. The flags in the file were
    // never this store's own, so they are not kept in place of its flags.
    [self simulateLockedDevice];
    second.retryTime = 0;
    NSString *large = [@"" stringByPaddingToLength:slotCapacity withString:@"x" startingAtIndex:0];
    [second addFeatureFlag:@"large" withVariant:large];
    XCTAssertEqual(gLockedCreateFileCount, 1);
    XCTAssertEqualObjects(FlagsToArray(second.allFlags), (@[@[@"previous", @"1"], @[@"large", large]]));
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:self.filePath]);
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    XCTAssertEqual(scheduler.pendingRetries.count, 1);
}

#pragma mark Flags near the size limit

/// Every slot switch or file replacement that a change caused, as seen in the file. The log is rewritten whole
/// (into the other slot, or into a new file) exactly when one of these happens.
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
    // Flags exactly at the limit (just under 2 MB), so that a file whose slots were no larger than that would
    // have no room left to append to, and every change would rewrite all of the flags
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
    // 1000 records of 17 bytes fit in the room left after the flags, so nothing is rewritten
    XCTAssertEqual(rewrites, 0);
    XCTAssertEqual(store.snapshotCount, snapshots);
    XCTAssertEqual(store.replaceFileCount, replacements);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"big", big], @[@"small", [NSString stringWithFormat:@"%04lu", (unsigned long)changes]]]));
}

- (void)testLargeChangesToFlagsNearTheLimitAreRewrittenOnlyWhenTheLogDoubles {
    // 19 flags of 100 KB, which take up just under 2 MB
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

    // Each change appends 100 KB. 40 of them append about twice the size of the flags, so the log should be
    // rewritten about twice; with no room to grow it would be rewritten by nearly every change.
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

// The error that SimulatedLockFailure fails with, and how many times it has been called
static int gLockErrno;
static NSUInteger gLockCallCount;

/// Stands in for flock(), failing with gLockErrno.
static int SimulatedLockFailure(__unused int fd, __unused int operation) {
    gLockCallCount++;
    errno = gLockErrno;
    return -1;
}

@implementation BSGPersistentFeatureFlagStoreLockAndRetryTests

- (void)setUp {
    [super setUp];
    self.directory = [NSTemporaryDirectory() stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"BSGPersistentFeatureFlagStoreLockAndRetryTests-%@", NSUUID.UUID.UUIDString]];
    [NSFileManager.defaultManager createDirectoryAtPath:self.directory withIntermediateDirectories:YES attributes:nil error:nil];
}

- (void)tearDown {
    BSGSetFeatureFlagLockFunction(NULL);
    chmod(self.directory.fileSystemRepresentation, 0700);
    [NSFileManager.defaultManager removeItemAtPath:self.directory error:nil];
    [super tearDown];
}

- (NSString *)filePath {
    return [self.directory stringByAppendingPathComponent:@"featureflag.bin"];
}

/// Makes flock() fail with `error` for featureflag.lock.
- (void)simulateLockFailure:(int)error {
    gLockErrno = error;
    gLockCallCount = 0;
    BSGSetFeatureFlagLockFunction(SimulatedLockFailure);
}

/// Named "new" so that ARC returns it retained: a store keeps the directory's lock until it is deallocated.
- (BSGPersistentFeatureFlagStore *)newStore {
    return [[BSGPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
}

- (NSArray<NSString *> *)files {
    return [[NSFileManager.defaultManager contentsOfDirectoryAtPath:self.directory error:nil] sortedArrayUsingSelector:@selector(compare:)];
}

- (NSArray<NSString *> *)jsonFiles {
    return [[self files] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.json'"]];
}

/// The flags a store created now (as at the next launch) reads.
- (NSArray *)reopenedFlags {
    NSMutableArray *result = [NSMutableArray array];
    for (BugsnagFeatureFlag *flag in [self newStore].allFlags) {
        [result addObject:@[flag.name, flag.variant ?: NSNull.null]];
    }
    return result;
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
    // As when Bugsnag starts with no flags in its configuration
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

    // Flags that cannot be persisted do not create the file either
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
    // The existing file is emptied in place rather than left holding the earlier flags
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

#pragma mark Backoff

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
    // Something other than a file at the path is a failure that never clears
    XCTAssertTrue([NSFileManager.defaultManager createDirectoryAtPath:self.filePath withIntermediateDirectories:NO attributes:nil error:nil]);
    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:store];
    store.retryInterval = 60;
    store.maximumRetryInterval = 3600;
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqual(store.replaceFileCount, 1);
    // Each attempt fails and schedules the next after twice the delay, up to an hour, rather than every minute
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
    // A retry is scheduled after the retry interval rather than in an hour
    XCTAssertEqual(scheduler.pendingRetries.count, 2);
    XCTAssertLessThanOrEqual(scheduler.delays.lastObject.doubleValue, 60);
    XCTAssertEqualObjects([self reopenedFlags], @[]);

    // The earlier retry has been superseded and does nothing; the new one saves the flags
    dispatch_block_t superseded = scheduler.pendingRetries.firstObject;
    [scheduler.pendingRetries removeObjectAtIndex:0];
    superseded();
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    XCTAssertEqual([scheduler runPendingRetries], 1);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"], @[@"b", @"2"]]));
}

#pragma mark The lock is tried again

- (void)testStoreThatTakesTheLockLaterKeepsThePreviousFlagsAndPersistsItsOwn {
    BSGPersistentFeatureFlagStore *first = [self newStore];
    [first addFeatureFlag:@"previous" withVariant:@"1"];

    BSGCountingPersistentFeatureFlagStore *second = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    // The flags read when the store is created (which an OOM event for the previous launch reports) are kept
    XCTAssertEqualObjects(BSGFlagsArray(second.allFlags), (@[@[@"previous", @"1"]]));
    [second addFeatureFlag:@"second" withVariant:@"2"];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"previous", @"1"]]));

    // The first store's lock is released; the second takes it at its next write after the retry interval
    first = nil;
    second.retryTime = 0;
    [second addFeatureFlag:@"third" withVariant:@"3"];
    NSArray *expected = @[@[@"previous", @"1"], @[@"second", @"2"], @[@"third", @"3"]];
    XCTAssertEqualObjects(BSGFlagsArray(second.allFlags), expected);
    XCTAssertEqualObjects([self reopenedFlags], expected);

    // From then on it writes like any store that holds the lock
    [second clear:@"previous"];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"second", @"2"], @[@"third", @"3"]]));
    [second clear];
    XCTAssertEqualObjects([self reopenedFlags], @[]);
}

- (void)testRetryTimerTakesTheLockOnceItIsReleased {
    BSGPersistentFeatureFlagStore *first = [self newStore];
    [first addFeatureFlag:@"first" withVariant:@"1"];
    BSGPersistentFeatureFlagStore *second = [self newStore];
    BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
    [scheduler attachToStore:second];
    second.retryTime = 0;
    // As when Bugsnag starts: nothing changes the flags later, so only the retry saves them
    [second replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"start" variant:@"2"]]];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"first", @"1"]]));
    XCTAssertEqual(scheduler.pendingRetries.count, 1);
    first = nil;
    XCTAssertEqual([scheduler runPendingRetries], 1);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"start", @"2"]]));
}

- (void)testStoreThatTakesTheLockLaterEmptiesTheFileWhenItHasNoFlags {
    BSGPersistentFeatureFlagStore *first = [self newStore];
    [first addFeatureFlag:@"previous" withVariant:@"1"];
    BSGPersistentFeatureFlagStore *second = [self newStore];
    [second replaceAllFlags:@[]];
    first = nil;
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"previous", @"1"]]));
    // The earlier flags must not stay in the file once this store can write
    second.retryTime = 0;
    [second clear];
    XCTAssertEqualObjects([self reopenedFlags], @[]);
}

- (void)testStoreThatTakesTheLockLaterReplacesAnUnusableFile {
    BSGPersistentFeatureFlagStore *first = [self newStore];
    [first addFeatureFlag:@"previous" withVariant:@"1"];
    BSGPersistentFeatureFlagStore *second = [self newStore];
    first = nil;
    // Another process leaves an unusable file and a temporary file
    XCTAssertTrue([[@"not a feature flag file" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:self.filePath atomically:YES]);
    NSString *temporaryPath = [self.filePath stringByAppendingString:@".6F9619FF-8B86-D011-B42D-00CF4FC964FF.tmp"];
    XCTAssertTrue([NSData.data writeToFile:temporaryPath atomically:NO]);
    second.retryTime = 0;
    [second addFeatureFlag:@"second" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"previous", @"1"], @[@"second", NSNull.null]]));
    XCTAssertEqualObjects([self files], (@[@"featureflag.bin", @"featureflag.lock"]));
}

#if TARGET_OS_IOS || TARGET_OS_TV
- (void)testProtectedDataBecomingAvailableTakesTheLock {
    BSGPersistentFeatureFlagStore *first = [self newStore];
    [first addFeatureFlag:@"first" withVariant:@"1"];
    BSGPersistentFeatureFlagStore *second = [self newStore];
    [second replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"second" variant:@"2"]]];
    first = nil;
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"first", @"1"]]));
    // The retry interval has not passed, but the device being unlocked is a reason to try again. The save runs in
    // the background, so the test waits for the store itself rather than opening the directory meanwhile.
    [NSNotificationCenter.defaultCenter postNotificationName:@"UIApplicationProtectedDataDidBecomeAvailable" object:nil];
    XCTAssertTrue(BSGWaitUntilStoreHasSaved(second, 30));
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"second", @"2"]]));
    (void)second;
}
#endif

#pragma mark File systems without flock()

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
        // The store proceeds as the only writer: it writes without retrying, and only tries to lock once
        XCTAssertEqual(gLockCallCount, 1, @"errno %@", error);
        XCTAssertEqual(scheduler.pendingRetries.count, 0, @"errno %@", error);
        XCTAssertEqualObjects([self files], (@[@"featureflag.bin", @"featureflag.lock"]));
        store = nil;
        // The next launch reads them, and also writes without the lock
        store = [self newStore];
        XCTAssertEqualObjects(BSGFlagsArray(store.allFlags), (@[@[@"b", NSNull.null]]), @"errno %@", error);
        [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"start"]]];
        store = nil;
        XCTAssertEqualObjects([self reopenedFlags], (@[@[@"start", NSNull.null]]), @"errno %@", error);
    }
}

- (void)testFlagsAreNotPersistedWhileAnotherStoreHoldsTheLock {
    // Unlike ENOTSUP, EWOULDBLOCK means that another store writes to the directory, so this one must not
    for (NSNumber *error in @[@(EWOULDBLOCK), @(EIO)]) {
        [self simulateLockFailure:error.intValue];
        BSGPersistentFeatureFlagStore *store = [self newStore];
        BSGManualRetryScheduler *scheduler = [BSGManualRetryScheduler new];
        [scheduler attachToStore:store];
        [store addFeatureFlag:@"a" withVariant:@"1"];
        XCTAssertEqual(gLockCallCount, 1);
        XCTAssertEqualObjects([self files], (@[@"featureflag.lock"]), @"errno %@", error);
        XCTAssertEqual(scheduler.pendingRetries.count, 1, @"The lock should be tried again later");
        XCTAssertEqualObjects(BSGFlagsArray(store.allFlags), (@[@[@"a", @"1"]]));

        // Once the lock can be taken, the retry saves the flags
        BSGSetFeatureFlagLockFunction(NULL);
        XCTAssertEqual([scheduler runPendingRetries], 1);
        store = nil;
        XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"]]), @"errno %@", error);
        [NSFileManager.defaultManager removeItemAtPath:self.filePath error:nil];
    }
}

#pragma mark Symbolic links

/// Creates a featureflag.bin holding flag "elsewhere" in another directory, and a symbolic link to it named
/// featureflag.bin in the store's directory. Returns the file's contents.
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
    // The link is replaced by a file of this store's own
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
    // A link at the path cannot hold flags, so the JSON files next to it are imported rather than discarded as
    // though both kinds of file had been found
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
    // The link is deleted with the other JSON files, but not the file it points to
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
    // Neither the JSON files can be deleted nor featureflag.bin created
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
    // So the next launch does not find both kinds of file, and reports the flags
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
    [store replaceAllFlags:@[]];
    XCTAssertEqualObjects([self files], (@[@"featureflag.lock"]));
    store = nil;
    XCTAssertEqualObjects([self reopenedFlags], @[]);
}

@end
