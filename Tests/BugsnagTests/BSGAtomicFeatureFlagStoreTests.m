//
//  BSGAtomicFeatureFlagStoreTests.m
//  Bugsnag
//
//  Created by Robert B on 24/03/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGTestCase.h"
#import "BSGAtomicFeatureFlagStore.h"
#import "WriterTestsSupport.h"
#import "BugsnagFeatureFlag.h"
#import "BSGCompositeFeatureFlagStore.h"
#import "BSGMemoryFeatureFlagStore.h"
#import "BSGPersistentFeatureFlagStore.h"

#import <stdatomic.h>

static NSArray<NSDictionary *> * AtomicStoreFlags(void) {
    NSDictionary<NSString *, id> *object = bsg_JSONObject(^(BSG_KSCrashReportWriter *writer) {
        writer->beginObject(writer, "");
        BugsnagFeatureFlagsWriteCrashReport(writer, true);
        writer->endContainer(writer);
    });
    return object[@"featureFlags"];
}

/// A memory store that stands in for the persistent store, which must implement replaceAllFlags:.
/// The SDK's memory store does not implement it because nothing calls it.
@interface BSGAtomicTestsReplaceableStore : BSGMemoryFeatureFlagStore <BSGReplaceableFeatureFlagStore>
@end

@implementation BSGAtomicTestsReplaceableStore

- (void)replaceAllFlags:(NSArray<BugsnagFeatureFlag *> *)featureFlags {
    [self clear];
    [self addFeatureFlags:featureFlags];
}

@end

@interface BSGAtomicFeatureFlagStoreTests : BSGTestCase

@end

@implementation BSGAtomicFeatureFlagStoreTests

- (void)setUp {
    BSGAtomicFeatureFlagStore *store = [BSGAtomicFeatureFlagStore store];
    [store clear];
}

- (void)tearDown {
    [[BSGAtomicFeatureFlagStore store] clear];
}

- (void)testStoreIsInitiallyEmpty {
    BSGAtomicFeatureFlagStore *store = [BSGAtomicFeatureFlagStore store];
    
    NSDictionary<NSString *, id> *object = bsg_JSONObject(^(BSG_KSCrashReportWriter *writer) {
        writer->beginObject(writer, "");
        BugsnagFeatureFlagsWriteCrashReport(writer, true);
        writer->endContainer(writer);
    });
    
    XCTAssertEqualObjects(object.allKeys, @[@"featureFlags"]);
    XCTAssertTrue([store isEmpty]);
    
    NSArray<NSDictionary *> *featureFlags = object[@"featureFlags"];
    XCTAssertEqual(featureFlags.count, 0);
}

- (void)testAddMultipleFlagsAtOnce {
    BSGAtomicFeatureFlagStore *store = [BSGAtomicFeatureFlagStore store];
    [store addFeatureFlags:@[
        [BugsnagFeatureFlag flagWithName:@"featureFlagA"],
        [BugsnagFeatureFlag flagWithName:@"featureFlagB" variant:@"testingB"],
        [BugsnagFeatureFlag flagWithName:@"featureFlagC" variant:@"testingC"]
    ]];
    
    NSDictionary<NSString *, id> *object = bsg_JSONObject(^(BSG_KSCrashReportWriter *writer) {
        writer->beginObject(writer, "");
        BugsnagFeatureFlagsWriteCrashReport(writer, true);
        writer->endContainer(writer);
    });
    
    XCTAssertEqualObjects(object.allKeys, @[@"featureFlags"]);
    
    NSArray<NSDictionary *> *featureFlags = object[@"featureFlags"];
    XCTAssertEqual(featureFlags.count, 3);
    
    XCTAssertTrue([featureFlags[0][@"featureFlag"] isEqualToString: @"featureFlagA"]);
    XCTAssertNil(featureFlags[0][@"variant"]);
    
    XCTAssertTrue([featureFlags[1][@"featureFlag"] isEqualToString: @"featureFlagB"]);
    XCTAssertTrue([featureFlags[1][@"variant"] isEqualToString: @"testingB"]);
    
    XCTAssertTrue([featureFlags[2][@"featureFlag"] isEqualToString: @"featureFlagC"]);
    XCTAssertTrue([featureFlags[2][@"variant"] isEqualToString: @"testingC"]);
}

