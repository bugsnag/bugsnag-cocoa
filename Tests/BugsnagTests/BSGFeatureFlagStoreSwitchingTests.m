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

// Earlier releases of the SDK saved one JSON file per flag (BSGLegacyJSONFeatureFlagStore is a copy of
// that store). Upgrading from, or downgrading to, such a release must never report stale flags.
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

// Named new... so that ARC returns the store retained rather than autoreleased: each store must be released (giving up
// the lock on featureflag.lock) before the next launch opens one.
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

/// The previous release's store at launch: its flags are read, then its files are cleared and the current flags added.
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
    XCTAssertTrue([self flagFileExists]);
}

- (void)testUpgradeDowngradeAndUpgradeNeverReportsStaleFlags {
    [self launchWithStore:[self newStore] flags:@[[BugsnagFeatureFlag flagWithName:@"new-1"]]];
    XCTAssertEqualObjects([self launchPreviousReleaseWithFlags:@[[BugsnagFeatureFlag flagWithName:@"old-1"]]], @[]);
    XCTAssertEqualObjects([self launchWithStore:[self newStore] flags:@[[BugsnagFeatureFlag flagWithName:@"new-2"]]],
                          (@[@[@"old-1", NSNull.null]]));
    XCTAssertEqualObjects([self launchWithStore:[self newStore] flags:@[]], (@[@[@"new-2", NSNull.null]]));
    XCTAssertEqual([self jsonFileCount], 0);
}

- (void)testDowngradeToPreviousReleaseAndUpgrade {
    [self launchWithStore:[self newStore] flags:@[[BugsnagFeatureFlag flagWithName:@"new-sdk"]]];

    // The previous release's store cannot decode featureflag.bin, and deletes it when it clears its files at launch
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
