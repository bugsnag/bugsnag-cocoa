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

/// Stands in for the persistent store in the composite store tests: a memory store that can also replace all of its
/// flags. BSGPersistentFeatureFlagStore implements BSGReplaceableFeatureFlagStore once the binary feature flag file is
/// added, and the composite store then calls replaceAllFlags: on it, which a plain BSGMemoryFeatureFlagStore does not
/// have; with this stand-in the tests work whichever version of the composite store they run against.
/// Being a memory store, it orders flags as BSGMemoryFeatureFlagStore does, not as BSGPersistentFeatureFlagStore does,
/// so the tests that use it do not cover the persistent store's order (see
/// testCompositeStoreWithPersistentStoreMovesAFlagThatIsAddedAgainToTheEnd for that).
@interface BSGReplaceablePersistentStoreStandIn : BSGMemoryFeatureFlagStore <BSGReplaceableFeatureFlagStore>
@end

@implementation BSGReplaceablePersistentStoreStandIn

- (void)replaceAllFlags:(NSArray<BugsnagFeatureFlag *> *)featureFlags {
    [self clear];
    [self addFeatureFlags:featureFlags];
}

@end

@interface BSGAtomicFeatureFlagStoreTests : BSGTestCase

@end

@implementation BSGAtomicFeatureFlagStoreTests

- (void)setUp {
    [super setUp];
    BSGAtomicFeatureFlagStore *store = [BSGAtomicFeatureFlagStore store];
    [store clear];
}

- (void)tearDown {
    [[BSGAtomicFeatureFlagStore store] clear];
    [super tearDown];
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

- (void)testVariantThatCannotBeSerializedRemovesTheFlagFromCrashReports {
    // A lone surrogate, as left by truncating a string in the middle of an emoji, cannot be converted to UTF-8
    const unichar loneSurrogate = 0xD800;
    NSString *unencodable = [NSString stringWithCharacters:&loneSurrogate length:1];
    BSGMemoryFeatureFlagStore *memoryStore = [BSGMemoryFeatureFlagStore new];
    BSGCompositeFeatureFlagStore *store = [BSGCompositeFeatureFlagStore storeWithMemoryStore:memoryStore
                                                                             persistentStore:[BSGReplaceablePersistentStoreStandIn new]
                                                                                 atomicStore:[BSGAtomicFeatureFlagStore store]];
    [store addFeatureFlag:@"other" withVariant:@"1"];
    [store addFeatureFlag:@"exp" withVariant:@"control"];
    [store addFeatureFlag:@"exp" withVariant:unencodable];

    // Crash reports leave the flag out rather than report "control", a variant that the app has replaced
    XCTAssertEqualObjects(AtomicStoreFlags(), (@[@{@"featureFlag": @"other", @"variant": @"1"}]));

    // The memory store is the source for handled events and keeps every flag as the app set it, so it still holds
    // exp with the new variant; it does not serialize flags itself.
    NSArray<BugsnagFeatureFlag *> *memoryFlags = memoryStore.allFlags;
    XCTAssertEqualObjects([memoryFlags valueForKey:@"name"], (@[@"other", @"exp"]));
    XCTAssertEqualObjects(memoryFlags.lastObject.variant, unencodable);
}

- (void)testVariantThatCannotBeSerializedRemovesTheFlagWhenAddedTwiceInOneCall {
    // As above, but both values are given in one call
    const unichar loneSurrogate = 0xD800;
    NSString *unencodable = [NSString stringWithCharacters:&loneSurrogate length:1];
    BSGMemoryFeatureFlagStore *memoryStore = [BSGMemoryFeatureFlagStore new];
    BSGCompositeFeatureFlagStore *store = [BSGCompositeFeatureFlagStore storeWithMemoryStore:memoryStore
                                                                             persistentStore:[BSGReplaceablePersistentStoreStandIn new]
                                                                                 atomicStore:[BSGAtomicFeatureFlagStore store]];
    [store addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:@"other" variant:@"1"],
                             [BugsnagFeatureFlag flagWithName:@"exp" variant:@"control"],
                             [BugsnagFeatureFlag flagWithName:@"exp" variant:unencodable]]];
    XCTAssertEqualObjects(AtomicStoreFlags(), (@[@{@"featureFlag": @"other", @"variant": @"1"}]));
    XCTAssertEqualObjects([memoryStore.allFlags valueForKey:@"name"], (@[@"other", @"exp"]));
    XCTAssertEqualObjects(memoryStore.allFlags.lastObject.variant, unencodable);

    // The same through replaceAllFlags:, which builds its new list the same way
    [[BSGAtomicFeatureFlagStore store] replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"exp" variant:@"control"],
                                                         [BugsnagFeatureFlag flagWithName:@"exp" variant:unencodable],
                                                         [BugsnagFeatureFlag flagWithName:@"other" variant:@"1"]]];
    XCTAssertEqualObjects(AtomicStoreFlags(), (@[@{@"featureFlag": @"other", @"variant": @"1"}]));
}

