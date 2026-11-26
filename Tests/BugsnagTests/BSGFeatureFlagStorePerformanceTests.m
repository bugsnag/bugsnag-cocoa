//
//  BSGFeatureFlagStorePerformanceTests.m
//  Bugsnag
//
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//
//  Benchmarks BSGLegacyJSONFeatureFlagStore (one JSON file per flag) against BSGPersistentFeatureFlagStore (one
//  binary file), each workload in a fresh directory. XCTest allows one measure block per test, so each benchmark has
//  a "JSON" and a "Binary" test. testPrintComparisonTable logs p50 / p95 timings as a markdown table.
//
//  Too slow for CI, they run only when BSG_RUN_PERFORMANCE_TESTS is set. Run them before a release (see TESTING.md):
//
//  TEST_RUNNER_BSG_RUN_PERFORMANCE_TESTS=1 xcodebuild test -project Bugsnag.xcodeproj -scheme Bugsnag-macOS \
//      -destination 'platform=macOS' -only-testing:Bugsnag-macOSTests/BSGFeatureFlagStorePerformanceTests
//

#import "BSGTestCase.h"

#import "BSGLegacyJSONFeatureFlagStore.h"
#import "BSGPersistentFeatureFlagStore.h"
#import "BugsnagFeatureFlag.h"

#import <mach/mach_time.h>

typedef NS_ENUM(NSUInteger, BSGFeatureFlagStoreKind) {
    BSGFeatureFlagStoreKindJSON,
    BSGFeatureFlagStoreKindBinary,
};

static NSArray<BugsnagFeatureFlag *> * BSGMakeFlags(NSUInteger start, NSUInteger count) {
    NSMutableArray<BugsnagFeatureFlag *> *flags = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i = start; i < start + count; i++) {
        [flags addObject:[BugsnagFeatureFlag flagWithName:[NSString stringWithFormat:@"flag-%lu", (unsigned long)i]
                                                  variant:[NSString stringWithFormat:@"variant-%lu", (unsigned long)i]]];
    }
    return flags;
}

static double BSGMillisecondsSince(uint64_t start) {
    static mach_timebase_info_data_t timebase;
    if (timebase.denom == 0) {
        mach_timebase_info(&timebase);
    }
    uint64_t elapsed = mach_absolute_time() - start;
    return (double)elapsed * timebase.numer / timebase.denom / 1e6;
}

/// Nearest-rank percentile.
static double BSGPercentile(NSArray<NSNumber *> *samples, double percentile) {
    NSArray<NSNumber *> *sorted = [samples sortedArrayUsingSelector:@selector(compare:)];
    NSUInteger rank = (NSUInteger)ceil(percentile / 100.0 * sorted.count);
    NSUInteger index = rank > 0 ? rank - 1 : 0;
    return sorted[MIN(index, sorted.count - 1)].doubleValue;
}

@interface BSGFeatureFlagStorePerformanceTests : BSGTestCase

@property (nonatomic) NSMutableArray<NSString *> *temporaryDirectories;

@end

@implementation BSGFeatureFlagStorePerformanceTests

+ (XCTestSuite *)defaultTestSuite {
    // An empty suite rather than dozens of skipped tests in a normal run
    if (!NSProcessInfo.processInfo.environment[@"BSG_RUN_PERFORMANCE_TESTS"]) {
        return [XCTestSuite testSuiteWithName:NSStringFromClass(self)];
    }
    return [super defaultTestSuite];
}

- (void)setUp {
    [super setUp];
    self.temporaryDirectories = [NSMutableArray array];
}

- (void)tearDown {
    for (NSString *directory in self.temporaryDirectories) {
        [NSFileManager.defaultManager removeItemAtPath:directory error:nil];
    }
    [super tearDown];
}

#pragma mark - Helpers

