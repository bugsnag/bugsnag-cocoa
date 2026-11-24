//
//  FeatureFlagsPersistenceOOMScenarios.m
//  iOSTestApp
//
//  Persistence scenarios using OOM detection (iOS / tvOS only), faked with SIGKILL as in OOMSessionlessScenario.
//  OOM events read flags from featureflag.bin (or legacy JSON) at next launch, so they test the persisted format.
//

#import "FeatureFlagsPersistenceScenario.h"
#import "Logging.h"

#import <signal.h>
#import <unistd.h>

/// Deletes the SDK's temporary featureflag.bin.<UUID>.tmp files.
static void FeatureFlagsRemoveTemporaryFiles(void) {
    NSString *directory = FeatureFlagsDirectoryPath();
    for (NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:nil]) {
        if ([name hasPrefix:@"featureflag.bin."] && [name hasSuffix:@".tmp"]) {
            [NSFileManager.defaultManager removeItemAtPath:[directory stringByAppendingPathComponent:name] error:nil];
        }
    }
}

#pragma mark - 7. OOM event contains the persisted flags

/// Adds 500 flags in bulk, updates one, clears one, adds long / Unicode / empty-variant /
/// nil-variant flags, then is killed.
@interface FeatureFlagsOOMScenario : FeatureFlagsPersistenceScenario
@end

@implementation FeatureFlagsOOMScenario

- (void)configure {
    [super configure];
    self.config.enabledErrorTypes.ooms = YES;
    [self.config addFeatureFlagWithName:@"config-flag" variant:@"config-flag:config"];
}

- (void)run {
    [Bugsnag addFeatureFlags:FeatureFlagsBulk(500)];
    [Bugsnag addFeatureFlagWithName:@"bulk-123" variant:@"bulk-123:updated"];
    [Bugsnag clearFeatureFlagWithName:@"bulk-456"];
    [Bugsnag addFeatureFlagWithName:FeatureFlagsLongName() variant:FeatureFlagsLongVariant()];
    [Bugsnag addFeatureFlagWithName:FeatureFlagsUnicodeName variant:FeatureFlagsUnicodeVariant];
    [Bugsnag addFeatureFlagWithName:@"empty-variant" variant:@""];
    [Bugsnag addFeatureFlagWithName:@"nil-variant" variant:nil];
    [self fakeOutOfMemoryAfterDelay];
}

@end

#pragma mark - 6. Flags do not leak between launches (OOM)

/// Launch 1 adds "old", launch 2 (sending launch 1's OOM) adds "new"; both are killed. Launch 2's OOM event must not
/// contain "old".
@interface FeatureFlagsRelaunchOOMScenario : FeatureFlagsPersistenceScenario
@end

@implementation FeatureFlagsRelaunchOOMScenario

- (void)configure {
    [super configure];
    self.config.enabledErrorTypes.ooms = YES;
    [self.config addFeatureFlagWithName:@"config-flag" variant:@"config-variant"];
}

- (void)run {
    if (self.launchCount <= 1) {
        [Bugsnag addFeatureFlagWithName:@"old" variant:@"launch1"];
        [self fakeOutOfMemoryAfterDelay];
    } else {
        // Let launch 1's OOM event arrive first, keeping events in order.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [Bugsnag addFeatureFlagWithName:@"new" variant:@"launch2"];
            [self fakeOutOfMemoryAfterDelay];
        });
    }
}

@end

#pragma mark - 8. Upgrade from an SDK that stored flags as JSON files

/// An app OOM-killed on an SDK that used JSON files: after start, featureflag.bin is replaced with legacy JSON files
/// and the app killed. The next OOM event must report the JSON flags, which are then deleted.
@interface FeatureFlagsLegacyUpgradeOOMScenario : FeatureFlagsPersistenceScenario
@end

@implementation FeatureFlagsLegacyUpgradeOOMScenario

- (void)configure {
    [super configure];
    self.config.enabledErrorTypes.ooms = YES;
    [self.config addFeatureFlagWithName:@"config-flag" variant:@"config-variant"];
}

- (void)run {
    // Only present in featureflag.bin, which is about to be deleted; must not be reported.
    [Bugsnag addFeatureFlagWithName:@"binary-file-only" variant:@"launch1"];
    // Allow time for state metadata to be flushed to disk (see OOMSessionlessScenario)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        NSString *filePath = FeatureFlagsFilePath();
        [NSFileManager.defaultManager removeItemAtPath:filePath error:nil];
        FeatureFlagsRemoveTemporaryFiles();
        // Written out of index order; the old SDK reported flags sorted by index.
        FeatureFlagsWriteLegacyFile(@"legacy-b", @"variant-b", 2);
        FeatureFlagsWriteLegacyFile(@"legacy-a", nil, 1);
        FeatureFlagsWriteLegacyFile(@"legacy flag/ü 🚩", @"unicode-variant", 3);
        FeatureFlagsWriteLegacyFile(@"legacy-empty", @"", 4);
        FeatureFlagsWriteLegacyFile(@"legacy-first", @"first", 0);
        logInfo(@"Feature flags directory before kill: %@", FeatureFlagsDirectorySummary());
        kill(getpid(), SIGKILL);
    });
}

@end

#pragma mark - 9. Stale legacy JSON files alongside featureflag.bin (OOM)

/// As FeatureFlagsStaleJSONScenario, but launch 1 is OOM-killed so JSON files are planted before its OOM event is
/// built. With both kinds of file present neither is used, so the event has no flags.
@interface FeatureFlagsStaleJSONOOMScenario : FeatureFlagsPersistenceScenario
@end

@implementation FeatureFlagsStaleJSONOOMScenario

- (void)configure {
    [super configure];
    self.config.enabledErrorTypes.ooms = YES;
    [self.config addFeatureFlagWithName:@"config-flag" variant:@"config-variant"];
}

- (void)prepareFilesBeforeStart {
    BOOL isDirectory = NO;
    if ([NSFileManager.defaultManager fileExistsAtPath:FeatureFlagsFilePath() isDirectory:&isDirectory] && !isDirectory) {
        FeatureFlagsWriteLegacyFile(@"stale-flag", @"stale", 0);
        FeatureFlagsWriteLegacyFile(@"stale-flag-2", nil, 1);
    }
}

- (void)run {
    [Bugsnag addFeatureFlagWithName:@"launch1-flag" variant:@"launch1"];
    [self fakeOutOfMemoryAfterDelay];
}

@end

#pragma mark - 10. Corrupt featureflag.bin (OOM)

/// featureflag.bin is corrupted before launch 1 starts Bugsnag; later flags must still be persisted and in launch 2's
/// OOM event.
@interface FeatureFlagsCorruptFileOOMScenario : FeatureFlagsPersistenceScenario
@end

@implementation FeatureFlagsCorruptFileOOMScenario

- (void)configure {
    [super configure];
    self.config.enabledErrorTypes.ooms = YES;
    [self.config addFeatureFlagWithName:@"config-flag" variant:@"config-variant"];
}

- (void)prepareFilesBeforeStart {
    if (self.launchCount <= 1) {
        NSString *mode = self.args.firstObject.length ? self.args.firstObject : @"random";
        FeatureFlagsWriteCorruptFile(mode);
    }
}

- (void)run {
    [Bugsnag addFeatureFlagWithName:@"after-start" variant:@"current"];
    [Bugsnag addFeatureFlags:FeatureFlagsBulk(3)];
    [Bugsnag clearFeatureFlagWithName:@"bulk-001"];
    [self fakeOutOfMemoryAfterDelay];
}

@end