- (void)testAddAndReplace {
    BSGAtomicFeatureFlagStore *store = [BSGAtomicFeatureFlagStore store];

    [store addFeatureFlag:@"featureFlagA" withVariant:@"testingA"];
    [store addFeatureFlag:@"featureFlagB" withVariant:@"testingB"];
    [store addFeatureFlag:@"featureFlagC" withVariant:@"testingC"];
    [store addFeatureFlag:@"featureFlagD" withVariant:@"testingD"];
    [store addFeatureFlag:@"featureFlagA" withVariant:@"testingA2"];
    [store addFeatureFlag:@"featureFlagB" withVariant:@"testingB2"];
    [store addFeatureFlag:@"featureFlagC" withVariant:@"testingC2"];
    [store addFeatureFlag:@"featureFlagB" withVariant:@"testingB3"];
    [store addFeatureFlag:@"featureFlagA" withVariant:@"testingA3"];
    
    NSDictionary<NSString *, id> *object = bsg_JSONObject(^(BSG_KSCrashReportWriter *writer) {
        writer->beginObject(writer, "");
        BugsnagFeatureFlagsWriteCrashReport(writer, true);
        writer->endContainer(writer);
    });
    
    XCTAssertEqualObjects(object.allKeys, @[@"featureFlags"]);
    
    NSArray<NSDictionary *> *featureFlags = object[@"featureFlags"];
    // A name that is already present keeps its position and takes the latest variant
    XCTAssertEqualObjects(featureFlags, (@[@{@"featureFlag": @"featureFlagA", @"variant": @"testingA3"},
                                           @{@"featureFlag": @"featureFlagB", @"variant": @"testingB3"},
                                           @{@"featureFlag": @"featureFlagC", @"variant": @"testingC2"},
                                           @{@"featureFlag": @"featureFlagD", @"variant": @"testingD"}]));
}

- (void)testAddMultipleAndReplace {
    BSGAtomicFeatureFlagStore *store = [BSGAtomicFeatureFlagStore store];
    [store addFeatureFlags:@[
        [BugsnagFeatureFlag flagWithName:@"featureFlagA"],
        [BugsnagFeatureFlag flagWithName:@"featureFlagB" variant:@"testingB"],
        [BugsnagFeatureFlag flagWithName:@"featureFlagC" variant:@"testingC"]
    ]];
    
    [store addFeatureFlag:@"featureFlagA" withVariant:@"testingA2"];
    [store addFeatureFlag:@"featureFlagB" withVariant:@"testingB2"];
    [store addFeatureFlag:@"featureFlagD" withVariant:@"testingD"];
    [store addFeatureFlag:@"featureFlagC" withVariant:@"testingC2"];
    
    NSDictionary<NSString *, id> *object = bsg_JSONObject(^(BSG_KSCrashReportWriter *writer) {
        writer->beginObject(writer, "");
        BugsnagFeatureFlagsWriteCrashReport(writer, true);
        writer->endContainer(writer);
    });
    
    XCTAssertEqualObjects(object.allKeys, @[@"featureFlags"]);
    
    NSArray<NSDictionary *> *featureFlags = object[@"featureFlags"];
    XCTAssertEqualObjects(featureFlags, (@[@{@"featureFlag": @"featureFlagA", @"variant": @"testingA2"},
                                           @{@"featureFlag": @"featureFlagB", @"variant": @"testingB2"},
                                           @{@"featureFlag": @"featureFlagC", @"variant": @"testingC2"},
                                           @{@"featureFlag": @"featureFlagD", @"variant": @"testingD"}]));
}

- (void)testClearShouldRemoveAllFlags {
    BSGAtomicFeatureFlagStore *store = [BSGAtomicFeatureFlagStore store];

    [store addFeatureFlag:@"featureFlagA" withVariant:@"testingA"];
    [store addFeatureFlag:@"featureFlagB" withVariant:@"testingB"];
    [store addFeatureFlag:@"featureFlagC" withVariant:@"testingC"];
    [store addFeatureFlag:@"featureFlagD" withVariant:@"testingD"];
    
    [store clear];
    
    NSDictionary<NSString *, id> *object = bsg_JSONObject(^(BSG_KSCrashReportWriter *writer) {
        writer->beginObject(writer, "");
        BugsnagFeatureFlagsWriteCrashReport(writer, true);
        writer->endContainer(writer);
    });
    
    XCTAssertEqualObjects(object.allKeys, @[@"featureFlags"]);
    XCTAssertTrue([store isEmpty]);
    
    NSArray<NSDictionary *> *featureFlags = object[@"featureFlags"];
    XCTAssertEqual(featureFlags.count, 0);
}

