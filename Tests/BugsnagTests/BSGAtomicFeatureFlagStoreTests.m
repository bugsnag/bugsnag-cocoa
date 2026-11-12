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

#import <stdatomic.h>

static NSArray<NSDictionary *> * AtomicStoreFlags(void) {
    NSDictionary<NSString *, id> *object = bsg_JSONObject(^(BSG_KSCrashReportWriter *writer) {
        writer->beginObject(writer, "");
        BugsnagFeatureFlagsWriteCrashReport(writer, true);
        writer->endContainer(writer);
    });
    return object[@"featureFlags"];
}

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
    [memoryStore replaceAllFlags:[input reverseObjectEnumerator].allObjects];
    XCTAssertEqualObjects(AtomicStoreFlags(), BSGFeatureFlagStoreToJSON(memoryStore));
    XCTAssertEqualObjects(AtomicStoreFlags(), (@[@{@"featureFlag": @"B"},
                                                 @{@"featureFlag": @"C", @"variant": @"3"},
                                                 @{@"featureFlag": @"A", @"variant": @"1"}]));
}

#pragma mark - Composite store

- (void)testCompositeStoreKeepsSubStoresInAgreement {
    BSGMemoryFeatureFlagStore *memoryStore = [BSGMemoryFeatureFlagStore new];
    BSGMemoryFeatureFlagStore *persistentStore = [BSGMemoryFeatureFlagStore new];
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

    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"D" variant:@"1"],
                             [BugsnagFeatureFlag flagWithName:@"E"],
                             [BugsnagFeatureFlag flagWithName:@"D" variant:@"2"]]];
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

@end
