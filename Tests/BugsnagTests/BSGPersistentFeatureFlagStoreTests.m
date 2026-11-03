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
#import "BugsnagFeatureFlag.h"

#import <fcntl.h>
#import <sys/mman.h>
#import <sys/stat.h>

// Layout of the file header; see BSGPersistentFeatureFlagStore.m
// XCTSkipIf is not available in the oldest versions of Xcode used to run the tests
#ifdef XCTSkipIf
#define BSGSkipIf(condition, ...) XCTSkipIf(condition, __VA_ARGS__)
#else
#define BSGSkipIf(condition, ...) if (condition) { NSLog(__VA_ARGS__); return; }
#endif

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
@property (nonatomic) NSTimeInterval retryInterval;
@property (nonatomic) NSTimeInterval retryTime;
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

static NSArray * FlagNames(NSArray<BugsnagFeatureFlag *> *flags) {
    return [flags valueForKey:@"name"];
}

/// Records the BSGFeatureFlagStore methods that are called.
@interface BSGRecordingFeatureFlagStore : NSObject <BSGFeatureFlagStore>
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
    // Restored in case testUnwritableDirectoryAfterMapping failed part way through
    chmod(self.directory.fileSystemRepresentation, 0700);
    [NSFileManager.defaultManager removeItemAtPath:self.directory error:nil];
    [super tearDown];
}

#pragma mark Helpers

- (NSString *)filePath {
    return [self.directory stringByAppendingPathComponent:@"flags.bin"];
}

- (BSGPersistentFeatureFlagStore *)openStore {
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
    return FlagsToArray([self openStore].allFlags);
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

- (void)assertFileBlocksAreAllocated {
    // st_blocks is not reliable for this on APFS, but SEEK_HOLE finds the first hole, which is
    // the end of the file if every block is allocated
    int fd = open(self.filePath.fileSystemRepresentation, O_RDONLY);
    XCTAssertNotEqual(fd, -1);
    struct stat st;
    XCTAssertEqual(fstat(fd, &st), 0);
    XCTAssertEqual(lseek(fd, 0, SEEK_HOLE), st.st_size, @"The file should not be sparse");
    close(fd);
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
    BSGPersistentFeatureFlagStore *store = [self openStore];
    XCTAssertTrue(store.isEmpty);
    XCTAssertEqualObjects(store.allFlags, @[]);
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:self.filePath]);
    XCTAssertEqualObjects([self reopenedFlags], @[]);
}

- (void)testAddAndReopen {
    BSGPersistentFeatureFlagStore *store = [self openStore];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    [store addFeatureFlag:@"b" withVariant:nil];
    [store addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:@"c" variant:@"3"],
                             [BugsnagFeatureFlag flagWithName:@"d"]]];
    NSArray *expected = @[@[@"a", @"1"], @[@"b", NSNull.null], @[@"c", @"3"], @[@"d", NSNull.null]];
    XCTAssertFalse(store.isEmpty);
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), expected);
    XCTAssertEqualObjects([self reopenedFlags], expected);
}

- (void)testOverwriteMovesFlagToEnd {
    BSGPersistentFeatureFlagStore *store = [self openStore];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    [store addFeatureFlag:@"b" withVariant:@"2"];
    [store addFeatureFlag:@"c" withVariant:@"3"];
    [store addFeatureFlag:@"a" withVariant:@"1b"];
    [store addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:@"b" variant:nil],
                             [BugsnagFeatureFlag flagWithName:@"e" variant:@"5"]]];
    NSArray *expected = @[@[@"c", @"3"], @[@"a", @"1b"], @[@"b", NSNull.null], @[@"e", @"5"]];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), expected);
    XCTAssertEqualObjects([self reopenedFlags], expected);
}

- (void)testClearNamedFlag {
    BSGPersistentFeatureFlagStore *store = [self openStore];
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
    BSGPersistentFeatureFlagStore *store = [self openStore];
    NSMutableString *name = [NSMutableString stringWithString:@"a"];
    [store addFeatureFlag:name withVariant:@"1"];
    [name setString:@"b"];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), (@[@[@"a", @"1"]]));

    [store clear:@"a"];
    XCTAssertTrue(store.isEmpty);
    XCTAssertEqualObjects([self reopenedFlags], @[]);
}