- (void)testClearByNameShouldRemoveASingleFlag {
    BSGAtomicFeatureFlagStore *store = [BSGAtomicFeatureFlagStore store];

    [store addFeatureFlag:@"featureFlagA" withVariant:@"testingA"];
    [store addFeatureFlag:@"featureFlagB" withVariant:@"testingB"];
    [store addFeatureFlag:@"featureFlagC" withVariant:@"testingC"];
    [store addFeatureFlag:@"featureFlagD" withVariant:@"testingD"];
    
    [store clear:@"featureFlagB"];
    
    NSDictionary<NSString *, id> *object = bsg_JSONObject(^(BSG_KSCrashReportWriter *writer) {
        writer->beginObject(writer, "");
        BugsnagFeatureFlagsWriteCrashReport(writer, true);
        writer->endContainer(writer);
    });
    
    XCTAssertEqualObjects(object.allKeys, @[@"featureFlags"]);
    
    NSArray<NSDictionary *> *featureFlags = object[@"featureFlags"];
    XCTAssertEqual(featureFlags.count, 3);
    
    XCTAssertTrue([featureFlags[0][@"featureFlag"] isEqualToString: @"featureFlagA"]);
    XCTAssertTrue([featureFlags[0][@"variant"] isEqualToString: @"testingA"]);
    
    XCTAssertTrue([featureFlags[1][@"featureFlag"] isEqualToString: @"featureFlagC"]);
    XCTAssertTrue([featureFlags[1][@"variant"] isEqualToString: @"testingC"]);
    
    XCTAssertTrue([featureFlags[2][@"featureFlag"] isEqualToString: @"featureFlagD"]);
    XCTAssertTrue([featureFlags[2][@"variant"] isEqualToString: @"testingD"]);
}

- (void)testClearByNameShouldRemoveAllFlagsIfNilIsProvided {
    BSGAtomicFeatureFlagStore *store = [BSGAtomicFeatureFlagStore store];

    [store addFeatureFlag:@"featureFlagA" withVariant:@"testingA"];
    [store addFeatureFlag:@"featureFlagB" withVariant:@"testingB"];
    [store addFeatureFlag:@"featureFlagC" withVariant:@"testingC"];
    [store addFeatureFlag:@"featureFlagD" withVariant:@"testingD"];
    
    [store clear:nil];
    
    NSDictionary<NSString *, id> *object = bsg_JSONObject(^(BSG_KSCrashReportWriter *writer) {
        writer->beginObject(writer, "");
        BugsnagFeatureFlagsWriteCrashReport(writer, true);
        writer->endContainer(writer);
    });
    
    XCTAssertEqualObjects(object.allKeys, @[@"featureFlags"]);
    XCTAssertTrue([store isEmpty]);
    
    NSArray<NSDictionary *> *featureFlags = object[@"featureFlags"];
    XCTAssertEqual(featureFlags.count, 0);
}


- (void)testReplaceAllFlags {
    BSGAtomicFeatureFlagStore *store = [BSGAtomicFeatureFlagStore store];

    [store addFeatureFlag:@"featureFlagA" withVariant:@"testingA"];
    [store addFeatureFlag:@"featureFlagB" withVariant:@"testingB"];
    
    [store replaceAllFlags:@[
        [BugsnagFeatureFlag flagWithName:@"featureFlagC" variant:@"testingC"],
        [BugsnagFeatureFlag flagWithName:@"featureFlagA"]
    ]];
    
    NSDictionary<NSString *, id> *object = bsg_JSONObject(^(BSG_KSCrashReportWriter *writer) {
        writer->beginObject(writer, "");
        BugsnagFeatureFlagsWriteCrashReport(writer, true);
        writer->endContainer(writer);
    });
    
    NSArray<NSDictionary *> *featureFlags = object[@"featureFlags"];
    XCTAssertEqualObjects(featureFlags, (@[@{@"featureFlag": @"featureFlagC", @"variant": @"testingC"},
                                           @{@"featureFlag": @"featureFlagA"}]));
    
    [store replaceAllFlags:@[]];
    XCTAssertTrue([store isEmpty]);
}

