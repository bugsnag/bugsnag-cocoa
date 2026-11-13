//
//  BSGPersistentFeatureFlagStoreStressTests.m
//  Bugsnag
//
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//
//  BSGPersistentFeatureFlagStoreStressTests contains long running volume, churn, concurrency,
//  kill-during-write and resource tests. They take too long for every CI run, so CI does not run
//  them: they only run when the environment variable BSG_RUN_STRESS_TESTS is set. Run them by hand
//  before a release (see TESTING.md), on macOS and in an iOS simulator:
//
//  TEST_RUNNER_BSG_RUN_STRESS_TESTS=1 xcodebuild test -project Bugsnag.xcodeproj -scheme Bugsnag-macOS \
//      -destination 'platform=macOS' -only-testing:Bugsnag-macOSTests/BSGPersistentFeatureFlagStoreStressTests
//
//  TEST_RUNNER_BSG_RUN_STRESS_TESTS=1 xcodebuild test -project Bugsnag.xcodeproj -scheme Bugsnag-iOS \
//      -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:Bugsnag-iOSTests/BSGPersistentFeatureFlagStoreStressTests
//
//  Run the file protection tests in BSGUtilsTests and BSGRunContextTests at the same time, with the
//  screen unlocked, so that they fail rather than skip if NSFileProtectionComplete cannot be set:
//
//  TEST_RUNNER_BSG_REQUIRE_FILE_PROTECTION_TESTS=1 xcodebuild test -project Bugsnag.xcodeproj -scheme Bugsnag-iOS \
//      -destination 'platform=iOS Simulator,name=iPhone 17' \
//      -only-testing:Bugsnag-iOSTests/BSGUtilsTests -only-testing:Bugsnag-iOSTests/BSGRunContextTests
//
//  BSGPersistentFeatureFlagStoreFileDescriptorTests contains quick checks that always run.
//

#import "BSGTestCase.h"

#import "BSGPersistentFeatureFlagStore.h"
#import "BugsnagFeatureFlag.h"

#import <fcntl.h>
#import <limits.h>
#import <stdlib.h>
#import <sys/param.h>
#import <signal.h>
#import <spawn.h>
#import <stdatomic.h>
#import <sys/wait.h>
#import <unistd.h>

// Layout of the file header; see BSGFeatureFlagFileFormat.h
static const size_t StressHeaderSize = 32;
static const size_t StressSlotCapacityOffset = 8;

#pragma mark - Instrumented store

@interface BSGPersistentFeatureFlagStore (StressPrivate)
- (BOOL)replaceFileWithSnapshot:(NSData *)snapshot;
@end

/// Counts how many times the file is replaced (i.e. grown or created).
@interface BSGStressCountingPersistentFeatureFlagStore : BSGPersistentFeatureFlagStore
@property (nonatomic) NSUInteger replaceFileCount;
@end

@implementation BSGStressCountingPersistentFeatureFlagStore

- (BOOL)replaceFileWithSnapshot:(NSData *)snapshot {
    self.replaceFileCount++;
    return [super replaceFileWithSnapshot:snapshot];
}

@end

#pragma mark - Reference model

/// A minimal model of the expected store behaviour, which matches BSGMemoryFeatureFlagStore: adding a
/// name that is already present replaces its variant and keeps its position, and a cleared name that is
/// added again goes at the end.
@interface BSGFeatureFlagModel : NSObject
@property (nonatomic, strong) NSMutableOrderedSet<NSString *> *names;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *variants;
@end

@implementation BSGFeatureFlagModel

- (instancetype)init {
    if ((self = [super init])) {
        _names = [NSMutableOrderedSet orderedSet];
        _variants = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)add:(NSString *)name variant:(NSString *)variant {
    if (![self.names containsObject:name]) {
        [self.names addObject:name];
    }
    self.variants[name] = variant ?: NSNull.null;
}

- (void)clear:(NSString *)name {
    [self.names removeObject:name];
    [self.variants removeObjectForKey:name];
}

- (void)clearAll {
    [self.names removeAllObjects];
    [self.variants removeAllObjects];
}

- (NSArray *)array {
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:self.names.count];
    for (NSString *name in self.names) {
        [result addObject:@[name, self.variants[name]]];
    }
    return result;
}

@end

#pragma mark - Helpers

static NSArray * StressFlagsToArray(NSArray<BugsnagFeatureFlag *> *flags) {
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:flags.count];
    for (BugsnagFeatureFlag *flag in flags) {
        [result addObject:@[flag.name, flag.variant ?: NSNull.null]];
    }
    return result;
}