- (void)testClearAll {
    BSGPersistentFeatureFlagStore *store = [self openStore];
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
    [[self openStore] addFeatureFlag:@"a" withVariant:@"1"];
    BSGPersistentFeatureFlagStore *store = [self openStore];
    [store addFeatureFlag:@"b" withVariant:@"2"];
    [store addFeatureFlag:@"a" withVariant:@"3"];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"b", @"2"], @[@"a", @"3"]]));
}

#pragma mark Encoding

- (void)testNilAndEmptyVariantsAreDistinct {
    BSGPersistentFeatureFlagStore *store = [self openStore];
    [store addFeatureFlag:@"nil" withVariant:nil];
    [store addFeatureFlag:@"empty" withVariant:@""];
    [store addFeatureFlag:@"" withVariant:@"empty name"];
    NSArray<BugsnagFeatureFlag *> *flags = [self openStore].allFlags;
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
    BSGPersistentFeatureFlagStore *store = [self openStore];
    [store addFeatureFlag:@"" withVariant:nil];
    XCTAssertEqual([self activeValue] >> 1, 8);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"", NSNull.null]]));

    [store addFeatureFlag:@"a" withVariant:@"1"];
    [store addFeatureFlag:@"" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"], @[@"", NSNull.null]]));
}

- (void)testUnicodeNames {
    BSGPersistentFeatureFlagStore *store = [self openStore];
    [store addFeatureFlag:@"フラグ🚩" withVariant:@"variante-é"];
    [store addFeatureFlag:@"Ελληνικά name" withVariant:@"👩‍👩‍👧‍👦"];
    NSArray *expected = @[@[@"フラグ🚩", @"variante-é"], @[@"Ελληνικά name", @"👩‍👩‍👧‍👦"]];
    XCTAssertEqualObjects([self reopenedFlags], expected);
}

- (void)testLongNames {
    NSString *longName = [@"" stringByPaddingToLength:10 * 1024 withString:@"n" startingAtIndex:0];
    NSString *longVariant = [@"" stringByPaddingToLength:10 * 1024 withString:@"vé" startingAtIndex:0];
    BSGPersistentFeatureFlagStore *store = [self openStore];
    [store addFeatureFlag:@"short" withVariant:nil];
    [store addFeatureFlag:longName withVariant:longVariant];
    [store addFeatureFlag:@"after" withVariant:@"x"];
    NSArray *expected = @[@[@"short", NSNull.null], @[longName, longVariant], @[@"after", @"x"]];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), expected);
    XCTAssertEqualObjects([self reopenedFlags], expected);
}

#pragma mark Growth

- (void)assertGrowthWithCount:(NSUInteger)count {
    BSGPersistentFeatureFlagStore *store = [self openStore];
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

- (void)testFileBlocksAreAllocated {
    BSGPersistentFeatureFlagStore *store = [self openStore];
    [self assertFileBlocksAreAllocated];
    const unsigned long long initialSize = [[NSFileManager.defaultManager attributesOfItemAtPath:self.filePath error:nil] fileSize];
    for (NSUInteger i = 0; i < 10000; i++) {
        [store addFeatureFlag:[NSString stringWithFormat:@"flag-%lu", (unsigned long)i] withVariant:@"variant"];
    }
    XCTAssertGreaterThan([[NSFileManager.defaultManager attributesOfItemAtPath:self.filePath error:nil] fileSize], initialSize);
    [self assertFileBlocksAreAllocated];
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
    BSGPersistentFeatureFlagStore *store = [self openStore];
    [store addFeatureFlag:@"first" withVariant:nil];
    [store addFeatureFlags:flags];
    NSArray *reopened = [self reopenedFlags];
    XCTAssertEqual(reopened.count, 5001);
    XCTAssertEqualObjects(reopened.firstObject, (@[@"first", NSNull.null]));
    XCTAssertEqualObjects(reopened.lastObject, (@[@"batch-4999", @"v"]));
}

#pragma mark Append vs snapshot

- (void)testNewFlagsAreAppendedToTheActiveSlot {
    BSGPersistentFeatureFlagStore *store = [self openStore];
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
    BSGPersistentFeatureFlagStore *store = [self openStore];
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

    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"new", NSNull.null], @[@"a", NSNull.null]]));
}