#pragma mark - Duplicate names

- (void)testAddFeatureFlagsWithDuplicateNamesKeepsFirstPositionAndLastVariant {
    BSGAtomicFeatureFlagStore *store = [BSGAtomicFeatureFlagStore store];
    [store addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:@"A" variant:@"1"],
                             [BugsnagFeatureFlag flagWithName:@"B"],
                             [BugsnagFeatureFlag flagWithName:@"A" variant:@"2"]]];
    XCTAssertEqualObjects(AtomicStoreFlags(), (@[@{@"featureFlag": @"A", @"variant": @"2"},
                                                 @{@"featureFlag": @"B"}]));

    // A name already in the store is updated in place, not added a second time
    [store addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:@"C" variant:@"3"],
                             [BugsnagFeatureFlag flagWithName:@"A"]]];
    XCTAssertEqualObjects(AtomicStoreFlags(), (@[@{@"featureFlag": @"A"},
                                                 @{@"featureFlag": @"B"},
                                                 @{@"featureFlag": @"C", @"variant": @"3"}]));

    // Clearing a name and adding it again puts it at the end
    [store clear:@"A"];
    [store addFeatureFlag:@"A" withVariant:@"4"];
    XCTAssertEqualObjects(AtomicStoreFlags(), (@[@{@"featureFlag": @"B"},
                                                 @{@"featureFlag": @"C", @"variant": @"3"},
                                                 @{@"featureFlag": @"A", @"variant": @"4"}]));
}

- (void)testReplaceAllFlagsWithDuplicateNames {
    BSGAtomicFeatureFlagStore *store = [BSGAtomicFeatureFlagStore store];
    [store addFeatureFlag:@"old" withVariant:nil];
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"A" variant:@"1"],
                             [BugsnagFeatureFlag flagWithName:@"B"],
                             [BugsnagFeatureFlag flagWithName:@"A" variant:@"2"]]];
    XCTAssertEqualObjects(AtomicStoreFlags(), (@[@{@"featureFlag": @"A", @"variant": @"2"},
                                                 @{@"featureFlag": @"B"}]));

    // The index of names must match the new list, so later updates and clears still work
    [store addFeatureFlag:@"B" withVariant:@"3"];
    [store clear:@"A"];
    XCTAssertEqualObjects(AtomicStoreFlags(), (@[@{@"featureFlag": @"B", @"variant": @"3"}]));
}

- (void)testAtomicAndMemoryStoresAgreeOnDuplicateNames {
    NSArray<BugsnagFeatureFlag *> *input = @[[BugsnagFeatureFlag flagWithName:@"A" variant:@"1"],
                                             [BugsnagFeatureFlag flagWithName:@"B"],
                                             [BugsnagFeatureFlag flagWithName:@"A" variant:@"2"],
                                             [BugsnagFeatureFlag flagWithName:@"C" variant:@"3"],
                                             [BugsnagFeatureFlag flagWithName:@"B" variant:@"4"]];
    BSGAtomicFeatureFlagStore *atomicStore = [BSGAtomicFeatureFlagStore store];
    BSGMemoryFeatureFlagStore *memoryStore = [BSGMemoryFeatureFlagStore new];

    [atomicStore addFeatureFlags:input];
    [memoryStore addFeatureFlags:input];
    XCTAssertEqualObjects(AtomicStoreFlags(), BSGFeatureFlagStoreToJSON(memoryStore));

    [atomicStore replaceAllFlags:[input reverseObjectEnumerator].allObjects];
    [memoryStore clear];
    [memoryStore addFeatureFlags:[input reverseObjectEnumerator].allObjects];
    XCTAssertEqualObjects(AtomicStoreFlags(), BSGFeatureFlagStoreToJSON(memoryStore));
    XCTAssertEqualObjects(AtomicStoreFlags(), (@[@{@"featureFlag": @"B"},
                                                 @{@"featureFlag": @"C", @"variant": @"3"},
                                                 @{@"featureFlag": @"A", @"variant": @"1"}]));
}

#pragma mark - Composite store

