//
//  BSGFeatureFlagStoreSwitchingTests.m
//  Bugsnag
//
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import "BSGTestCase.h"

#import "BSGLegacyJSONFeatureFlagStore.h"
#import "BSGPersistentFeatureFlagStore.h"
#import "BugsnagFeatureFlag.h"

static NSArray * FlagsToArray(NSArray<BugsnagFeatureFlag *> *flags) {
    NSMutableArray *result = [NSMutableArray array];
    for (BugsnagFeatureFlag *flag in flags) {
        [result addObject:@[flag.name, flag.variant ?: NSNull.null]];
    }
    return result;
}

// Earlier releases saved one JSON file per flag (see BSGLegacyJSONFeatureFlagStore). Upgrading from or downgrading to
// them must never report stale flags.
@interface BSGFeatureFlagStoreSwitchingTests : BSGTestCase

@property (nonatomic) NSString *directory;

@end

@implementation BSGFeatureFlagStoreSwitchingTests

- (void)setUp {
    [super setUp];
    self.directory = [NSTemporaryDirectory() stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"BSGFeatureFlagStoreSwitchingTests-%@", NSUUID.UUID.UUIDString]];
    [NSFileManager.defaultManager createDirectoryAtPath:self.directory withIntermediateDirectories:YES attributes:nil error:nil];
}

- (void)tearDown {
    [NSFileManager.defaultManager removeItemAtPath:self.directory error:nil];
    [super tearDown];
}

// Named new... so ARC returns the store retained: each must be released (freeing featureflag.lock) before the next
// launch.
- (BSGPersistentFeatureFlagStore *)newStore {
    return [[BSGPersistentFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
}

- (BSGLegacyJSONFeatureFlagStore *)openPreviousReleaseStore {
    return [[BSGLegacyJSONFeatureFlagStore alloc] initWithStorageDirectory:self.directory];
}

- (BOOL)flagFileExists {
    return [NSFileManager.defaultManager fileExistsAtPath:[self.directory stringByAppendingPathComponent:@"featureflag.bin"]];
}

- (NSUInteger)jsonFileCount {
    NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.directory error:nil];
    return [files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"pathExtension == 'json'"]].count;
}

/// Simulates a launch: the previous launch's flags are read, then replaced with the current ones.
- (NSArray *)launchWithStore:(id<BSGReplaceableFeatureFlagStore>)store flags:(NSArray<BugsnagFeatureFlag *> *)flags {
    NSArray *previous = FlagsToArray(store.allFlags);
    [store replaceAllFlags:flags];
    return previous;
}

/// The previous release's store at launch: reads its flags, clears its files and adds the current flags.
- (NSArray *)launchPreviousReleaseWithFlags:(NSArray<BugsnagFeatureFlag *> *)flags {
    BSGLegacyJSONFeatureFlagStore *store = [self openPreviousReleaseStore];
    NSArray *previous = FlagsToArray(store.allFlags);
    [store clear];
    [store addFeatureFlags:flags];
    return previous;
}

- (void)testUpgradeImportsFlags {
    [self launchPreviousReleaseWithFlags:@[[BugsnagFeatureFlag flagWithName:@"a" variant:@"1"],
                                           [BugsnagFeatureFlag flagWithName:@"b"]]];
    XCTAssertEqual([self jsonFileCount], 2);

    XCTAssertEqualObjects([self launchWithStore:[self newStore] flags:@[]], (@[@[@"a", @"1"], @[@"b", NSNull.null]]));
    XCTAssertEqual([self jsonFileCount], 0);
    // Imported flags are copied into featureflag.bin at start, even if the launch has no flags
    XCTAssertTrue([self flagFileExists]);
    XCTAssertEqualObjects(FlagsToArray([self newStore].allFlags), (@[@[@"a", @"1"], @[@"b", NSNull.null]]));

    [self launchPreviousReleaseWithFlags:@[[BugsnagFeatureFlag flagWithName:@"c" variant:@"3"]]];
    XCTAssertEqualObjects([self launchWithStore:[self newStore] flags:@[[BugsnagFeatureFlag flagWithName:@"d"]]],
                          (@[@[@"c", @"3"]]));
    XCTAssertEqual([self jsonFileCount], 0);
    XCTAssertTrue([self flagFileExists]);
    // The imported flag is kept ahead of the launch's own flags
    XCTAssertEqualObjects(FlagsToArray([self newStore].allFlags), (@[@[@"c", @"3"], @[@"d", NSNull.null]]));

    // A later launch replaces them like any persisted flags
    XCTAssertEqualObjects([self launchWithStore:[self newStore] flags:@[[BugsnagFeatureFlag flagWithName:@"e"]]],
                          (@[@[@"c", @"3"], @[@"d", NSNull.null]]));
    XCTAssertEqualObjects(FlagsToArray([self newStore].allFlags), (@[@[@"e", NSNull.null]]));
}

- (void)testUpgradeDowngradeAndUpgradeAgain {
    [self launchWithStore:[self newStore] flags:@[[BugsnagFeatureFlag flagWithName:@"new-1"]]];
    XCTAssertEqualObjects([self launchPreviousReleaseWithFlags:@[[BugsnagFeatureFlag flagWithName:@"old-1"]]], @[]);
    XCTAssertEqualObjects([self launchWithStore:[self newStore] flags:@[[BugsnagFeatureFlag flagWithName:@"new-2"]]],
                          (@[@[@"old-1", NSNull.null]]));
    // The previous release's flag is copied into featureflag.bin with the launch's own
    XCTAssertEqualObjects([self launchWithStore:[self newStore] flags:@[]],
                          (@[@[@"old-1", NSNull.null], @[@"new-2", NSNull.null]]));
    XCTAssertEqualObjects([self launchWithStore:[self newStore] flags:@[]], @[]);
    XCTAssertEqual([self jsonFileCount], 0);
}

- (void)testDowngradeToPreviousReleaseAndUpgrade {
    [self launchWithStore:[self newStore] flags:@[[BugsnagFeatureFlag flagWithName:@"new-sdk"]]];

    // The previous release's store can't decode featureflag.bin and deletes it when clearing at launch
    BSGLegacyJSONFeatureFlagStore *previousRelease = [self openPreviousReleaseStore];
    XCTAssertEqualObjects(previousRelease.allFlags, @[]);
    [previousRelease clear];
    [previousRelease addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:@"old-sdk" variant:@"1"]]];
    XCTAssertFalse([self flagFileExists]);
    XCTAssertEqual([self jsonFileCount], 1);

    XCTAssertEqualObjects([self launchWithStore:[self newStore] flags:@[]], (@[@[@"old-sdk", @"1"]]));
    XCTAssertEqual([self jsonFileCount], 0);
}

@end