- (void)testChangesNeverRewriteTheLog {
    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
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
    BSGPersistentFeatureFlagStore *store = [self openStore];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    const uint64_t before = [self activeValue];
    [store clear];
    const uint64_t after = [self activeValue];
    XCTAssertNotEqual(after & 1, before & 1, @"Clearing all flags should switch slots");
    XCTAssertEqual(after >> 1, 0);
    XCTAssertEqualObjects([self reopenedFlags], @[]);
}

- (void)testRemovalRecordsAreReplayed {
    BSGPersistentFeatureFlagStore *store = [self openStore];
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

- (void)testAddingTheLastFlagAgainDoesNotWrite {
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
    // The same variant on a flag that is not last still moves it to the end
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"b", NSNull.null], @[@"a", @"1"]]));
    // An empty variant is not the same as no variant
    [store addFeatureFlag:@"a" withVariant:@""];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"b", NSNull.null], @[@"a", @""]]));
}

- (void)testFileGrowsOnceTheFlagsTakeUpHalfASlot {
    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    const uint32_t capacity = [self headerFieldAtOffset:SlotCapacityOffset];
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
    BSGPersistentFeatureFlagStore *store = [self openStore];
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
    // Encodable again
    [store addFeatureFlag:@"b" withVariant:@"2"];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"d", NSNull.null], @[@"b", @"2"]]));
}

- (void)testLeadingByteOrderMarksAreKept {
    BSGPersistentFeatureFlagStore *store = [self openStore];
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
    BSGPersistentFeatureFlagStore *store = [self openStore];
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
    [[self openStore] addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:@"old1" variant:@"1"],
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
    [[self openStore] addFeatureFlag:@"previous" withVariant:@"run"];

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
    BSGMemoryFeatureFlagStore *persistentStore = [BSGMemoryFeatureFlagStore new];
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
    BSGCompositeFeatureFlagStore *store = [BSGCompositeFeatureFlagStore storeWithMemoryStore:[BSGMemoryFeatureFlagStore new]
                                                                             persistentStore:[self openStore]
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

    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"d" variant:@"4"]]];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), (@[@[@"d", @"4"]]));
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

#pragma mark Legacy files

- (void)testLegacyFilesAreImportedAndDeleted {
    [self writeLegacyFlag:@"third" variant:nil index:7];
    [self writeLegacyFlag:@"first" variant:@"1" index:0];
    [self writeLegacyFlag:@"second flag/ü" variant:@"" index:3];
    XCTAssertEqual([self jsonFiles].count, 3);

    BSGPersistentFeatureFlagStore *store = [self openStore];
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
    XCTAssertEqualObjects(FlagsToArray([self openStore].allFlags), expected);
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
    XCTAssertEqualObjects(FlagsToArray([self openStore].allFlags), expected);
    XCTAssertEqualObjects([self jsonFiles], @[]);
    XCTAssertEqualObjects([self reopenedFlags], expected);
}

- (void)testFileAndLegacyFilesAreBothDiscardedWhenFoundTogether {
    [[self openStore] addFeatureFlag:@"current" withVariant:@"1"];
    // Only left together when a file could not be deleted; which of them is current is unknown
    [self writeLegacyFlag:@"stale" variant:@"old" index:0];
    [self writeLegacyFlag:@"current" variant:@"old" index:1];
    XCTAssertEqual([self jsonFiles].count, 2);

    BSGPersistentFeatureFlagStore *store = [self openStore];
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
    BSGPersistentFeatureFlagStore *store = [self openStore];
    XCTAssertEqualObjects(store.allFlags, @[]);

    [store addFeatureFlag:@"a" withVariant:@"1"];
    NSData *data = [NSData dataWithContentsOfFile:self.filePath];
    XCTAssertEqualObjects([data subdataWithRange:NSMakeRange(0, 4)], [@"BSFF" dataUsingEncoding:NSASCIIStringEncoding]);
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"]]));
}