- (void)testVariantThatCannotBeSerializedRemovesTheFlagFromCrashAndPersistedReports {
    // A lone surrogate, as left by truncating a string in the middle of an emoji, cannot be converted to UTF-8
    const unichar loneSurrogate = 0xD800;
    NSString *unencodable = [NSString stringWithCharacters:&loneSurrogate length:1];
    NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:
                           [NSString stringWithFormat:@"BSGAtomicFeatureFlagStoreTests-%@", NSUUID.UUID.UUIDString]];
    [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];

    @autoreleasepool {
        BSGMemoryFeatureFlagStore *memoryStore = [BSGMemoryFeatureFlagStore new];
        BSGPersistentFeatureFlagStore *persistentStore = [[BSGPersistentFeatureFlagStore alloc] initWithStorageDirectory:directory];
        BSGCompositeFeatureFlagStore *store = [BSGCompositeFeatureFlagStore storeWithMemoryStore:memoryStore
                                                                                 persistentStore:persistentStore
                                                                                     atomicStore:[BSGAtomicFeatureFlagStore store]];
        [store addFeatureFlag:@"other" withVariant:@"1"];
        [store addFeatureFlag:@"exp" withVariant:@"control"];
        [store addFeatureFlag:@"exp" withVariant:unencodable];

        // Crash reports (atomic store) and OOM and thermal kill events (persistent store) both leave the flag out
        // rather than report "control", a variant that the app has replaced
        NSArray *withoutExp = @[@{@"featureFlag": @"other", @"variant": @"1"}];
        XCTAssertEqualObjects(AtomicStoreFlags(), withoutExp);
        BSGPersistentFeatureFlagStore *reopened = [[BSGPersistentFeatureFlagStore alloc] initWithStorageDirectory:directory];
        XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(reopened), withoutExp);
        reopened = nil;

        // The stores differ here on purpose. The memory store is the source for handled events and keeps every
        // flag as the app set it, so it still holds exp with the new variant; it does not serialize flags itself.
        NSArray<BugsnagFeatureFlag *> *memoryFlags = memoryStore.allFlags;
        XCTAssertEqualObjects([memoryFlags valueForKey:@"name"], (@[@"other", @"exp"]));
        XCTAssertEqualObjects(memoryFlags.lastObject.variant, unencodable);
        XCTAssertEqualObjects([store.allFlags valueForKey:@"name"], (@[@"other", @"exp"]));
    }

    [NSFileManager.defaultManager removeItemAtPath:directory error:nil];
}

- (void)testCompositeStoreKeepsSubStoresInAgreement {
    BSGMemoryFeatureFlagStore *memoryStore = [BSGMemoryFeatureFlagStore new];
    BSGAtomicTestsReplaceableStore *persistentStore = [BSGAtomicTestsReplaceableStore new];
    BSGCompositeFeatureFlagStore *store = [BSGCompositeFeatureFlagStore storeWithMemoryStore:memoryStore
                                                                             persistentStore:persistentStore
                                                                                 atomicStore:[BSGAtomicFeatureFlagStore store]];
    void (^assertAgreement)(NSArray *) = ^(NSArray *expected) {
        XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(memoryStore), expected);
        XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(persistentStore), expected);
        XCTAssertEqualObjects(AtomicStoreFlags(), expected);
    };

    [store addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:@"A" variant:@"1"],
                             [BugsnagFeatureFlag flagWithName:@"B"],
                             [BugsnagFeatureFlag flagWithName:@"A" variant:@"2"]]];
    assertAgreement(@[@{@"featureFlag": @"A", @"variant": @"2"}, @{@"featureFlag": @"B"}]);

    [store addFeatureFlag:@"A" withVariant:@"3"];
    [store addFeatureFlag:@"C" withVariant:nil];
    assertAgreement(@[@{@"featureFlag": @"A", @"variant": @"3"}, @{@"featureFlag": @"B"}, @{@"featureFlag": @"C"}]);

    [store clear:@"B"];
    assertAgreement(@[@{@"featureFlag": @"A", @"variant": @"3"}, @{@"featureFlag": @"C"}]);

    // As when Bugsnag starts: the memory store's flags are copied to the other stores
    [memoryStore clear];
    [memoryStore addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:@"D" variant:@"1"],
                                   [BugsnagFeatureFlag flagWithName:@"E"],
                                   [BugsnagFeatureFlag flagWithName:@"D" variant:@"2"]]];
    [store synchronizeFlagsWithMemoryStore];
    assertAgreement(@[@{@"featureFlag": @"D", @"variant": @"2"}, @{@"featureFlag": @"E"}]);

    [memoryStore addFeatureFlag:@"F" withVariant:@"6"];
    [store synchronizeFlagsWithMemoryStore];
    assertAgreement(@[@{@"featureFlag": @"D", @"variant": @"2"}, @{@"featureFlag": @"E"}, @{@"featureFlag": @"F", @"variant": @"6"}]);

    [store clear];
    assertAgreement(@[]);
}