- (NSString *)makeTemporaryDirectory {
    NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:
                           [NSString stringWithFormat:@"BSGFeatureFlagStorePerf-%@", NSUUID.UUID.UUIDString]];
    NSError *error = nil;
    XCTAssertTrue([NSFileManager.defaultManager createDirectoryAtPath:directory
                                          withIntermediateDirectories:YES attributes:nil error:&error], @"%@", error);
    [self.temporaryDirectories addObject:directory];
    return directory;
}

- (void)removeDirectory:(NSString *)directory {
    [NSFileManager.defaultManager removeItemAtPath:directory error:nil];
    [self.temporaryDirectories removeObject:directory];
}

// Named new... so ARC returns the store retained: only the lock holder writes, and a store holds the lock until
// released.
- (id<BSGFeatureFlagStore>)newStoreOfKind:(BSGFeatureFlagStoreKind)kind directory:(NSString *)directory {
    switch (kind) {
        case BSGFeatureFlagStoreKindJSON:
            return [[BSGLegacyJSONFeatureFlagStore alloc] initWithStorageDirectory:directory];
        case BSGFeatureFlagStoreKindBinary:
            return [[BSGPersistentFeatureFlagStore alloc] initWithStorageDirectory:directory];
    }
}

/// A fresh directory with `count` flags saved by an earlier store.
- (NSString *)directoryWithFlags:(NSUInteger)count kind:(BSGFeatureFlagStoreKind)kind {
    NSString *directory = [self makeTemporaryDirectory];
    [[self newStoreOfKind:kind directory:directory] addFeatureFlags:BSGMakeFlags(0, count)];
    return directory;
}

#pragma mark - XCTest measure benchmarks

/// Wall-clock measurement with manual start/stop, with fewer iterations where XCTMeasureOptions exists (the JSON store
/// takes seconds for 10,000 flags).
- (void)measureWithIterations:(NSUInteger)iterations block:(void (^)(void))block {
    if (@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 8.0, *)) {
        XCTMeasureOptions *options = [XCTMeasureOptions defaultOptions];
        options.invocationOptions = XCTMeasurementInvocationManuallyStart | XCTMeasurementInvocationManuallyStop;
        options.iterationCount = iterations;
        [self measureWithMetrics:@[[[XCTClockMetric alloc] init]] options:options block:block];
        return;
    }
    // Older OSes: default iterations via the older API
    [self measureMetrics:@[XCTPerformanceMetric_WallClockTime] automaticallyStartMeasuring:NO forBlock:block];
}

static NSUInteger BSGIterationsForFlagCount(NSUInteger count) {
    return count >= 10000 ? 3 : 5;
}

- (void)measureBatchAdd:(NSUInteger)count kind:(BSGFeatureFlagStoreKind)kind {
    NSArray<BugsnagFeatureFlag *> *flags = BSGMakeFlags(0, count);
    [self measureWithIterations:BSGIterationsForFlagCount(count) block:^{
        NSString *directory = [self makeTemporaryDirectory];
        id<BSGFeatureFlagStore> store = [self newStoreOfKind:kind directory:directory];
        [self startMeasuring];
        [store addFeatureFlags:flags];
        [self stopMeasuring];
        XCTAssertEqual(store.allFlags.count, count);
        [self removeDirectory:directory];
    }];
}

- (void)testBatchAdd100JSON   { [self measureBatchAdd:100 kind:BSGFeatureFlagStoreKindJSON]; }
- (void)testBatchAdd100Binary   { [self measureBatchAdd:100 kind:BSGFeatureFlagStoreKindBinary]; }
- (void)testBatchAdd1000JSON  { [self measureBatchAdd:1000 kind:BSGFeatureFlagStoreKindJSON]; }
- (void)testBatchAdd1000Binary  { [self measureBatchAdd:1000 kind:BSGFeatureFlagStoreKindBinary]; }
- (void)testBatchAdd10000JSON { [self measureBatchAdd:10000 kind:BSGFeatureFlagStoreKindJSON]; }
- (void)testBatchAdd10000Binary { [self measureBatchAdd:10000 kind:BSGFeatureFlagStoreKindBinary]; }