- (void)testWrongMagic {
    [[self openStore] addFeatureFlag:@"a" withVariant:@"1"];
    const uint32_t magic = 0x46465341;
    [self replaceFileBytesAtOffset:MagicOffset withBytes:&magic length:sizeof(magic)];
    XCTAssertEqual([self headerFieldAtOffset:VersionOffset], 1);

    BSGPersistentFeatureFlagStore *store = [self openStore];
    XCTAssertEqualObjects(store.allFlags, @[]);
    [self assertFileIsAValidEmptySnapshot];
    [store addFeatureFlag:@"b" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"b", NSNull.null]]));
}

- (void)testUnknownVersion {
    [[self openStore] addFeatureFlag:@"a" withVariant:@"1"];
    const uint32_t version = 2;
    [self replaceFileBytesAtOffset:VersionOffset withBytes:&version length:sizeof(version)];
    XCTAssertEqual([self headerFieldAtOffset:MagicOffset], 0x46465342);

    BSGPersistentFeatureFlagStore *store = [self openStore];
    XCTAssertEqualObjects(store.allFlags, @[]);
    [self assertFileIsAValidEmptySnapshot];
    [store addFeatureFlag:@"b" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"b", NSNull.null]]));
}

- (void)testSlotCapacityTooLargeForTheWriter {
    [[self openStore] addFeatureFlag:@"a" withVariant:@"1"];
    // A capacity the store never writes, in a file large enough to hold it so that only the
    // capacity limit can reject it. The file is sparse, so it does not use much disk space.
    const uint32_t slotCapacity = UINT32_MAX / 4 + 1;
    [self replaceFileBytesAtOffset:SlotCapacityOffset withBytes:&slotCapacity length:sizeof(slotCapacity)];
    XCTAssertEqual(truncate(self.filePath.fileSystemRepresentation, (off_t)(HeaderSize + 2 * (uint64_t)slotCapacity)), 0);

    BSGPersistentFeatureFlagStore *store = [self openStore];
    XCTAssertEqualObjects(store.allFlags, @[]);
    [self assertFileIsAValidEmptySnapshot];
    XCTAssertLessThan([self headerFieldAtOffset:SlotCapacityOffset], slotCapacity);
}

- (void)testHugeSlotCapacities {
    // On 32-bit platforms, a file size calculated in size_t would wrap and pass the size check
    const uint32_t capacities[] = {0x80000000, 0x80000001, 0xFFFFFFF0, UINT32_MAX};
    for (size_t i = 0; i < sizeof(capacities) / sizeof(capacities[0]); i++) {
        [[self openStore] addFeatureFlag:@"a" withVariant:@"1"];
        [self replaceFileBytesAtOffset:SlotCapacityOffset withBytes:&capacities[i] length:sizeof(capacities[i])];

        BSGPersistentFeatureFlagStore *store = [self openStore];
        XCTAssertEqualObjects(store.allFlags, @[]);
        [self assertFileIsAValidEmptySnapshot];
        [store addFeatureFlag:@"b" withVariant:nil];
        XCTAssertEqualObjects([self reopenedFlags], (@[@[@"b", NSNull.null]]));
        [store clear];
    }
}

- (void)testTruncatedFile {
    [[self openStore] addFeatureFlag:@"a" withVariant:@"1"];
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:self.filePath];
    [handle truncateFileAtOffset:HeaderSize + 4];
    [handle closeFile];

    BSGPersistentFeatureFlagStore *store = [self openStore];
    XCTAssertEqualObjects(store.allFlags, @[]);
    [store addFeatureFlag:@"b" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"b", NSNull.null]]));
}

- (void)testTruncatedLargeFile {
    BSGPersistentFeatureFlagStore *original = [self openStore];
    for (NSUInteger i = 0; i < 10000; i++) {
        [original addFeatureFlag:[NSString stringWithFormat:@"flag-%lu", (unsigned long)i] withVariant:@"variant"];
    }
    original = nil;
    const uint32_t slotCapacity = [self headerFieldAtOffset:SlotCapacityOffset];
    XCTAssertGreaterThan(slotCapacity, 4 * (uint32_t)getpagesize());
    // Accessing the slots would touch pages past the end of the file
    XCTAssertEqual(truncate(self.filePath.fileSystemRepresentation, 64), 0);

    BSGPersistentFeatureFlagStore *store = [self openStore];
    XCTAssertEqualObjects(store.allFlags, @[]);
    [self assertFileIsAValidEmptySnapshot];
    [store addFeatureFlag:@"b" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"b", NSNull.null]]));
}