/// The number of file descriptors open in this process that refer to a file in `directory`
/// (e.g. featureflag.bin, featureflag.lock, or a temporary file). Descriptors opened by anything else in the
/// process are ignored, so the count is not affected by other work going on in the test process.
static NSUInteger FileDescriptorCountInDirectory(NSString *directory) {
    char resolved[PATH_MAX];
    if (!realpath(directory.fileSystemRepresentation, resolved)) {
        return 0;
    }
    // F_GETPATH returns the resolved path (e.g. /private/var/... rather than /var/...)
    NSString *prefix = [@(resolved) stringByAppendingString:@"/"];
    NSUInteger count = 0;
    const int max = getdtablesize();
    for (int fd = 0; fd < max; fd++) {
        char path[MAXPATHLEN];
        if (fcntl(fd, F_GETPATH, path) != -1 && [@(path) hasPrefix:prefix]) {
            count++;
        }
    }
    return count;
}

static double MillisecondsSince(CFAbsoluteTime start) {
    return (CFAbsoluteTimeGetCurrent() - start) * 1000.0;
}

/// Decodes featureflag.bin independently of BSGPersistentFeatureFlagStore, replaying the log in the active
/// slot (see the format description in BSGFeatureFlagFileFormat.h). Returns nil if the file is
/// missing or corrupt, otherwise an array of [name, variant or NSNull].
static NSArray * DecodeFlagsFile(NSString *path) {
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data.length < StressHeaderSize) {
        return nil;
    }
    const uint8_t *bytes = data.bytes;
    uint32_t magic, version, capacity;
    uint64_t active;
    memcpy(&magic, bytes, sizeof(magic));
    memcpy(&version, bytes + 4, sizeof(version));
    memcpy(&capacity, bytes + StressSlotCapacityOffset, sizeof(capacity));
    memcpy(&active, bytes + 16, sizeof(active));
    const uint64_t length = active >> 1;
    if (magic != 0x46465342 || version != 1 || capacity == 0 ||
        data.length < StressHeaderSize + 2 * (uint64_t)capacity || length > capacity) {
        return nil;
    }
    const uint8_t *log = bytes + StressHeaderSize + (active & 1) * (uint64_t)capacity;
    NSMutableOrderedSet<NSString *> *names = [NSMutableOrderedSet orderedSet];
    NSMutableDictionary<NSString *, id> *variants = [NSMutableDictionary dictionary];
    for (uint64_t offset = 0; offset < length;) {
        uint32_t lengths[2];
        if (length - offset < sizeof(lengths)) {
            return nil;
        }
        memcpy(lengths, log + offset, sizeof(lengths));
        offset += sizeof(lengths);
        const BOOL removed = lengths[1] == UINT32_MAX - 1;
        const BOOL hasVariant = lengths[1] != UINT32_MAX && !removed;
        const uint32_t variantLength = hasVariant ? lengths[1] : 0;
        if (lengths[0] > length - offset || variantLength > length - offset - lengths[0]) {
            return nil;
        }
        NSString *name = [[NSString alloc] initWithBytes:log + offset length:lengths[0] encoding:NSUTF8StringEncoding];
        offset += lengths[0];
        NSString *variant = hasVariant ? [[NSString alloc] initWithBytes:log + offset length:variantLength
                                                                encoding:NSUTF8StringEncoding] : nil;
        offset += variantLength;
        if (!name || (hasVariant && !variant)) {
            return nil;
        }
        // As in the store, a record for a name that is present keeps its position, and a removed name
        // that is added again goes at the end
        if (removed) {
            [names removeObject:name];
            [variants removeObjectForKey:name];
        } else {
            if (![names containsObject:name]) {
                [names addObject:name];
            }
            variants[name] = variant ?: NSNull.null;
        }
    }
    NSMutableArray *flags = [NSMutableArray array];
    for (NSString *name in names) {
        [flags addObject:@[name, variants[name]]];
    }
    return flags;
}

#if TARGET_OS_OSX
static NSString * const KillTestDirectoryKey = @"BSG_FEATURE_FLAG_KILL_TEST_DIRECTORY";
#endif

#pragma mark - Shared setup

/// Provides a temporary storage directory and helpers. Contains no tests itself.
@interface BSGPersistentFeatureFlagStoreStressTestCase : BSGTestCase

@property (nonatomic) NSString *directory;

@end

@implementation BSGPersistentFeatureFlagStoreStressTestCase

- (void)setUp {
    [super setUp];
    self.directory = [NSTemporaryDirectory() stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"BSGPersistentFeatureFlagStoreStressTests-%@", NSUUID.UUID.UUIDString]];
    [NSFileManager.defaultManager createDirectoryAtPath:self.directory withIntermediateDirectories:YES attributes:nil error:nil];
}

- (void)tearDown {
    [NSFileManager.defaultManager removeItemAtPath:self.directory error:nil];
    [super tearDown];
}