- (void)measureIncrementalAdds:(NSUInteger)adds onTopOf:(NSUInteger)existing kind:(BSGFeatureFlagStoreKind)kind {
    NSArray<BugsnagFeatureFlag *> *initial = BSGMakeFlags(0, existing);
    NSArray<BugsnagFeatureFlag *> *additional = BSGMakeFlags(existing, adds);
    [self measureWithIterations:BSGIterationsForFlagCount(existing) block:^{
        NSString *directory = [self makeTemporaryDirectory];
        id<BSGFeatureFlagStore> store = [self newStoreOfKind:kind directory:directory];
        [store addFeatureFlags:initial];
        [self startMeasuring];
        for (BugsnagFeatureFlag *flag in additional) {
            [store addFeatureFlag:flag.name withVariant:flag.variant];
        }
        [self stopMeasuring];
        XCTAssertEqual(store.allFlags.count, existing + adds);
        [self removeDirectory:directory];
    }];
}

- (void)testIncrementalAdds100OnTopOf1000JSON {
    [self measureIncrementalAdds:100 onTopOf:1000 kind:BSGFeatureFlagStoreKindJSON];
}

- (void)testIncrementalAdds100OnTopOf1000Binary {
    [self measureIncrementalAdds:100 onTopOf:1000 kind:BSGFeatureFlagStoreKindBinary];
}

- (void)measureClearAll:(NSUInteger)count kind:(BSGFeatureFlagStoreKind)kind {
    NSArray<BugsnagFeatureFlag *> *flags = BSGMakeFlags(0, count);
    [self measureWithIterations:BSGIterationsForFlagCount(count) block:^{
        NSString *directory = [self makeTemporaryDirectory];
        id<BSGFeatureFlagStore> store = [self newStoreOfKind:kind directory:directory];
        [store addFeatureFlags:flags];
        [self startMeasuring];
        [store clear];
        [self stopMeasuring];
        XCTAssertEqual(store.allFlags.count, 0);
        [self removeDirectory:directory];
    }];
}

- (void)testClearAll1000JSON { [self measureClearAll:1000 kind:BSGFeatureFlagStoreKindJSON]; }
- (void)testClearAll1000Binary { [self measureClearAll:1000 kind:BSGFeatureFlagStoreKindBinary]; }

- (void)measureColdLoad:(NSUInteger)count kind:(BSGFeatureFlagStoreKind)kind {
    NSString *directory = [self directoryWithFlags:count kind:kind];
    [self measureWithIterations:BSGIterationsForFlagCount(count) block:^{
        [self startMeasuring];
        id<BSGFeatureFlagStore> store = [self newStoreOfKind:kind directory:directory];
        NSArray<BugsnagFeatureFlag *> *flags = store.allFlags;
        [self stopMeasuring];
        XCTAssertEqual(flags.count, count);
    }];
}

- (void)testColdLoad1000JSON  { [self measureColdLoad:1000 kind:BSGFeatureFlagStoreKindJSON]; }
- (void)testColdLoad1000Binary  { [self measureColdLoad:1000 kind:BSGFeatureFlagStoreKindBinary]; }
- (void)testColdLoad10000JSON { [self measureColdLoad:10000 kind:BSGFeatureFlagStoreKindJSON]; }
- (void)testColdLoad10000Binary { [self measureColdLoad:10000 kind:BSGFeatureFlagStoreKindBinary]; }

#pragma mark - Disk writes