#pragma mark - Concurrency

static BOOL HasDuplicateNames(NSArray<NSDictionary *> *flags) {
    NSMutableSet *names = [NSMutableSet set];
    for (NSDictionary *flag in flags) {
        if ([names containsObject:flag[@"featureFlag"]]) {
            return YES;
        }
        [names addObject:flag[@"featureFlag"]];
    }
    return NO;
}

- (void)testConcurrentReplaceAllFlagsAndAddNeverDuplicatesOrEmpties {
    BSGAtomicFeatureFlagStore *store = [BSGAtomicFeatureFlagStore store];
    NSMutableArray<BugsnagFeatureFlag *> *setA = [NSMutableArray array];
    NSMutableArray<BugsnagFeatureFlag *> *setB = [NSMutableArray array];
    for (int i = 0; i < 20; i++) {
        NSString *name = [NSString stringWithFormat:@"flag-%d", i];
        [setA addObject:[BugsnagFeatureFlag flagWithName:name variant:@"a"]];
        [setB addObject:[BugsnagFeatureFlag flagWithName:name variant:@"b"]];
    }
    // Both sets contain the name added concurrently below, so it can never legitimately appear twice
    [setA addObject:[BugsnagFeatureFlag flagWithName:@"shared" variant:@"a"]];
    [setB addObject:[BugsnagFeatureFlag flagWithName:@"shared" variant:@"b"]];
    [store replaceAllFlags:setA];

    const int iterations = 2000;
    __block atomic_bool done = false;
    __block int emptyReads = 0;
    __block int shortReads = 0;
    __block int duplicateReads = 0;
    __block int reads = 0;

    dispatch_group_t readerGroup = dispatch_group_create();
    dispatch_group_t writerGroup = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);

    // A single reader, acting like the crash handler
    dispatch_group_async(readerGroup, queue, ^{
        while (!atomic_load(&done)) {
            NSArray<NSDictionary *> *flags = AtomicStoreFlags();
            reads++;
            if (flags.count == 0) {
                emptyReads++;
            } else if (flags.count < setA.count) {
                shortReads++;
            }
            if (HasDuplicateNames(flags)) {
                duplicateReads++;
            }
        }
    });
    dispatch_group_async(writerGroup, queue, ^{
        for (int i = 0; i < iterations; i++) {
            [store replaceAllFlags:(i % 2) ? setB : setA];
        }
    });
    dispatch_group_async(writerGroup, queue, ^{
        for (int i = 0; i < iterations; i++) {
            [store addFeatureFlag:@"shared" withVariant:@"added"];
            [store addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:@"shared" variant:@"added-bulk"],
                                     [BugsnagFeatureFlag flagWithName:@"flag-0" variant:@"added-bulk"]]];
        }
    });
    dispatch_group_async(writerGroup, queue, ^{
        for (int i = 0; i < iterations; i++) {
            [store addFeatureFlag:@"flag-7" withVariant:@"added"];
        }
    });

    dispatch_group_wait(writerGroup, DISPATCH_TIME_FOREVER);
    atomic_store(&done, true);
    dispatch_group_wait(readerGroup, DISPATCH_TIME_FOREVER);

    XCTAssertGreaterThan(reads, 0);
    XCTAssertEqual(emptyReads, 0, @"The crash-time reader saw an empty list during replaceAllFlags");
    XCTAssertEqual(shortReads, 0, @"The crash-time reader saw a partly built list during replaceAllFlags");
    XCTAssertEqual(duplicateReads, 0, @"The crash-time reader saw a name twice");

    NSArray<NSDictionary *> *flags = AtomicStoreFlags();
    XCTAssertEqual(flags.count, setA.count);
    XCTAssertFalse(HasDuplicateNames(flags));
}

