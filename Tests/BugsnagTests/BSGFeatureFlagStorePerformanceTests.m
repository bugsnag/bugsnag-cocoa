//
//  BSGFeatureFlagStorePerformanceTests.m
//  Bugsnag
//
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//
//  Benchmarks comparing the legacy feature flag persistence (one JSON file per
//  flag, BSGLegacyJSONFeatureFlagStore) with the memory-mapped
//  BSGPersistentFeatureFlagStore. Each workload runs against both stores, each
//  in a fresh temporary directory.
//
//  XCTest allows only one measure block per test method, so every benchmark is
//  split into a "JSON" and an "Mmap" test with an identical workload.
//  testPrintComparisonTable logs a markdown table of p50 / p95 timings.
//
//  The benchmarks take several minutes, so they only run when the environment
//  variable BSG_RUN_PERFORMANCE_TESTS is set, for example:
//  TEST_RUNNER_BSG_RUN_PERFORMANCE_TESTS=1 xcodebuild test ...
//

#import "BSGTestCase.h"

#import "BSGLegacyJSONFeatureFlagStore.h"
#import "BSGPersistentFeatureFlagStore.h"
#import "BugsnagFeatureFlag.h"

#import <mach/mach_time.h>

typedef NS_ENUM(NSUInteger, BSGFeatureFlagStoreKind) {
    BSGFeatureFlagStoreKindJSON,
    BSGFeatureFlagStoreKindMmap,
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
    // An empty suite rather than XCTSkip, which is unavailable in the oldest versions of Xcode
    // used to run the tests
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

- (id<BSGFeatureFlagStore>)storeOfKind:(BSGFeatureFlagStoreKind)kind directory:(NSString *)directory {
    switch (kind) {
        case BSGFeatureFlagStoreKindJSON:
            return [[BSGLegacyJSONFeatureFlagStore alloc] initWithStorageDirectory:directory];
        case BSGFeatureFlagStoreKindMmap:
            return [[BSGPersistentFeatureFlagStore alloc] initWithStorageDirectory:directory];
    }
}

/// A fresh directory holding `count` flags written by a previous store instance.
- (NSString *)directoryWithFlags:(NSUInteger)count kind:(BSGFeatureFlagStoreKind)kind {
    NSString *directory = [self makeTemporaryDirectory];
    [[self storeOfKind:kind directory:directory] addFeatureFlags:BSGMakeFlags(0, count)];
    return directory;
}

#pragma mark - XCTest measure benchmarks

/// Wall-clock measurement with manual start/stop. Uses a reduced iteration count where
/// XCTMeasureOptions is available, because the JSON store takes many seconds for 10,000 flags.
- (void)measureWithIterations:(NSUInteger)iterations block:(void (^)(void))block {
    if (@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 8.0, *)) {
        XCTMeasureOptions *options = [XCTMeasureOptions defaultOptions];
        options.invocationOptions = XCTMeasurementInvocationManuallyStart | XCTMeasurementInvocationManuallyStop;
        options.iterationCount = iterations;
        [self measureWithMetrics:@[[[XCTClockMetric alloc] init]] options:options block:block];
    } else {
        [self measureMetrics:@[XCTPerformanceMetric_WallClockTime] automaticallyStartMeasuring:NO forBlock:block];
    }
}

static NSUInteger BSGIterationsForFlagCount(NSUInteger count) {
    return count >= 10000 ? 3 : 5;
}

- (void)measureBatchAdd:(NSUInteger)count kind:(BSGFeatureFlagStoreKind)kind {
    NSArray<BugsnagFeatureFlag *> *flags = BSGMakeFlags(0, count);
    [self measureWithIterations:BSGIterationsForFlagCount(count) block:^{
        NSString *directory = [self makeTemporaryDirectory];
        id<BSGFeatureFlagStore> store = [self storeOfKind:kind directory:directory];
        [self startMeasuring];
        [store addFeatureFlags:flags];
        [self stopMeasuring];
        XCTAssertEqual(store.allFlags.count, count);
        [self removeDirectory:directory];
    }];
}