- (NSString *)filePath {
    return [self.directory stringByAppendingPathComponent:@"featureflag.bin"];
}

// Named new... so that ARC returns the store retained rather than autoreleased, and it is released (giving
// up the lock on featureflag.lock if it took it) as soon as the caller no longer uses it.
- (BSGPersistentFeatureFlagStore *)newStore {
    return [[BSGPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
}

/// The flags a new store reads from the directory. The store is released before this returns.
- (NSArray *)reopenedFlags {
    @autoreleasepool {
        BSGPersistentFeatureFlagStore *store = [self newStore];
        return StressFlagsToArray(store.allFlags);
    }
}

- (unsigned long long)fileSize {
    return [[NSFileManager.defaultManager attributesOfItemAtPath:self.filePath error:nil] fileSize];
}

- (uint32_t)slotCapacity {
    NSData *data = [NSData dataWithContentsOfFile:self.filePath];
    uint32_t slotCapacity = 0;
    if (data.length >= StressHeaderSize) {
        [data getBytes:&slotCapacity range:NSMakeRange(StressSlotCapacityOffset, sizeof(slotCapacity))];
    }
    return slotCapacity;
}

- (NSUInteger)openFileDescriptorCount {
    return FileDescriptorCountInDirectory(self.directory);
}

@end

#pragma mark - File descriptor checks (always run)

/// Quick checks, run on every CI run, that opening, using and closing stores does not leak
/// descriptors for files in the featureFlags directory. A store that has saved flags keeps two
/// descriptors open for its lifetime, for featureflag.bin and featureflag.lock, and closes both when it
/// is deallocated.
@interface BSGPersistentFeatureFlagStoreFileDescriptorTests : BSGPersistentFeatureFlagStoreStressTestCase
@end

@implementation BSGPersistentFeatureFlagStoreFileDescriptorTests

- (void)testOpenCloseCyclesDoNotLeakFileDescriptors {
    @autoreleasepool {
        BSGPersistentFeatureFlagStore *store = [self newStore];
        [store addFeatureFlag:@"a" withVariant:@"1"];
        [store addFeatureFlag:@"b" withVariant:nil];
    }
    // Every store has been closed, so this is the baseline for the directory
    const NSUInteger closedBaseline = self.openFileDescriptorCount;

    // Check that descriptors for files in the directory are actually counted, using featureflag.bin itself
    const int fd = open(self.filePath.fileSystemRepresentation, O_RDONLY);
    XCTAssertNotEqual(fd, -1);
    XCTAssertEqual(self.openFileDescriptorCount, closedBaseline + 1);
    close(fd);

    for (NSUInteger i = 0; i < 20; i++) {
        @autoreleasepool {
            BSGPersistentFeatureFlagStore *store = [self newStore];
            XCTAssertEqual(store.allFlags.count, 2);
            // Exercise the append, snapshot and growth paths before closing
            NSString *name = [NSString stringWithFormat:@"extra-%lu", (unsigned long)i];
            [store addFeatureFlag:name withVariant:nil];
            [store addFeatureFlag:@"a" withVariant:name];
            [store clear:name];
            // featureflag.bin and featureflag.lock
            XCTAssertEqual(self.openFileDescriptorCount, closedBaseline + 2,
                           @"Cycle %lu: an open store's descriptor count changed", (unsigned long)i);
        }
        XCTAssertEqual(self.openFileDescriptorCount, closedBaseline, @"Cycle %lu: descriptors leaked", (unsigned long)i);
    }
}

- (void)testStoreGrowthDoesNotLeakFileDescriptors {
    const NSUInteger before = self.openFileDescriptorCount;
    @autoreleasepool {
        BSGStressCountingPersistentFeatureFlagStore *store =
        [[BSGStressCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
        [store addFeatureFlag:@"first" withVariant:nil];
        // featureflag.bin and featureflag.lock
        const NSUInteger open = self.openFileDescriptorCount;
        XCTAssertEqual(open, before + 2);
        for (NSUInteger i = 0; i < 5000; i++) {
            [store addFeatureFlag:[NSString stringWithFormat:@"fd-%lu", (unsigned long)i]
                      withVariant:@"a-reasonably-long-variant-to-force-several-growth-steps"];
        }
        XCTAssertGreaterThan(store.replaceFileCount, 3);
        XCTAssertEqual(self.openFileDescriptorCount, open, @"Growing the file leaked descriptors");
    }
    XCTAssertEqual(self.openFileDescriptorCount, before, @"Closing the store leaked descriptors");
}

@end

#pragma mark - Stress tests (only run when BSG_RUN_STRESS_TESTS is set)

@interface BSGPersistentFeatureFlagStoreStressTests : BSGPersistentFeatureFlagStoreStressTestCase
@end

@implementation BSGPersistentFeatureFlagStoreStressTests

+ (XCTestSuite *)defaultTestSuite {
    // An empty suite rather than a skip in every test, so that a normal run does not list dozens of skipped tests
    if (!NSProcessInfo.processInfo.environment[@"BSG_RUN_STRESS_TESTS"]) {
        return [XCTestSuite testSuiteWithName:NSStringFromClass(self)];
    }
    return [super defaultTestSuite];
}

#pragma mark Volume

- (void)test40000FlagsBatchAddAndReopen {
    // About 1.2 MB of records, which is below the 2 MB that a slot can hold
    const NSUInteger count = 40000;
    NSMutableArray<BugsnagFeatureFlag *> *flags = [NSMutableArray arrayWithCapacity:count];
    BSGFeatureFlagModel *model = [BSGFeatureFlagModel new];
    for (NSUInteger i = 0; i < count; i++) {
        NSString *name = [NSString stringWithFormat:@"bulk-flag-%lu", (unsigned long)i];
        NSString *variant = i % 4 == 0 ? nil : (i % 4 == 1 ? @"" : [NSString stringWithFormat:@"variant-%lu", (unsigned long)i]);
        [flags addObject:[BugsnagFeatureFlag flagWithName:name variant:variant]];
        [model add:name variant:variant];
    }

    BSGPersistentFeatureFlagStore *store = [self newStore];
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    [store addFeatureFlags:flags];
    const double addMs = MillisecondsSince(start);

    start = CFAbsoluteTimeGetCurrent();
    NSArray *reopened = [self reopenedFlags];
    const double reopenMs = MillisecondsSince(start);
    NSLog(@"[STRESS] 40k batch add: add=%.1f ms, reopen=%.1f ms, file=%llu bytes, slotCapacity=%u",
          addMs, reopenMs, [self fileSize], [self slotCapacity]);
    XCTAssertEqual(reopened.count, count);
    XCTAssertEqualObjects(reopened, model.array);

    // An overwrite rewrites the whole snapshot into the other slot
    start = CFAbsoluteTimeGetCurrent();
    [store addFeatureFlag:@"bulk-flag-0" withVariant:@"overwritten"];
    [model add:@"bulk-flag-0" variant:@"overwritten"];
    const double overwriteMs = MillisecondsSince(start);

    // A new flag is appended
    start = CFAbsoluteTimeGetCurrent();
    [store addFeatureFlag:@"after-bulk" withVariant:nil];
    [model add:@"after-bulk" variant:nil];
    const double appendMs = MillisecondsSince(start);
    NSLog(@"[STRESS] 40k overwrite one=%.2f ms, append one=%.3f ms", overwriteMs, appendMs);

    XCTAssertEqualObjects(StressFlagsToArray(store.allFlags), model.array);
    XCTAssertEqualObjects([self reopenedFlags], model.array);

    // A 1 MB variant takes the flags over the 2 MB a slot can hold: they stay in memory, but the log in the
    // file is emptied rather than left holding flags that are no longer current
    NSString *large = [@"" stringByPaddingToLength:1024 * 1024 withString:@"0123456789abcdef" startingAtIndex:0];
    [store addFeatureFlag:@"over-the-cap" withVariant:large];
    [model add:@"over-the-cap" variant:large];
    XCTAssertEqualObjects(StressFlagsToArray(store.allFlags), model.array);
    XCTAssertEqualObjects([self reopenedFlags], @[], @"Flags over the size limit must not be persisted");
    XCTAssertLessThanOrEqual([self slotCapacity], 2u * 1024 * 1024);

    // Once they are small enough again, the next change saves all of them
    [store clear:@"over-the-cap"];
    [model clear:@"over-the-cap"];
    XCTAssertEqualObjects(StressFlagsToArray(store.allFlags), model.array);
    XCTAssertEqualObjects([self reopenedFlags], model.array);
}

- (void)testIncrementalGrowthTo20000Flags {
    const NSUInteger count = 20000;
    BSGStressCountingPersistentFeatureFlagStore *store =
    [[BSGStressCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    BSGFeatureFlagModel *model = [BSGFeatureFlagModel new];
    const unsigned long long initialSize = [self fileSize];

    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    for (NSUInteger i = 0; i < count; i++) {
        NSString *name = [NSString stringWithFormat:@"grow-%lu", (unsigned long)i];
        NSString *variant = i % 2 ? [NSString stringWithFormat:@"v%lu", (unsigned long)i] : nil;
        [store addFeatureFlag:name withVariant:variant];
        [model add:name variant:variant];
    }
    const double addMs = MillisecondsSince(start);
    NSLog(@"[STRESS] growth to %lu one at a time: total=%.1f ms (%.2f us/flag), file %llu -> %llu bytes, file replaced %lu times",
          (unsigned long)count, addMs, addMs * 1000.0 / count, initialSize, [self fileSize],
          (unsigned long)store.replaceFileCount);

    // The capacity doubles when the file grows, so it is only replaced a logarithmic number of times
    XCTAssertLessThanOrEqual(store.replaceFileCount, 15);
    XCTAssertGreaterThan(store.replaceFileCount, 1);
    XCTAssertEqualObjects(StressFlagsToArray(store.allFlags), model.array);
    XCTAssertEqualObjects([self reopenedFlags], model.array);
}

- (void)testOneMegabyteVariant {
    NSString *large = [@"" stringByPaddingToLength:1024 * 1024 withString:@"0123456789abcdef" startingAtIndex:0];
    NSString *largeUnicode = [@"" stringByPaddingToLength:256 * 1024 withString:@"é🚩" startingAtIndex:0];
    BSGPersistentFeatureFlagStore *store = [self newStore];
    BSGFeatureFlagModel *model = [BSGFeatureFlagModel new];

    [store addFeatureFlag:@"small" withVariant:@"1"];
    [model add:@"small" variant:@"1"];
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    [store addFeatureFlag:@"large" withVariant:large];
    [model add:@"large" variant:large];
    const double addMs = MillisecondsSince(start);
    const unsigned long long sizeAfterLarge = [self fileSize];
    XCTAssertGreaterThan(sizeAfterLarge, 2ull * 1024 * 1024, @"Both slots must be able to hold the 1 MB entry");

    [store addFeatureFlag:@"unicode-large" withVariant:largeUnicode];
    [model add:@"unicode-large" variant:largeUnicode];
    [store addFeatureFlag:@"small" withVariant:nil]; // snapshot rewrite including the large entries
    [model add:@"small" variant:nil];

    start = CFAbsoluteTimeGetCurrent();
    NSArray *reopened = [self reopenedFlags];
    const double reopenMs = MillisecondsSince(start);
    NSLog(@"[STRESS] 1 MB variant: add=%.1f ms, reopen=%.1f ms, file=%llu bytes, slotCapacity=%u",
          addMs, reopenMs, [self fileSize], [self slotCapacity]);
    XCTAssertEqualObjects(reopened, model.array);

    [store clear:@"large"];
    [model clear:@"large"];
    XCTAssertEqualObjects([self reopenedFlags], model.array);
}

#pragma mark Churn

- (void)testAlternatingClearAndRefillKeepsFileSizeBounded {
    const NSUInteger cycles = 1000;
    const NSUInteger flagsPerCycle = 100;
    BSGStressCountingPersistentFeatureFlagStore *store =
    [[BSGStressCountingPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
    unsigned long long sizeAfterFirstCycle = 0, maxSize = 0;
    NSUInteger replacementsAfterFirstCycle = 0;
    NSMutableString *sizes = [NSMutableString string];

    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    for (NSUInteger cycle = 0; cycle < cycles; cycle++) {
        [store clear];
        for (NSUInteger i = 0; i < flagsPerCycle; i++) {
            NSString *name = [NSString stringWithFormat:@"cycle-flag-%lu", (unsigned long)i];
            [store addFeatureFlag:name withVariant:[NSString stringWithFormat:@"c%lu", (unsigned long)cycle]];
        }
        const unsigned long long size = [self fileSize];
        maxSize = MAX(maxSize, size);
        if (cycle == 0) {
            sizeAfterFirstCycle = size;
            replacementsAfterFirstCycle = store.replaceFileCount;
        }
        if (cycle == 0 || cycle == 9 || cycle == 99 || cycle == cycles - 1) {
            [sizes appendFormat:@" after %lu cycles=%llu", (unsigned long)cycle + 1, size];
        }
    }
    const double totalMs = MillisecondsSince(start);
    NSLog(@"[STRESS] clear-all + refill(%lu) x %lu: total=%.1f ms, file sizes:%@, max=%llu, file replaced %lu times",
          (unsigned long)flagsPerCycle, (unsigned long)cycles, totalMs, sizes, maxSize, (unsigned long)store.replaceFileCount);

    XCTAssertEqual(maxSize, sizeAfterFirstCycle, @"Repeated clear and refill must not grow the file");
    // With 4 KB pages the first cycle also grows the file once
    XCTAssertEqual(store.replaceFileCount, replacementsAfterFirstCycle, @"Later cycles should not replace the file");
    NSArray *reopened = [self reopenedFlags];
    XCTAssertEqual(reopened.count, flagsPerCycle);
    XCTAssertEqualObjects(reopened.lastObject, (@[@"cycle-flag-99", @"c999"]));
}

- (void)testRandomisedOperationsMatchModel {
    // Single threaded model check: after every operation the file must decode to exactly the model,
    // which is what an OOM-killed process would leave behind.
    srand48(20260101);
    BSGPersistentFeatureFlagStore *store = [self newStore];
    BSGFeatureFlagModel *model = [BSGFeatureFlagModel new];
    for (NSUInteger op = 0; op < 3000; op++) {
        NSString *name = [NSString stringWithFormat:@"m-%ld", lrand48() % 200];
        const long variantKind = lrand48() % 3;
        NSString *variant = variantKind == 0 ? nil : (variantKind == 1 ? @"" : [NSString stringWithFormat:@"v%lu", (unsigned long)op]);
        const long kind = lrand48() % 100;
        if (kind < 50) {
            [store addFeatureFlag:name withVariant:variant];
            [model add:name variant:variant];
        } else if (kind < 65) {
            NSString *other = [NSString stringWithFormat:@"m-%ld", lrand48() % 200];
            [store addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:name variant:variant],
                                     [BugsnagFeatureFlag flagWithName:other variant:nil]]];
            [model add:name variant:variant];
            [model add:other variant:nil];
        } else if (kind < 90) {
            [store clear:name];
            [model clear:name];
        } else if (kind < 93) {
            [store clear];
            [model clearAll];
        } else {
            NSMutableArray *flags = [NSMutableArray array];
            [model clearAll];
            for (long i = 0, n = lrand48() % 30; i < n; i++) {
                NSString *replacement = [NSString stringWithFormat:@"m-%ld", lrand48() % 200];
                [flags addObject:[BugsnagFeatureFlag flagWithName:replacement variant:@"r"]];
                [model add:replacement variant:@"r"];
            }
            [store replaceAllFlags:flags];
        }
        if (op % 25 == 0) {
            XCTAssertEqualObjects([self reopenedFlags], model.array, @"Mismatch after operation %lu", (unsigned long)op);
        }
    }
    XCTAssertEqualObjects(StressFlagsToArray(store.allFlags), model.array);
    XCTAssertEqualObjects([self reopenedFlags], model.array);
}

#pragma mark Concurrency

- (void)testEightThreadsMixedOperations {
    BSGPersistentFeatureFlagStore *store = [self newStore];
    const NSTimeInterval duration = 4;
    const CFAbsoluteTime deadline = CFAbsoluteTimeGetCurrent() + duration;
    __block _Atomic(uint64_t) operations = 0;
    __block _Atomic(int) inconsistencies = 0;

    dispatch_apply(8, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t thread) {
        uint64_t count = 0;
        while (CFAbsoluteTimeGetCurrent() < deadline) {
            @autoreleasepool {
                NSString *name = [NSString stringWithFormat:@"t-%u", arc4random_uniform(1000)];
                NSString *variant = [NSString stringWithFormat:@"%zu-%llu", thread, count];
                const uint32_t kind = arc4random_uniform(1000);
                if (kind < 400) {
                    [store addFeatureFlag:name withVariant:kind % 5 ? variant : nil];
                } else if (kind < 550) {
                    [store addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:name variant:variant],
                                             [BugsnagFeatureFlag flagWithName:[name stringByAppendingString:@"-b"] variant:@""]]];
                } else if (kind < 750) {
                    [store clear:name];
                } else if (kind < 755) {
                    [store clear];
                } else if (kind < 765) {
                    NSMutableArray *flags = [NSMutableArray array];
                    for (uint32_t i = 0; i < 100; i++) {
                        [flags addObject:[BugsnagFeatureFlag flagWithName:[NSString stringWithFormat:@"t-%u", arc4random_uniform(1000)]
                                                                  variant:variant]];
                    }
                    [store replaceAllFlags:flags];
                } else {
                    NSArray<BugsnagFeatureFlag *> *flags = store.allFlags;
                    NSMutableSet *seen = [NSMutableSet setWithCapacity:flags.count];
                    for (BugsnagFeatureFlag *flag in flags) {
                        if ([seen containsObject:flag.name]) {
                            atomic_fetch_add(&inconsistencies, 1);
                        }
                        [seen addObject:flag.name];
                    }
                }
                count++;
            }
        }
        atomic_fetch_add(&operations, count);
    });

    const uint64_t totalOperations = atomic_load(&operations);
    const int duplicateNames = atomic_load(&inconsistencies);
    NSArray *expected = StressFlagsToArray(store.allFlags);
    const CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    NSArray *reopened = [self reopenedFlags];
    NSLog(@"[STRESS] 8 threads x %.0f s: %llu operations (%.0f ops/s), final flags=%lu, reopen=%.1f ms, file=%llu bytes",
          duration, (unsigned long long)totalOperations, totalOperations / duration, (unsigned long)expected.count,
          MillisecondsSince(start), [self fileSize]);
    XCTAssertEqual(duplicateNames, 0, @"allFlags returned duplicate names");
    XCTAssertGreaterThan(totalOperations, 1000ull);
    XCTAssertEqual(store.isEmpty, expected.count == 0);
    XCTAssertEqualObjects(reopened, expected);
}

#pragma mark Kill during writes

#if TARGET_OS_OSX

/// Run by testFileIsConsistentAfterBeingKilledDuringWrites in a separate xctest process, which it kills.
/// Does nothing when run as part of the normal test run.
- (void)testChildProcessChangesFlagsUntilKilled {
    NSString *directory = NSProcessInfo.processInfo.environment[KillTestDirectoryKey];
    if (!directory) {
        return;
    }
    BSGPersistentFeatureFlagStore *store = [[BSGPersistentFeatureFlagStore alloc] initWithStorageDirectory:directory];
    srand48(getpid());
    NSString *padding = [@"" stringByPaddingToLength:2000 withString:@"p" startingAtIndex:0];
    // Every variant starts with its flag's name, so a record mixed up with another is detected
    for (uint64_t counter = 0;; counter++) {
        NSString *name = [NSString stringWithFormat:@"k-%ld", lrand48() % 500];
        NSString *variant = [NSString stringWithFormat:@"%@:%llu", name, counter];
        const long kind = lrand48() % 1000;
        if (kind < 600) {
            [store addFeatureFlag:name withVariant:variant];
        } else if (kind < 800) {
            [store clear:name];
        } else if (kind < 990) {
            // Large batches make the file grow, and clearing all flags makes it shrink again
            NSMutableArray *flags = [NSMutableArray array];
            for (long i = 0, n = lrand48() % 200; i < n; i++) {
                NSString *batchName = [NSString stringWithFormat:@"k-%ld", lrand48() % 5000];
                [flags addObject:[BugsnagFeatureFlag flagWithName:batchName
                                                          variant:[NSString stringWithFormat:@"%@:%llu:%@", batchName, counter, padding]]];
            }
            [store addFeatureFlags:flags];
        } else if (kind < 998) {
            [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:name variant:variant]]];
        } else {
            [store clear];
        }
    }
}

- (void)testFileIsConsistentAfterBeingKilledDuringWrites {
    NSString *xctest = NSProcessInfo.processInfo.arguments.firstObject;
    NSString *bundlePath = [NSBundle bundleForClass:[self class]].bundlePath;
    XCTSkipIf(![xctest.lastPathComponent isEqualToString:@"xctest"],
              @"The child process needs the tests to run in xctest, not %@", xctest);
    XCTSkipIf(NSProcessInfo.processInfo.environment[@"DYLD_INSERT_LIBRARIES"] != nil,
              @"The child process cannot load a test bundle built with a sanitizer");
    NSString *testName = [NSString stringWithFormat:@"%@/testChildProcessChangesFlagsUntilKilled", NSStringFromClass([self class])];
    srand48(20261030);
    NSUInteger flagsSeen = 0;
    for (int round = 0; round < 8; round++) {
        NSString *directory = [self.directory stringByAppendingPathComponent:[NSString stringWithFormat:@"round-%d", round]];
        [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *filePath = [directory stringByAppendingPathComponent:@"featureflag.bin"];

        NSMutableArray<NSString *> *environment = [NSMutableArray array];
        [NSProcessInfo.processInfo.environment enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
            // Without these the child would join Xcode's test session instead of running the one test
            if (![key hasPrefix:@"XCTest"] && ![key hasPrefix:@"XPC_"] && ![key hasPrefix:@"XCInject"]) {
                [environment addObject:[NSString stringWithFormat:@"%@=%@", key, value]];
            }
        }];
        [environment addObject:[NSString stringWithFormat:@"%@=%@", KillTestDirectoryKey, directory]];
        NSArray<NSString *> *arguments = @[xctest, @"-XCTest", testName, bundlePath];
        char *argv[5] = {0}, **envp = calloc(environment.count + 1, sizeof(char *));
        for (NSUInteger i = 0; i < arguments.count; i++) {
            argv[i] = (char *)arguments[i].UTF8String;
        }
        for (NSUInteger i = 0; i < environment.count; i++) {
            envp[i] = (char *)environment[i].UTF8String;
        }
        NSString *logPath = [directory stringByAppendingPathComponent:@"child.log"];
        posix_spawn_file_actions_t actions;
        posix_spawn_file_actions_init(&actions);
        posix_spawn_file_actions_addopen(&actions, STDOUT_FILENO, logPath.fileSystemRepresentation, O_WRONLY | O_CREAT | O_TRUNC, 0600);
        posix_spawn_file_actions_adddup2(&actions, STDOUT_FILENO, STDERR_FILENO);
        pid_t pid = 0;
        const int spawned = posix_spawn(&pid, xctest.fileSystemRepresentation, &actions, NULL, argv, envp);
        posix_spawn_file_actions_destroy(&actions);
        free(envp);
        XCTAssertEqual(spawned, 0);
        if (spawned != 0) {
            return;
        }

        // Wait for the child to start writing, then kill it at a random point
        for (int i = 0; i < 600 && access(filePath.fileSystemRepresentation, F_OK) != 0; i++) {
            usleep(50000);
        }
        if (access(filePath.fileSystemRepresentation, F_OK) != 0) {
            kill(pid, SIGKILL);
            waitpid(pid, NULL, 0);
            XCTFail(@"The child process did not start writing: %@",
                    [NSString stringWithContentsOfFile:logPath encoding:NSUTF8StringEncoding error:nil]);
            return;
        }
        usleep((useconds_t)(50000 + lrand48() % 400000));
        kill(pid, SIGKILL);
        int status = 0;
        waitpid(pid, &status, 0);
        XCTAssertTrue(WIFSIGNALED(status) && WTERMSIG(status) == SIGKILL, @"Round %d: the child stopped before it was killed", round);

        NSArray *flags = DecodeFlagsFile(filePath);
        XCTAssertNotNil(flags, @"Round %d: the file is corrupt after the process was killed", round);
        NSMutableSet *names = [NSMutableSet set];
        for (NSArray *flag in flags) {
            XCTAssertFalse([names containsObject:flag[0]], @"Round %d: %@ appears twice", round, flag[0]);
            [names addObject:flag[0]];
            XCTAssertTrue([flag[1] isKindOfClass:[NSString class]] &&
                          [flag[1] hasPrefix:[flag[0] stringByAppendingString:@":"]],
                          @"Round %d: %@ has the variant %@", round, flag[0], flag[1]);
        }
        // The store reads the same flags
        BSGPersistentFeatureFlagStore *store = [[BSGPersistentFeatureFlagStore alloc] initWithStorageDirectory:directory];
        XCTAssertEqualObjects(StressFlagsToArray(store.allFlags), flags, @"Round %d", round);
        flagsSeen += flags.count;
    }
    NSLog(@"[STRESS] kill during writes: 8 rounds, %lu flags checked", (unsigned long)flagsSeen);
}

#endif

#pragma mark Resource leaks

- (void)testManyStoreInstancesDoNotLeakFileDescriptors {
    NSString *large = [@"" stringByPaddingToLength:1024 * 1024 withString:@"x" startingAtIndex:0];
    @autoreleasepool {
        BSGPersistentFeatureFlagStore *store = [self newStore];
        [store addFeatureFlag:@"large" withVariant:large];
        [store addFeatureFlag:@"small" withVariant:nil];
    }
    const unsigned long long fileSize = [self fileSize];

    // One more open/close cycle first, so that anything opened once per process is not counted
    @autoreleasepool {
        XCTAssertEqual([self newStore].allFlags.count, 2);
    }
    const NSUInteger fdsBefore = self.openFileDescriptorCount;
    const NSUInteger iterations = 500;
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    for (NSUInteger i = 0; i < iterations; i++) {
        @autoreleasepool {
            BSGPersistentFeatureFlagStore *store = [self newStore];
            XCTAssertEqual(store.allFlags.count, 2);
            if (i % 50 == 0) {
                // Also exercise the write paths (append, snapshot, growth) before closing
                [store addFeatureFlag:[NSString stringWithFormat:@"extra-%lu", (unsigned long)i] withVariant:nil];
                [store clear:[NSString stringWithFormat:@"extra-%lu", (unsigned long)i]];
            }
        }
    }
    const double totalMs = MillisecondsSince(start);
    const NSUInteger fdsAfter = self.openFileDescriptorCount;
    NSLog(@"[STRESS] %lu open/close cycles of a %llu byte file: total=%.1f ms (%.2f ms each), open fds in the directory %lu -> %lu",
          (unsigned long)iterations, fileSize, totalMs, totalMs / iterations, (unsigned long)fdsBefore, (unsigned long)fdsAfter);

    XCTAssertEqual(fdsAfter, fdsBefore, @"File descriptors leaked");
    NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.filePath.stringByDeletingLastPathComponent error:nil];
    XCTAssertEqualObjects([files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"pathExtension == 'tmp'"]], @[]);
}

@end