#pragma mark - Other behaviour

- (void)testAllFlagsIsAlwaysEmpty {
    // The flags are only read by BugsnagFeatureFlagsWriteCrashReport; allFlags is never used
    BSGAtomicFeatureFlagStore *store = [BSGAtomicFeatureFlagStore store];
    XCTAssertEqualObjects(store.allFlags, @[]);
    [store addFeatureFlag:@"A" withVariant:@"1"];
    XCTAssertFalse(store.isEmpty);
    XCTAssertEqualObjects(store.allFlags, @[]);
    XCTAssertEqualObjects(AtomicStoreFlags(), (@[@{@"featureFlag": @"A", @"variant": @"1"}]));
}

- (void)testFlagsThatCannotBeSerializedAreSkipped {
    // A lone surrogate cannot be converted to UTF-8, so the flag cannot be serialized as JSON
    const unichar loneSurrogate = 0xD800;
    NSString *unencodable = [NSString stringWithCharacters:&loneSurrogate length:1];
    BSGAtomicFeatureFlagStore *store = [BSGAtomicFeatureFlagStore store];

    [store addFeatureFlag:unencodable withVariant:nil];
    XCTAssertTrue(store.isEmpty);

    [store addFeatureFlag:@"A" withVariant:@"1"];
    [store addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:@"B" variant:unencodable],
                             [BugsnagFeatureFlag flagWithName:@"C"]]];
    // An update that cannot be serialized removes the flag, so a crash report never shows a replaced variant
    [store addFeatureFlag:@"A" withVariant:unencodable];
    XCTAssertEqualObjects(AtomicStoreFlags(), (@[@{@"featureFlag": @"C"}]));
    // The same applies to an update that is part of a batch
    [store addFeatureFlag:@"F" withVariant:@"6"];
    [store addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:@"F" variant:unencodable]]];
    XCTAssertEqualObjects(AtomicStoreFlags(), (@[@{@"featureFlag": @"C"}]));
    // The flag can be added again afterwards, at the end of the list
    [store addFeatureFlag:@"A" withVariant:@"2"];
    XCTAssertEqualObjects(AtomicStoreFlags(), (@[@{@"featureFlag": @"C"},
                                                 @{@"featureFlag": @"A", @"variant": @"2"}]));

    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:unencodable],
                             [BugsnagFeatureFlag flagWithName:@"D" variant:@"4"],
                             [BugsnagFeatureFlag flagWithName:@"E" variant:unencodable]]];
    XCTAssertEqualObjects(AtomicStoreFlags(), (@[@{@"featureFlag": @"D", @"variant": @"4"}]));

    // Only flags that cannot be serialized gives an empty list
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:unencodable]]];
    XCTAssertTrue(store.isEmpty);
    XCTAssertEqualObjects(AtomicStoreFlags(), @[]);
    [store clear:unencodable];
    XCTAssertTrue(store.isEmpty);
}

- (void)testClearingAMissingNameDoesNothing {
    BSGAtomicFeatureFlagStore *store = [BSGAtomicFeatureFlagStore store];
    [store clear:@"missing"];
    XCTAssertTrue(store.isEmpty);
    [store addFeatureFlag:@"A" withVariant:nil];
    [store clear:@"missing"];
    XCTAssertEqualObjects(AtomicStoreFlags(), (@[@{@"featureFlag": @"A"}]));
}

@end

#pragma mark - Several crash-time readers at once

// The original addJSONElement of the writer used by the readers in the test below
static void (*g_originalAddJSONElement)(const BSG_KSCrashReportWriter *writer, const char *name, const char *jsonElement);

/// Lets the test pause a crash-time reader while it is walking the list: signals the thread's
/// "entered" semaphore and waits on its "proceed" semaphore before writing each element.
static void BSGPausingAddJSONElement(const BSG_KSCrashReportWriter *writer, const char *name, const char *jsonElement) {
    NSMutableDictionary *threadDictionary = NSThread.currentThread.threadDictionary;
    dispatch_semaphore_t entered = threadDictionary[@"BSGReaderEntered"];
    dispatch_semaphore_t proceed = threadDictionary[@"BSGReaderProceed"];
    if (entered && proceed) {
        dispatch_semaphore_signal(entered);
        dispatch_semaphore_wait(proceed, DISPATCH_TIME_FOREVER);
    }
    g_originalAddJSONElement(writer, name, jsonElement);
}