- (void)testBatchAdd100JSON   { [self measureBatchAdd:100 kind:BSGFeatureFlagStoreKindJSON]; }
- (void)testBatchAdd100Mmap   { [self measureBatchAdd:100 kind:BSGFeatureFlagStoreKindMmap]; }
- (void)testBatchAdd1000JSON  { [self measureBatchAdd:1000 kind:BSGFeatureFlagStoreKindJSON]; }
- (void)testBatchAdd1000Mmap  { [self measureBatchAdd:1000 kind:BSGFeatureFlagStoreKindMmap]; }
- (void)testBatchAdd10000JSON { [self measureBatchAdd:10000 kind:BSGFeatureFlagStoreKindJSON]; }
- (void)testBatchAdd10000Mmap { [self measureBatchAdd:10000 kind:BSGFeatureFlagStoreKindMmap]; }

- (void)measureIncrementalAdds:(NSUInteger)adds onTopOf:(NSUInteger)existing kind:(BSGFeatureFlagStoreKind)kind {
    NSArray<BugsnagFeatureFlag *> *initial = BSGMakeFlags(0, existing);
    NSArray<BugsnagFeatureFlag *> *additional = BSGMakeFlags(existing, adds);
    [self measureWithIterations:BSGIterationsForFlagCount(existing) block:^{
        NSString *directory = [self makeTemporaryDirectory];
        id<BSGFeatureFlagStore> store = [self storeOfKind:kind directory:directory];
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

- (void)testIncrementalAdds100OnTopOf1000Mmap {
    [self measureIncrementalAdds:100 onTopOf:1000 kind:BSGFeatureFlagStoreKindMmap];
}

- (void)measureClearAll:(NSUInteger)count kind:(BSGFeatureFlagStoreKind)kind {
    NSArray<BugsnagFeatureFlag *> *flags = BSGMakeFlags(0, count);
    [self measureWithIterations:BSGIterationsForFlagCount(count) block:^{
        NSString *directory = [self makeTemporaryDirectory];
        id<BSGFeatureFlagStore> store = [self storeOfKind:kind directory:directory];
        [store addFeatureFlags:flags];
        [self startMeasuring];
        [store clear];
        [self stopMeasuring];
        XCTAssertEqual(store.allFlags.count, 0);
        [self removeDirectory:directory];
    }];
}

- (void)testClearAll1000JSON { [self measureClearAll:1000 kind:BSGFeatureFlagStoreKindJSON]; }
- (void)testClearAll1000Mmap { [self measureClearAll:1000 kind:BSGFeatureFlagStoreKindMmap]; }

- (void)measureColdLoad:(NSUInteger)count kind:(BSGFeatureFlagStoreKind)kind {
    NSString *directory = [self directoryWithFlags:count kind:kind];
    [self measureWithIterations:BSGIterationsForFlagCount(count) block:^{
        [self startMeasuring];
        id<BSGFeatureFlagStore> store = [self storeOfKind:kind directory:directory];
        NSArray<BugsnagFeatureFlag *> *flags = store.allFlags;
        [self stopMeasuring];
        XCTAssertEqual(flags.count, count);
    }];
}

- (void)testColdLoad1000JSON  { [self measureColdLoad:1000 kind:BSGFeatureFlagStoreKindJSON]; }
- (void)testColdLoad1000Mmap  { [self measureColdLoad:1000 kind:BSGFeatureFlagStoreKindMmap]; }
- (void)testColdLoad10000JSON { [self measureColdLoad:10000 kind:BSGFeatureFlagStoreKindJSON]; }
- (void)testColdLoad10000Mmap { [self measureColdLoad:10000 kind:BSGFeatureFlagStoreKindMmap]; }

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
            id<BSGFeatureFlagStore> store = [self storeOfKind:kind directory:directory];
            [self startMeasuring];
            [store addFeatureFlags:flags];
            [self stopMeasuring];
            [self removeDirectory:directory];
        }];
    } else {
        NSLog(@"XCTStorageMetric is not available on this OS version; skipping");
    }
}