- (void)measureDiskWritesForBatchAdd:(NSUInteger)count kind:(BSGFeatureFlagStoreKind)kind {
    if (@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 8.0, *)) {
        NSArray<BugsnagFeatureFlag *> *flags = BSGMakeFlags(0, count);
        XCTMeasureOptions *options = [XCTMeasureOptions defaultOptions];
        options.invocationOptions = XCTMeasurementInvocationManuallyStart | XCTMeasurementInvocationManuallyStop;
        options.iterationCount = 3;
        [self measureWithMetrics:@[[[XCTStorageMetric alloc] init], [[XCTClockMetric alloc] init]]
                         options:options
                           block:^{
            NSString *directory = [self makeTemporaryDirectory];
            id<BSGFeatureFlagStore> store = [self newStoreOfKind:kind directory:directory];
            [self startMeasuring];
            [store addFeatureFlags:flags];
            [self stopMeasuring];
            [self removeDirectory:directory];
        }];
        return;
    }
    XCTSkip(@"XCTStorageMetric is not available on this OS version");
}

- (void)testDiskWritesBatchAdd1000JSON { [self measureDiskWritesForBatchAdd:1000 kind:BSGFeatureFlagStoreKindJSON]; }
- (void)testDiskWritesBatchAdd1000Binary { [self measureDiskWritesForBatchAdd:1000 kind:BSGFeatureFlagStoreKindBinary]; }

#pragma mark - Comparison table

typedef void (^ BSGTimedBlock)(void);

/// Runs `iterations` samples. `setup` (untimed) returns the block to time.
- (NSArray<NSNumber *> *)sample:(NSUInteger)iterations
                          setup:(BSGTimedBlock (^)(void))setup {
    NSMutableArray<NSNumber *> *samples = [NSMutableArray arrayWithCapacity:iterations];
    for (NSUInteger i = 0; i < iterations; i++) {
        @autoreleasepool {
            BSGTimedBlock work = setup();
            uint64_t start = mach_absolute_time();
            work();
            [samples addObject:@(BSGMillisecondsSince(start))];
        }
    }
    return samples;
}

- (NSArray<NSNumber *> *)batchAddSamples:(NSUInteger)count kind:(BSGFeatureFlagStoreKind)kind iterations:(NSUInteger)iterations {
    NSArray<BugsnagFeatureFlag *> *flags = BSGMakeFlags(0, count);
    __block NSString *previous = nil;
    NSArray *samples = [self sample:iterations setup:^BSGTimedBlock{
        if (previous) {
            [self removeDirectory:previous];
        }
        NSString *directory = previous = [self makeTemporaryDirectory];
        id<BSGFeatureFlagStore> store = [self newStoreOfKind:kind directory:directory];
        return ^{ [store addFeatureFlags:flags]; };
    }];
    [self removeDirectory:previous];
    return samples;
}

- (NSArray<NSNumber *> *)coldLoadSamples:(NSUInteger)count kind:(BSGFeatureFlagStoreKind)kind iterations:(NSUInteger)iterations {
    NSString *directory = [self directoryWithFlags:count kind:kind];
    NSArray *samples = [self sample:iterations setup:^BSGTimedBlock{
        return ^{
            id<BSGFeatureFlagStore> store = [self newStoreOfKind:kind directory:directory];
            if (store.allFlags.count != count) {
                XCTFail(@"Cold load returned the wrong number of flags");
            }
        };
    }];
    [self removeDirectory:directory];
    return samples;
}

/// One addFeatureFlag: changing an existing variant in a store of `count` flags.
- (NSArray<NSNumber *> *)singleUpdateSamples:(NSUInteger)count kind:(BSGFeatureFlagStoreKind)kind iterations:(NSUInteger)iterations {
    NSString *directory = [self makeTemporaryDirectory];
    id<BSGFeatureFlagStore> store = [self newStoreOfKind:kind directory:directory];
    [store addFeatureFlags:BSGMakeFlags(0, count)];
    NSString *name = [NSString stringWithFormat:@"flag-%lu", (unsigned long)(count / 2)];
    __block NSUInteger iteration = 0;
    NSArray *samples = [self sample:iterations setup:^BSGTimedBlock{
        NSString *variant = [NSString stringWithFormat:@"updated-%lu", (unsigned long)iteration++];
        return ^{ [store addFeatureFlag:name withVariant:variant]; };
    }];
    [self removeDirectory:directory];
    return samples;
}