- (void)testEmptyFile {
    [[NSData data] writeToFile:self.filePath atomically:YES];
    BSGPersistentFeatureFlagStore *store = [self openStore];
    XCTAssertEqualObjects(store.allFlags, @[]);
    [store addFeatureFlag:@"b" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"b", NSNull.null]]));
}

- (void)testCorruptEntries {
    BSGPersistentFeatureFlagStore *original = [self openStore];
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

    BSGPersistentFeatureFlagStore *store = [self openStore];
    XCTAssertEqualObjects(store.allFlags, @[], @"A corrupt snapshot should be discarded entirely");

    // New flags must not be appended to the corrupt snapshot
    [store addFeatureFlag:@"c" withVariant:@"3"];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"c", @"3"]]));
}

- (void)testInvalidUTF8 {
    [[self openStore] addFeatureFlag:@"ab" withVariant:nil];
    NSMutableData *data = [NSMutableData dataWithContentsOfFile:self.filePath];
    uint32_t slotCapacity = 0;
    uint64_t active = 0;
    [data getBytes:&slotCapacity range:NSMakeRange(SlotCapacityOffset, sizeof(slotCapacity))];
    [data getBytes:&active range:NSMakeRange(ActiveOffset, sizeof(active))];
    const uint8_t invalid[] = {0xFF, 0xFE};
    [data replaceBytesInRange:NSMakeRange(HeaderSize + (active & 1) * slotCapacity + 8, 2) withBytes:invalid];
    [data writeToFile:self.filePath atomically:NO];

    BSGPersistentFeatureFlagStore *store = [self openStore];
    XCTAssertEqualObjects(store.allFlags, @[]);
    [store addFeatureFlag:@"c" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"c", NSNull.null]]));
}

- (void)testCorruptFileIsRebuiltOnOpen {
    BSGPersistentFeatureFlagStore *original = [self openStore];
    [original addFeatureFlag:@"a" withVariant:@"1"];
    [original addFeatureFlag:@"b" withVariant:@"2"];
    original = nil;
    const uint32_t badLength = 0x7FFFFFF0;
    [self replaceFileBytesAtOffset:[self activeSlotOffset] withBytes:&badLength length:sizeof(badLength)];

    // No changes are made, so the corrupt snapshot must be replaced when the store is opened
    BSGPersistentFeatureFlagStore *store = [self openStore];
    XCTAssertEqualObjects(store.allFlags, @[]);
    [self assertFileIsAValidEmptySnapshot];
}

- (void)testInvalidUTF8InVariant {
    [[self openStore] addFeatureFlag:@"ab" withVariant:@"cd"];
    const uint8_t invalid[] = {0xFF, 0xFE};
    [self replaceFileBytesAtOffset:[self activeSlotOffset] + 8 + 2 withBytes:invalid length:sizeof(invalid)];

    BSGPersistentFeatureFlagStore *store = [self openStore];
    XCTAssertEqualObjects(store.allFlags, @[]);
    [store addFeatureFlag:@"c" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"c", NSNull.null]]));
}

- (void)testActiveLengthExceedsSlotCapacity {
    [[self openStore] addFeatureFlag:@"a" withVariant:@"1"];
    NSMutableData *data = [NSMutableData dataWithContentsOfFile:self.filePath];
    const uint64_t active = (uint64_t)UINT32_MAX << 1;
    [data replaceBytesInRange:NSMakeRange(ActiveOffset, sizeof(active)) withBytes:&active];
    [data writeToFile:self.filePath atomically:NO];

    BSGPersistentFeatureFlagStore *store = [self openStore];
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
    // Writing the file is not retried on every change
    XCTAssertEqual(store.replaceFileCount, 1);

    BOOL isDirectory = NO;
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:self.filePath isDirectory:&isDirectory]);
    XCTAssertTrue(isDirectory);
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:[self.filePath stringByAppendingString:@".tmp"]]);
    XCTAssertEqualObjects([self reopenedFlags], @[]);
}