- (void)testDiskWritesBatchAdd1000JSON { [self measureDiskWritesForBatchAdd:1000 kind:BSGFeatureFlagStoreKindJSON]; }
- (void)testDiskWritesBatchAdd1000Mmap { [self measureDiskWritesForBatchAdd:1000 kind:BSGFeatureFlagStoreKindMmap]; }

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
        id<BSGFeatureFlagStore> store = [self storeOfKind:kind directory:directory];
        return ^{ [store addFeatureFlags:flags]; };
    }];
    [self removeDirectory:previous];
    return samples;
}

- (NSArray<NSNumber *> *)coldLoadSamples:(NSUInteger)count kind:(BSGFeatureFlagStoreKind)kind iterations:(NSUInteger)iterations {
    NSString *directory = [self directoryWithFlags:count kind:kind];
    NSArray *samples = [self sample:iterations setup:^BSGTimedBlock{
        return ^{
            id<BSGFeatureFlagStore> store = [self storeOfKind:kind directory:directory];
            if (store.allFlags.count != count) {
                XCTFail(@"Cold load returned the wrong number of flags");
            }
        };
    }];
    [self removeDirectory:directory];
    return samples;
}

/// One addFeatureFlag: call that changes the variant of an existing flag in a store holding `count` flags.
- (NSArray<NSNumber *> *)singleUpdateSamples:(NSUInteger)count kind:(BSGFeatureFlagStoreKind)kind iterations:(NSUInteger)iterations {
    NSString *directory = [self makeTemporaryDirectory];
    id<BSGFeatureFlagStore> store = [self storeOfKind:kind directory:directory];
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

/// One addFeatureFlag: call that adds a new flag to a store holding `count` flags.
- (NSArray<NSNumber *> *)singleAddSamples:(NSUInteger)count kind:(BSGFeatureFlagStoreKind)kind iterations:(NSUInteger)iterations {
    NSString *directory = [self makeTemporaryDirectory];
    id<BSGFeatureFlagStore> store = [self storeOfKind:kind directory:directory];
    [store addFeatureFlags:BSGMakeFlags(0, count)];
    __block NSUInteger iteration = 0;
    NSArray *samples = [self sample:iterations setup:^BSGTimedBlock{
        NSString *name = [NSString stringWithFormat:@"new-flag-%lu", (unsigned long)iteration++];
        return ^{ [store addFeatureFlag:name withVariant:@"variant"]; };
    }];
    [self removeDirectory:directory];
    return samples;
}

/// The JSON store takes many seconds per 10,000-flag batch add, so fewer samples are taken.
static NSUInteger BSGTableIterations(NSUInteger count) {
    return count >= 10000 ? 5 : 10;
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
    [table appendString:@"| Operation | Flags | JSON p50 (ms) | JSON p95 (ms) | mmap p50 (ms) | mmap p95 (ms) | p50 speed-up |\n"];
    [table appendString:@"|---|---:|---:|---:|---:|---:|---:|\n"];
    for (NSArray *operation in operations) {
        NSString *title = operation[0];
        BSGSampler sampler = operation[1];
        for (NSNumber *count in counts) {
            NSArray<NSNumber *> *json = sampler(count.unsignedIntegerValue, BSGFeatureFlagStoreKindJSON);
            NSArray<NSNumber *> *mmap = sampler(count.unsignedIntegerValue, BSGFeatureFlagStoreKindMmap);
            double jsonP50 = BSGPercentile(json, 50), jsonP95 = BSGPercentile(json, 95);
            double mmapP50 = BSGPercentile(mmap, 50), mmapP95 = BSGPercentile(mmap, 95);
            [table appendFormat:@"| %@ | %@ | %.3f | %.3f | %.3f | %.3f | %.1fx |\n",
             title, count, jsonP50, jsonP95, mmapP50, mmapP95, mmapP50 > 0 ? jsonP50 / mmapP50 : 0];
        }
    }
    NSLog(@"BSGFeatureFlagStore comparison:%@", table);
}

@end