/// One addFeatureFlag: adding a new flag to a store of `count` flags.
- (NSArray<NSNumber *> *)singleAddSamples:(NSUInteger)count kind:(BSGFeatureFlagStoreKind)kind iterations:(NSUInteger)iterations {
    NSString *directory = [self makeTemporaryDirectory];
    id<BSGFeatureFlagStore> store = [self newStoreOfKind:kind directory:directory];
    [store addFeatureFlags:BSGMakeFlags(0, count)];
    __block NSUInteger iteration = 0;
    NSArray *samples = [self sample:iterations setup:^BSGTimedBlock{
        NSString *name = [NSString stringWithFormat:@"new-flag-%lu", (unsigned long)iteration++];
        return ^{ [store addFeatureFlag:name withVariant:@"variant"]; };
    }];
    [self removeDirectory:directory];
    return samples;
}

/// Fewer samples: the JSON store takes seconds per 10,000-flag batch add.
static NSUInteger BSGTableIterations(NSUInteger count) {
    return count >= 10000 ? 5 : 10;
}

#pragma mark - Slowest single call

/// `count` flags whose records (8 bytes of lengths, a 10-byte name and the variant) take up just under the 2 MB limit.
static NSArray<BugsnagFeatureFlag *> * BSGFlagsNearTheLimit(NSUInteger variantLength, NSString *prefix) {
    const NSUInteger recordLength = 8 + 10 + variantLength;
    const NSUInteger count = (2 * 1024 * 1024 - 16) / recordLength;
    NSMutableArray<BugsnagFeatureFlag *> *flags = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i = 0; i < count; i++) {
        NSString *name = [NSString stringWithFormat:@"%@-%05lu", prefix, (unsigned long)i];
        NSString *variant = [[NSString stringWithFormat:@"%@-", name] stringByPaddingToLength:variantLength
                                                                                withString:@"v" startingAtIndex:0];
        [flags addObject:[BugsnagFeatureFlag flagWithName:name variant:variant]];
    }
    return flags;
}

/// Times one call on the calling thread, in milliseconds.
static double BSGTimeCall(dispatch_block_t block) {
    const uint64_t start = mach_absolute_time();
    block();
    return BSGMillisecondsSince(start);
}

static NSString * BSGDescribeSamples(NSArray<NSNumber *> *samples) {
    return [NSString stringWithFormat:@"max %.2f ms, p50 %.3f ms, p99 %.3f ms over %lu", BSGPercentile(samples, 100),
            BSGPercentile(samples, 50), BSGPercentile(samples, 99), (unsigned long)samples.count];
}