- (void)testUnusableFileAndLegacyFilesAreBothDiscarded {
    [[self openStore] addFeatureFlag:@"mapped" withVariant:@"1"];
    uint32_t version = 99;
    [self replaceFileBytesAtOffset:VersionOffset withBytes:&version length:sizeof(version)];
    [self writeLegacyFlag:@"legacy" variant:@"1" index:0];
    BSGPersistentFeatureFlagStore *store = [self openStore];
    XCTAssertEqualObjects(store.allFlags, @[]);
    XCTAssertEqualObjects([self jsonFiles], @[]);
    [self assertFileIsAValidEmptySnapshot];
}

- (void)testDirectoryAtFilePathWithLegacyFiles {
    [NSFileManager.defaultManager createDirectoryAtPath:self.filePath withIntermediateDirectories:NO attributes:nil error:nil];
    [self writeLegacyFlag:@"legacy" variant:@"1" index:0];
    BSGPersistentFeatureFlagStore *store = [self openStore];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), (@[@[@"legacy", @"1"]]));
    // The legacy files are deleted even though the flags could not be saved, so that they are not
    // imported again at the next launch when they would be stale
    XCTAssertEqualObjects([self jsonFiles], @[]);
    XCTAssertEqualObjects([self reopenedFlags], @[]);
}

- (void)testGrowthFailureWithAnExistingMapping {
    BSGFailingPersistentFeatureFlagStore *store = [[BSGFailingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    store.retryInterval = 0;
    [store addFeatureFlag:@"a" withVariant:@"1"];
    [store addFeatureFlag:@"b" withVariant:@"2"];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"], @[@"b", @"2"]]));

    store.failReplaceFile = YES;
    NSString *large = [@"" stringByPaddingToLength:4 * (NSUInteger)getpagesize() withString:@"x" startingAtIndex:0];
    [store addFeatureFlag:@"large" withVariant:large];
    // The file must never hold a stale or partial set of flags
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    [store addFeatureFlag:@"c" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    [store clear:@"a"];
    XCTAssertEqualObjects([self reopenedFlags], @[]);

    NSArray *expected = @[@[@"b", @"2"], @[@"large", large], @[@"c", NSNull.null]];
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), expected);

    store.failReplaceFile = NO;
    [store addFeatureFlag:@"d" withVariant:nil];
    expected = @[@[@"b", @"2"], @[@"large", large], @[@"c", NSNull.null], @[@"d", NSNull.null]];
    XCTAssertEqualObjects([self reopenedFlags], expected);
}

- (void)testUnwritableDirectoryAfterMapping {
    BSGSkipIf(geteuid() == 0, @"File permissions are not enforced for root");
    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqual(chmod(self.directory.fileSystemRepresentation, 0500), 0);

    NSString *large = [@"" stringByPaddingToLength:4 * (NSUInteger)getpagesize() withString:@"x" startingAtIndex:0];
    [store addFeatureFlag:@"large" withVariant:large];
    [store addFeatureFlag:@"b" withVariant:nil];
    [store clear:@"a"];
    XCTAssertEqual(store.replaceFileCount, 2, @"Growing the file should not be retried");
    XCTAssertEqualObjects(FlagsToArray(store.allFlags), (@[@[@"large", large], @[@"b", NSNull.null]]));
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:[self.filePath stringByAppendingString:@".tmp"]]);

    XCTAssertEqual(chmod(self.directory.fileSystemRepresentation, 0700), 0);
}

- (void)testWritingIsRetriedAfterTheRetryInterval {
    BSGSkipIf(geteuid() == 0, @"File permissions are not enforced for root");
    BSGCountingPersistentFeatureFlagStore *store = [[BSGCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    XCTAssertEqual(chmod(self.directory.fileSystemRepresentation, 0500), 0);
    NSString *large = [@"" stringByPaddingToLength:4 * (NSUInteger)getpagesize() withString:@"x" startingAtIndex:0];
    [store addFeatureFlag:@"large" withVariant:large];
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    XCTAssertEqual(chmod(self.directory.fileSystemRepresentation, 0700), 0);

    // Within the retry interval the file is not written
    [store addFeatureFlag:@"b" withVariant:nil];
    XCTAssertEqual(store.replaceFileCount, 2);
    XCTAssertEqualObjects([self reopenedFlags], @[]);

    // Once it has passed, the next change writes all of the flags
    store.retryTime = 0;
    [store clear:@"a"];
    [store addFeatureFlag:@"c" withVariant:nil];
    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"large", large], @[@"b", NSNull.null], @[@"c", NSNull.null]]));
}