- (void)testCompositeStoreKeepsTheMemoryStoreAndCrashReportsInAgreement {
    BSGMemoryFeatureFlagStore *memoryStore = [BSGMemoryFeatureFlagStore new];
    // A memory store standing in for the persistent store: checking it only shows that the composite store passes
    // every change on to it. The real persistent store's order is checked in the next test.
    BSGReplaceablePersistentStoreStandIn *persistentStore = [BSGReplaceablePersistentStoreStandIn new];
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

- (void)testCompositeStoreWithPersistentStoreMovesAFlagThatIsAddedAgainToTheEnd {
    NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
    XCTAssertTrue([NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES
                                                           attributes:nil error:nil]);
    [self addTeardownBlock:^{
        [NSFileManager.defaultManager removeItemAtPath:directory error:nil];
    }];
    BSGMemoryFeatureFlagStore *memoryStore = [BSGMemoryFeatureFlagStore new];
    BSGPersistentFeatureFlagStore *persistentStore = [[BSGPersistentFeatureFlagStore alloc] initWithStorageDirectory:directory];
    BSGCompositeFeatureFlagStore *store = [BSGCompositeFeatureFlagStore storeWithMemoryStore:memoryStore
                                                                             persistentStore:persistentStore
                                                                                 atomicStore:[BSGAtomicFeatureFlagStore store]];

    // As BSGFeatureFlagStore.h describes: the memory store and crash reports keep A where it was first added, while
    // the persistent store, whose flags are reported with OOM and thermal kill events, moves it to the end
    [store addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:@"A" variant:@"1"],
                             [BugsnagFeatureFlag flagWithName:@"B"],
                             [BugsnagFeatureFlag flagWithName:@"A" variant:@"2"]]];
    NSArray *firstPosition = @[@{@"featureFlag": @"A", @"variant": @"2"}, @{@"featureFlag": @"B"}];
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(memoryStore), firstPosition);
    XCTAssertEqualObjects(AtomicStoreFlags(), firstPosition);
    XCTAssertEqualObjects([store.persistedFlags valueForKey:@"name"], (@[@"B", @"A"]));
    XCTAssertEqualObjects([store.persistedFlags valueForKey:@"variant"], (@[NSNull.null, @"2"]));

    // As when Bugsnag starts: the memory store's flags, which hold each name once, are copied to the other stores, so
    // the persistent store then has the same order
    [store synchronizeFlagsWithMemoryStore];
    XCTAssertEqualObjects(AtomicStoreFlags(), firstPosition);
    XCTAssertEqualObjects([store.persistedFlags valueForKey:@"name"], (@[@"A", @"B"]));
    XCTAssertEqualObjects([store.persistedFlags valueForKey:@"variant"], (@[@"2", NSNull.null]));
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
    dispatch_semaphore_t readerStarted = dispatch_semaphore_create(0);

    // A single reader, acting like the crash handler. It reads at least once after the writers have finished too, so
    // the test never depends on the reader being scheduled while they run.
    dispatch_group_async(readerGroup, queue, ^{
        BOOL finished;
        do {
            finished = atomic_load(&done);
            NSArray<NSDictionary *> *flags = AtomicStoreFlags();
            if (reads++ == 0) {
                dispatch_semaphore_signal(readerStarted);
            }
            if (flags.count == 0) {
                emptyReads++;
            } else if (flags.count < setA.count) {
                shortReads++;
            }
            if (HasDuplicateNames(flags)) {
                duplicateReads++;
            }
        } while (!finished);
    });
    // The writers start once the reader is running, so that they overlap with it even on a busy machine
    XCTAssertEqual(dispatch_semaphore_wait(readerStarted, dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC)), 0);
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

    // Bounded waits, so that a regression fails the test rather than hanging the run
    XCTAssertEqual(dispatch_group_wait(writerGroup, dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC)), 0,
                   @"The writers did not finish");
    atomic_store(&done, true);
    XCTAssertEqual(dispatch_group_wait(readerGroup, dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC)), 0,
                   @"The reader did not finish");

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