/// Logs (asserting nothing) the slowest call on the caller's thread: adding flags one by one up to the 2 MB limit,
/// clearing and shrinking, and replaceAllFlags: at start with about 2 MB.
- (void)testSlowestSingleCallOnTheCallersThread {
    NSMutableString *report = [NSMutableString stringWithString:@"\n"];
    const NSUInteger rounds = 5;
    for (NSNumber *variantLength in @[@1000, @100]) {
        NSArray<BugsnagFeatureFlag *> *flags = BSGFlagsNearTheLimit(variantLength.unsignedIntegerValue, @"flag");
        NSArray<BugsnagFeatureFlag *> *otherFlags = BSGFlagsNearTheLimit(variantLength.unsignedIntegerValue, @"next");
        NSArray<BugsnagFeatureFlag *> *fewFlags = [flags subarrayWithRange:NSMakeRange(0, 10)];
        NSMutableArray<NSNumber *> *addMaxima = [NSMutableArray array], *addAll = [NSMutableArray array];
        NSMutableArray<NSNumber *> *clearAll = [NSMutableArray array], *shrink = [NSMutableArray array];
        NSMutableArray<NSNumber *> *startNew = [NSMutableArray array], *startSame = [NSMutableArray array];
        NSMutableArray<NSNumber *> *startOther = [NSMutableArray array], *coldLoad = [NSMutableArray array];
        NSUInteger slowestIndex = 0;
        double slowest = 0;
        for (NSUInteger round = 0; round < rounds; round++) {
            @autoreleasepool {
                // Growing to the limit, one flag at a time
                NSString *directory = [self makeTemporaryDirectory];
                __block BSGPersistentFeatureFlagStore *store = [[BSGPersistentFeatureFlagStore alloc] initWithStorageDirectory:directory];
                double roundMax = 0;
                for (NSUInteger i = 0; i < flags.count; i++) {
                    BugsnagFeatureFlag *flag = flags[i];
                    const double ms = BSGTimeCall(^{ [store addFeatureFlag:flag.name withVariant:flag.variant]; });
                    [addAll addObject:@(ms)];
                    roundMax = MAX(roundMax, ms);
                    if (ms > slowest) {
                        slowest = ms;
                        slowestIndex = i;
                    }
                }
                [addMaxima addObject:@(roundMax)];
                XCTAssertEqual(store.allFlags.count, flags.count);

                // Clearing, then replacing with a few flags, which swaps the large file for a small one
                [clearAll addObject:@(BSGTimeCall(^{ [store clear]; }))];
                const unsigned long long sizeBefore = [[NSFileManager.defaultManager attributesOfItemAtPath:
                                                        [directory stringByAppendingPathComponent:@"featureflag.bin"] error:nil] fileSize];
                [shrink addObject:@(BSGTimeCall(^{ [store replaceAllFlags:fewFlags]; }))];
                const unsigned long long sizeAfter = [[NSFileManager.defaultManager attributesOfItemAtPath:
                                                       [directory stringByAppendingPathComponent:@"featureflag.bin"] error:nil] fileSize];
                XCTAssertLessThan(sizeAfter, sizeBefore, @"The file should have been shrunk");
                store = nil;
                [self removeDirectory:directory];

                // replaceAllFlags: at start with about 2 MB of flags: no file, a file with the same flags (usual), and
                // one with other flags
                // Each store is released in its own pool so the next gets the lock (otherwise it reads and writes
                // nothing)
                directory = [self makeTemporaryDirectory];
                @autoreleasepool {
                    BSGPersistentFeatureFlagStore *first = [[BSGPersistentFeatureFlagStore alloc] initWithStorageDirectory:directory];
                    [startNew addObject:@(BSGTimeCall(^{ [first replaceAllFlags:flags]; }))];
                }
                @autoreleasepool {
                    __block BSGPersistentFeatureFlagStore *reopened = nil;
                    [coldLoad addObject:@(BSGTimeCall(^{
                        reopened = [[BSGPersistentFeatureFlagStore alloc] initWithStorageDirectory:directory];
                    }))];
                    XCTAssertEqual(reopened.allFlags.count, flags.count);
                    [startSame addObject:@(BSGTimeCall(^{ [reopened replaceAllFlags:flags]; }))];
                }
                @autoreleasepool {
                    BSGPersistentFeatureFlagStore *reopened = [[BSGPersistentFeatureFlagStore alloc] initWithStorageDirectory:directory];
                    XCTAssertEqual(reopened.allFlags.count, flags.count);
                    [startOther addObject:@(BSGTimeCall(^{ [reopened replaceAllFlags:otherFlags]; }))];
                }
                @autoreleasepool {
                    BSGPersistentFeatureFlagStore *last = [[BSGPersistentFeatureFlagStore alloc] initWithStorageDirectory:directory];
                    XCTAssertEqual(last.allFlags.count, otherFlags.count, @"The other flags should have been saved");
                }
                [self removeDirectory:directory];
            }
        }
        [report appendFormat:@"[M5] %lu flags with %@-byte variants (%lu bytes of records), %lu rounds\n",
         (unsigned long)flags.count, variantLength, (unsigned long)(flags.count * (18 + variantLength.unsignedIntegerValue)),
         (unsigned long)rounds];
        [report appendFormat:@"[M5]   addFeatureFlag, each call: %@ (slowest was call %lu)\n", BSGDescribeSamples(addAll),
         (unsigned long)slowestIndex];
        [report appendFormat:@"[M5]   addFeatureFlag, slowest call per round: %@\n", BSGDescribeSamples(addMaxima)];
        [report appendFormat:@"[M5]   clear (all flags at the limit): %@\n", BSGDescribeSamples(clearAll)];
        [report appendFormat:@"[M5]   replaceAllFlags: with 10 flags after clear (shrinks the file): %@\n", BSGDescribeSamples(shrink)];
        [report appendFormat:@"[M5]   replaceAllFlags: at start, no file: %@\n", BSGDescribeSamples(startNew)];
        [report appendFormat:@"[M5]   store created (reads 2 MB): %@\n", BSGDescribeSamples(coldLoad)];
        [report appendFormat:@"[M5]   replaceAllFlags: at start, same flags as the file: %@\n", BSGDescribeSamples(startSame)];
        [report appendFormat:@"[M5]   replaceAllFlags: at start, other flags than the file: %@\n", BSGDescribeSamples(startOther)];
    }
    NSLog(@"Slowest single calls:%@", report);
}