- (void)testUnreadableFileIsDeletedWhenItCannotBeReplaced {
    BSGSkipIf(geteuid() == 0, @"File permissions are not enforced for root");
    [[self openStore] addFeatureFlag:@"previous-launch" withVariant:@"1"];
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
    XCTAssertEqualObjects([self reopenedFlags], @[], @"The file must not keep stale flags");

    // Within the retry interval the file is not replaced on later changes, even though they would now fit
    store.replacementSnapshot = nil;
    munmap(bytes, length);
    [store addFeatureFlag:@"b" withVariant:nil];
    [store addFeatureFlag:@"large" withVariant:[large stringByAppendingString:@"y"]];
    XCTAssertEqual(store.replaceFileCount, 2);
    XCTAssertEqualObjects([self reopenedFlags], @[]);
    XCTAssertEqual(store.allFlags.count, 3);
}

- (void)testStaleTemporaryFileIsRemovedOnOpen {
    [[self openStore] addFeatureFlag:@"a" withVariant:@"1"];
    NSString *tempPath = [self.filePath stringByAppendingString:@".tmp"];
    XCTAssertTrue([[@"partial" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:tempPath atomically:NO]);

    XCTAssertEqualObjects([self reopenedFlags], (@[@[@"a", @"1"]]));
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:tempPath]);
}

#pragma mark Concurrency

- (void)testConcurrentWriters {
    BSGPersistentFeatureFlagStore *store = [self openStore];
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

- (void)testStoresSharingADirectoryCanGrowTheFileConcurrently {
    // Two clients, or two instances of a macOS app, use the same directory. Each replacement of the file
    // must use its own temporary file, or one store can truncate a file the other has mapped (SIGBUS).
    // The stores share no lock, so the flags left in the file are not defined: this checks that neither
    // store crashes and that no temporary file is left behind.
    BSGPersistentFeatureFlagStore *first = [self openStore];
    BSGPersistentFeatureFlagStore *second = [self openStore];
    dispatch_apply(2, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t index) {
        BSGPersistentFeatureFlagStore *store = index ? second : first;
        for (int round = 1; round <= 12; round++) {
            BSGGrowStore(store, [NSString stringWithFormat:@"store%zu-round%d", index, round], round * 200);
            [store clear];
        }
        BSGGrowStore(store, [NSString stringWithFormat:@"store%zu-final", index], 3000);
    });
    (void)[self reopenedFlags];
    NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.directory error:nil];
    XCTAssertEqualObjects([files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"pathExtension == 'tmp'"]], @[]);
}

- (void)testLeftoverTemporaryFilesAreDeleted {
    NSArray *leftovers = @[@"flags.bin.tmp", @"flags.bin.6F9619FF-8B86-D011-B42D-00CF4FC964FF.tmp"];
    for (NSString *file in [leftovers arrayByAddingObject:@"other.tmp"]) {
        [NSData.data writeToFile:[self.directory stringByAppendingPathComponent:file] atomically:NO];
    }
    [[self openStore] addFeatureFlag:@"a" withVariant:@"1"];
    NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.directory error:nil];
    XCTAssertEqualObjects([files sortedArrayUsingSelector:@selector(compare:)], (@[@"flags.bin", @"other.tmp"]));
}

- (void)testSlotCapacityChangedByAnotherProcessIsIgnored {
    // Offsets come from the size of the mapping, not from the header, which another process could change.
    BSGPersistentFeatureFlagStore *store = [self openStore];
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
    BSGPersistentFeatureFlagStore *store = [self openStore];
    [store addFeatureFlag:@"a" withVariant:@"1"];
    // As if another process using this directory was killed while replacing the file
    [NSData.data writeToFile:[self.filePath stringByAppendingString:@".tmp"] atomically:NO];
    BSGGrowStore(store, @"after", 1000);
    XCTAssertEqual([self reopenedFlags].count, 1001);
}

@end