typedef void (*BSGAddJSONElementFunction)(const BSG_KSCrashReportWriter *writer, const char *name, const char *jsonElement);
// The original addJSONElement of the writer used by the readers in the test below. Atomic, because every reader thread
// stores it and every reader thread loads it.
static _Atomic(BSGAddJSONElementFunction) g_originalAddJSONElement;
// Set to let paused readers write their remaining elements without stopping
static atomic_bool g_pausingDisabled;
// Every reader started by the running test, so that tearDown can wait until they have all finished
static dispatch_group_t g_allReaders;
// The "proceed" semaphores of the readers started by the running test, so that tearDown can release a reader that a
// failed test left paused. Otherwise it would stay paused, counted as a reader, and break the tests that run after it.
static NSMutableArray<dispatch_semaphore_t> *g_proceedSemaphores;
// How long a paused reader waits at each element before it carries on by itself, so that it can never be stuck for good
static const int64_t BSGPausedReaderTimeout = (int64_t)(120 * NSEC_PER_SEC);

/// Lets the test pause a crash-time reader while it is walking the list: signals the thread's
/// "entered" semaphore and waits on its "proceed" semaphore before writing each element.
static void BSGPausingAddJSONElement(const BSG_KSCrashReportWriter *writer, const char *name, const char *jsonElement) {
    NSMutableDictionary *threadDictionary = NSThread.currentThread.threadDictionary;
    dispatch_semaphore_t entered = threadDictionary[@"BSGReaderEntered"];
    dispatch_semaphore_t proceed = threadDictionary[@"BSGReaderProceed"];
    if (entered && proceed && !atomic_load(&g_pausingDisabled)) {
        dispatch_semaphore_signal(entered);
        dispatch_semaphore_wait(proceed, dispatch_time(DISPATCH_TIME_NOW, BSGPausedReaderTimeout));
    }
    atomic_load(&g_originalAddJSONElement)(writer, name, jsonElement);
}

@interface BSGAtomicFeatureFlagStoreConcurrentReaderTests : BSGTestCase
@end

@implementation BSGAtomicFeatureFlagStoreConcurrentReaderTests

- (void)setUp {
    [super setUp];
    atomic_store(&g_pausingDisabled, false);
    g_proceedSemaphores = [NSMutableArray array];
    g_allReaders = dispatch_group_create();
    [[BSGAtomicFeatureFlagStore store] clear];
}

- (void)tearDown {
    // Readers no longer pause once this is set, so one signal releases a reader that is still paused
    atomic_store(&g_pausingDisabled, true);
    @synchronized (g_proceedSemaphores) {
        for (dispatch_semaphore_t proceed in g_proceedSemaphores) {
            dispatch_semaphore_signal(proceed);
        }
    }
    // A reader still counted when the next test starts would keep that test's retired items from being freed, so a
    // failure here would show up as a misleading failure in the next test instead
    XCTAssertEqual(dispatch_group_wait(g_allReaders, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)), 0,
                   @"A reader started by this test did not finish");
    [[BSGAtomicFeatureFlagStore store] clear];
    [super tearDown];
}

/// Writes a crash report on a background thread, pausing before each element until proceed is signalled.
static void BSGStartPausedReader(dispatch_group_t group, dispatch_semaphore_t entered, dispatch_semaphore_t proceed,
                                 NSMutableArray *results) {
    NSMutableArray<dispatch_semaphore_t> *proceedSemaphores = g_proceedSemaphores;
    @synchronized (proceedSemaphores) {
        [proceedSemaphores addObject:proceed];
    }
    dispatch_group_t allReaders = g_allReaders;
    dispatch_group_enter(allReaders);
    dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableDictionary *threadDictionary = NSThread.currentThread.threadDictionary;
        threadDictionary[@"BSGReaderEntered"] = entered;
        threadDictionary[@"BSGReaderProceed"] = proceed;
        NSDictionary *object = bsg_JSONObject(^(BSG_KSCrashReportWriter *writer) {
            atomic_store(&g_originalAddJSONElement, writer->addJSONElement);
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
        dispatch_group_leave(allReaders);
    });
}