- (void)testPrintComparisonTable {
    NSArray<NSNumber *> *counts = @[@100, @1000, @10000];

    typedef NSArray<NSNumber *> * (^ BSGSampler)(NSUInteger count, BSGFeatureFlagStoreKind kind);
    NSArray<NSArray *> *operations = @[
        @[@"Batch add (empty store)", ^NSArray *(NSUInteger count, BSGFeatureFlagStoreKind kind) {
            return [self batchAddSamples:count kind:kind iterations:BSGTableIterations(count)];
        }],
        @[@"Cold load (init + allFlags)", ^NSArray *(NSUInteger count, BSGFeatureFlagStoreKind kind) {
            return [self coldLoadSamples:count kind:kind iterations:BSGTableIterations(count)];
        }],
        @[@"Single update (existing flag)", ^NSArray *(NSUInteger count, BSGFeatureFlagStoreKind kind) {
            return [self singleUpdateSamples:count kind:kind iterations:BSGTableIterations(count)];
        }],
        @[@"Single add (new flag)", ^NSArray *(NSUInteger count, BSGFeatureFlagStoreKind kind) {
            return [self singleAddSamples:count kind:kind iterations:BSGTableIterations(count)];
        }],
    ];

    NSMutableString *table = [NSMutableString string];
    [table appendString:@"\n10 iterations per cell (5 for 10,000 flags), nearest-rank percentiles\n"];
    [table appendString:@"| Operation | Flags | JSON p50 (ms) | JSON p95 (ms) | binary p50 (ms) | binary p95 (ms) | p50 speed-up |\n"];
    [table appendString:@"|---|---:|---:|---:|---:|---:|---:|\n"];
    for (NSArray *operation in operations) {
        NSString *title = operation[0];
        BSGSampler sampler = operation[1];
        for (NSNumber *count in counts) {
            NSArray<NSNumber *> *json = sampler(count.unsignedIntegerValue, BSGFeatureFlagStoreKindJSON);
            NSArray<NSNumber *> *binary = sampler(count.unsignedIntegerValue, BSGFeatureFlagStoreKindBinary);
            double jsonP50 = BSGPercentile(json, 50), jsonP95 = BSGPercentile(json, 95);
            double binaryP50 = BSGPercentile(binary, 50), binaryP95 = BSGPercentile(binary, 95);
            [table appendFormat:@"| %@ | %@ | %.3f | %.3f | %.3f | %.3f | %.1fx |\n",
             title, count, jsonP50, jsonP95, binaryP50, binaryP95, binaryP50 > 0 ? jsonP50 / binaryP50 : 0];
        }
    }
    NSLog(@"BSGFeatureFlagStore comparison:%@", table);
}

@end