@interface BSGAtomicFeatureFlagStoreConcurrentReaderTests : BSGTestCase
@end

@implementation BSGAtomicFeatureFlagStoreConcurrentReaderTests

- (void)setUp {
    [super setUp];
    [[BSGAtomicFeatureFlagStore store] clear];
}

- (void)tearDown {
    [[BSGAtomicFeatureFlagStore store] clear];
    [super tearDown];
}

/// Writes a crash report on a background thread, pausing before each element until proceed is signalled.
static void BSGStartPausedReader(dispatch_group_t group, dispatch_semaphore_t entered, dispatch_semaphore_t proceed,
                                 NSMutableArray *results) {
    dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableDictionary *threadDictionary = NSThread.currentThread.threadDictionary;
        threadDictionary[@"BSGReaderEntered"] = entered;
        threadDictionary[@"BSGReaderProceed"] = proceed;
        NSDictionary *object = bsg_JSONObject(^(BSG_KSCrashReportWriter *writer) {
            g_originalAddJSONElement = writer->addJSONElement;
            BSG_KSCrashReportWriter pausingWriter = *writer;
            pausingWriter.addJSONElement = BSGPausingAddJSONElement;
            pausingWriter.beginObject(&pausingWriter, "");
            BugsnagFeatureFlagsWriteCrashReport(&pausingWriter, true);
            pausingWriter.endContainer(&pausingWriter);
        });
        [threadDictionary removeObjectForKey:@"BSGReaderEntered"];
        [threadDictionary removeObjectForKey:@"BSGReaderProceed"];
        @synchronized (results) {
            [results addObject:object[@"featureFlags"] ?: @[]];
        }
    });
}

- (void)testWriterDoesNotFreeItemsWhileAnotherReaderIsStillReading {
    BSGAtomicFeatureFlagStore *store = [BSGAtomicFeatureFlagStore store];
    [store addFeatureFlag:@"first" withVariant:@"1"];
    [store addFeatureFlag:@"second" withVariant:@"2"];

    NSMutableArray *results = [NSMutableArray array];
    dispatch_group_t readers = dispatch_group_create();
    dispatch_semaphore_t enteredA = dispatch_semaphore_create(0), proceedA = dispatch_semaphore_create(0);
    dispatch_semaphore_t enteredB = dispatch_semaphore_create(0), proceedB = dispatch_semaphore_create(0);

    // Both readers stop on the first item, so both are walking the list at the same time
    BSGStartPausedReader(readers, enteredA, proceedA, results);
    XCTAssertEqual(dispatch_semaphore_wait(enteredA, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)), 0);
    BSGStartPausedReader(readers, enteredB, proceedB, results);
    XCTAssertEqual(dispatch_semaphore_wait(enteredB, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)), 0);

    // Reader A finishes while reader B is still on the first item
    dispatch_semaphore_signal(proceedA);
    XCTAssertEqual(dispatch_semaphore_wait(enteredA, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)), 0);
    dispatch_semaphore_signal(proceedA);

    // A writer that would free the items reader B is reading must wait for it
    __block atomic_bool cleared = false;
    dispatch_semaphore_t writerDone = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [store clear];
        atomic_store(&cleared, true);
        dispatch_semaphore_signal(writerDone);
    });
    [NSThread sleepForTimeInterval:0.3];
    XCTAssertFalse(atomic_load(&cleared), @"The items were freed while a reader was still walking them");

    // Once reader B has finished, the writer frees the list
    dispatch_semaphore_signal(proceedB);
    XCTAssertEqual(dispatch_semaphore_wait(enteredB, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)), 0);
    dispatch_semaphore_signal(proceedB);
    XCTAssertEqual(dispatch_group_wait(readers, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)), 0);
    XCTAssertEqual(dispatch_semaphore_wait(writerDone, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)), 0);
    XCTAssertTrue(atomic_load(&cleared));

    NSArray *expected = @[@{@"featureFlag": @"first", @"variant": @"1"}, @{@"featureFlag": @"second", @"variant": @"2"}];
    XCTAssertEqualObjects(results, (@[expected, expected]));
    XCTAssertEqualObjects(AtomicStoreFlags(), @[]);
}

@end