/// Starts a reader that stops on the first item, and waits until it is there.
- (void)startReaderOnTheFirstItemInGroup:(dispatch_group_t)group entered:(dispatch_semaphore_t)entered
                                 proceed:(dispatch_semaphore_t)proceed results:(NSMutableArray *)results {
    BSGStartPausedReader(group, entered, proceed, results);
    XCTAssertEqual(dispatch_semaphore_wait(entered, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)), 0);
}

// BSGAtomicFeatureFlagStoreRetiredItemCount exists only in debug builds, so only the checks on the number of retired
// items are left out of release builds; the rest of each of these tests runs in both.
#if defined(DEBUG) && DEBUG
#define AssertRetiredItemCount(expected, ...) \
    XCTAssertEqual(BSGAtomicFeatureFlagStoreRetiredItemCount(), (size_t)(expected), ##__VA_ARGS__)
#define AssertSomeItemsAreRetired(...) XCTAssertGreaterThan(BSGAtomicFeatureFlagStoreRetiredItemCount(), 0, ##__VA_ARGS__)
#else
#define AssertRetiredItemCount(expected, ...) do {} while (0)
#define AssertSomeItemsAreRetired(...) do {} while (0)
#endif

/// Lets a paused reader write every remaining element without stopping.
static void BSGFinishReader(dispatch_semaphore_t entered, dispatch_semaphore_t proceed, NSUInteger remainingElements) {
    for (NSUInteger i = 0; i < remainingElements; i++) {
        dispatch_semaphore_signal(proceed);
        if (i + 1 < remainingElements) {
            dispatch_semaphore_wait(entered, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));
        }
    }
}

- (void)testTwoConcurrentReadersKeepTheirItemsAndWritersDoNotWait {
    BSGAtomicFeatureFlagStore *store = [BSGAtomicFeatureFlagStore store];
    [store addFeatureFlag:@"first" withVariant:@"1"];
    [store addFeatureFlag:@"second" withVariant:@"2"];
    AssertRetiredItemCount(0);

    NSMutableArray *results = [NSMutableArray array];
    dispatch_group_t readers = dispatch_group_create();
    dispatch_semaphore_t enteredA = dispatch_semaphore_create(0), proceedA = dispatch_semaphore_create(0);
    dispatch_semaphore_t enteredB = dispatch_semaphore_create(0), proceedB = dispatch_semaphore_create(0);

    // Both readers stop on the first item, so both are walking the list at the same time
    [self startReaderOnTheFirstItemInGroup:readers entered:enteredA proceed:proceedA results:results];
    [self startReaderOnTheFirstItemInGroup:readers entered:enteredB proceed:proceedB results:results];

    // Writers do not wait for the readers: the items they unlink are retired, not freed
    [store addFeatureFlag:@"first" withVariant:@"changed"];
    [store clear];
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"third" variant:@"3"]]];
    AssertRetiredItemCount(3, @"first:1, first:changed and second");

    // Reader A finishes while reader B is still on the first item; B still keeps the items from being freed
    BSGFinishReader(enteredA, proceedA, 2);
    [store addFeatureFlag:@"fourth" withVariant:@"4"];
    AssertRetiredItemCount(3);

    // Both readers saw the list as it was when they started, complete
    BSGFinishReader(enteredB, proceedB, 2);
    XCTAssertEqual(dispatch_group_wait(readers, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)), 0);
    NSArray *expected = @[@{@"featureFlag": @"first", @"variant": @"1"}, @{@"featureFlag": @"second", @"variant": @"2"}];
    XCTAssertEqualObjects(results, (@[expected, expected]));

    // Once neither reader is walking the list, the next write frees the retired items
    [store addFeatureFlag:@"fifth" withVariant:nil];
    AssertRetiredItemCount(0);
    XCTAssertEqualObjects(AtomicStoreFlags(), (@[@{@"featureFlag": @"third", @"variant": @"3"},
                                                 @{@"featureFlag": @"fourth", @"variant": @"4"},
                                                 @{@"featureFlag": @"fifth"}]));
}

- (void)testReaderThatNeverFinishesDoesNotBlockWriters {
    BSGAtomicFeatureFlagStore *store = [BSGAtomicFeatureFlagStore store];
    [store addFeatureFlag:@"stuck" withVariant:nil];

    // A reader that does not finish, as when the app crashes again part way through writing a report
    NSMutableArray *results = [NSMutableArray array];
    dispatch_group_t readers = dispatch_group_create();
    dispatch_semaphore_t entered = dispatch_semaphore_create(0), proceed = dispatch_semaphore_create(0);
    [self startReaderOnTheFirstItemInGroup:readers entered:entered proceed:proceed results:results];

    // Writers on several threads all finish; nothing is freed meanwhile
    const NSUInteger iterations = 500;
    dispatch_group_t writers = dispatch_group_create();
    for (int thread = 0; thread < 3; thread++) {
        dispatch_group_async(writers, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            for (NSUInteger i = 0; i < iterations; i++) {
                NSString *name = [NSString stringWithFormat:@"flag-%d-%lu", thread, (unsigned long)(i % 10)];
                switch (i % 4) {
                    case 0: [store addFeatureFlag:name withVariant:@"a"]; break;
                    case 1: [store addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:name variant:@"b"]]]; break;
                    case 2: [store clear:name]; break;
                    default: [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:name variant:@"c"]]]; break;
                }
            }
        });
    }
    XCTAssertEqual(dispatch_group_wait(writers, dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC)), 0,
                   @"Writers must not wait for a reader that never finishes");
    AssertSomeItemsAreRetired(@"Retired items stay pending");

    // Lets the reader finish, so that the test leaves nothing behind; the next write frees everything. The item it is
    // on may lead to items added after it, so it no longer stops before each of them.
    atomic_store(&g_pausingDisabled, true);
    dispatch_semaphore_signal(proceed);
    XCTAssertEqual(dispatch_group_wait(readers, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)), 0);
    // It carries on from the retired item it was on, which was not freed
    XCTAssertEqual(results.count, 1);
    XCTAssertEqualObjects([results.firstObject firstObject], @{@"featureFlag": @"stuck"});
    [store clear];
    AssertRetiredItemCount(0);
}

- (void)testRetiredItemsAreFreed {
    BSGAtomicFeatureFlagStore *store = [BSGAtomicFeatureFlagStore store];
    // Without a reader, every write frees the items it unlinks straight away
    [store addFeatureFlag:@"A" withVariant:@"1"];
    [store addFeatureFlag:@"A" withVariant:@"2"];
    AssertRetiredItemCount(0);
    [store addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:@"B"], [BugsnagFeatureFlag flagWithName:@"B" variant:@"3"]]];
    [store clear:@"A"];
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"C"]]];
    [store clear];
    AssertRetiredItemCount(0);

    // Items retired while a reader is walking the list are all freed by the first write after it finishes, even after
    // many writes
    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"D"]]];
    NSMutableArray *results = [NSMutableArray array];
    dispatch_group_t readers = dispatch_group_create();
    dispatch_semaphore_t entered = dispatch_semaphore_create(0), proceed = dispatch_semaphore_create(0);
    [self startReaderOnTheFirstItemInGroup:readers entered:entered proceed:proceed results:results];
    for (int i = 0; i < 1000; i++) {
        [store addFeatureFlag:@"D" withVariant:[NSString stringWithFormat:@"%d", i]];
    }
    AssertRetiredItemCount(1000);
    BSGFinishReader(entered, proceed, 1);
    XCTAssertEqual(dispatch_group_wait(readers, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)), 0);
    AssertRetiredItemCount(1000, @"Nothing is freed until the next write");
    [store addFeatureFlag:@"E" withVariant:nil];
    AssertRetiredItemCount(0);
    XCTAssertEqualObjects(AtomicStoreFlags(), (@[@{@"featureFlag": @"D", @"variant": @"999"}, @{@"featureFlag": @"E"}]));
    XCTAssertEqualObjects(results, (@[@[@{@"featureFlag": @"D"}]]));
}

@end
