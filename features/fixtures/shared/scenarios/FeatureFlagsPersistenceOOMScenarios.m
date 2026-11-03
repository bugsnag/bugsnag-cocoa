//
//  FeatureFlagsPersistenceOOMScenarios.m
//  iOSTestApp
//
//  Feature flag persistence scenarios that rely on Out Of Memory detection, which is only
//  available on iOS / tvOS. The OOM is faked with SIGKILL, as in OOMSessionlessScenario.
//
//  The flags in an OOM event are read from flags.bin (or legacy JSON files) at next launch,
//  unlike crash reports and handled errors, so these scenarios exercise the persisted format.
//

#import "FeatureFlagsPersistenceScenario.h"
#import "Logging.h"

#import <signal.h>
#import <unistd.h>

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

/// Launch 1 adds "old" and is killed. Launch 2 (which sends the OOM event for launch 1) adds "new"
/// and is killed. The OOM event for launch 2 must not contain "old".
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
        // Allow time for the OOM event from launch 1 to be delivered, so the events arrive in order.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [Bugsnag addFeatureFlagWithName:@"new" variant:@"launch2"];
            [self fakeOutOfMemoryAfterDelay];
        });
    }
}

@end

#pragma mark - 8. Upgrade from an SDK that stored flags as JSON files

/// Simulates an app that was OOM-killed while running an SDK that stored one JSON file per flag:
/// after Bugsnag has started (so OOM detection state is in place), flags.bin is deleted and legacy
/// JSON files are written in its place, then the app is killed. At next launch the OOM event should
/// contain the flags from the JSON files, which should then be deleted.
@interface FeatureFlagsLegacyUpgradeOOMScenario : FeatureFlagsPersistenceScenario
@end

@implementation FeatureFlagsLegacyUpgradeOOMScenario

- (void)configure {
    [super configure];
    self.config.enabledErrorTypes.ooms = YES;
    [self.config addFeatureFlagWithName:@"config-flag" variant:@"config-variant"];
}

- (void)run {
    // Only present in flags.bin, which is about to be deleted; must not be reported.
    [Bugsnag addFeatureFlagWithName:@"mmap-only" variant:@"launch1"];
    // Allow time for state metadata to be flushed to disk (see OOMSessionlessScenario)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        NSString *binPath = FeatureFlagsBinPath();
        [NSFileManager.defaultManager removeItemAtPath:binPath error:nil];
        [NSFileManager.defaultManager removeItemAtPath:[binPath stringByAppendingString:@".tmp"] error:nil];
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

#pragma mark - 9. Stale legacy JSON files alongside flags.bin (OOM)

/// As FeatureFlagsStaleJSONScenario, but launch 1 is OOM-killed so that the JSON files are
/// planted before an OOM event is generated from the persisted flags. Because flags.bin and JSON
/// files are found together, neither is used, and the OOM event has no flags.
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
    if ([NSFileManager.defaultManager fileExistsAtPath:FeatureFlagsBinPath() isDirectory:&isDirectory] && !isDirectory) {
        FeatureFlagsWriteLegacyFile(@"stale-flag", @"stale", 0);
        FeatureFlagsWriteLegacyFile(@"stale-flag-2", nil, 1);
    }
}

- (void)run {
    [Bugsnag addFeatureFlagWithName:@"launch1-flag" variant:@"launch1"];
    [self fakeOutOfMemoryAfterDelay];
}

@end

#pragma mark - 10. Corrupt flags.bin (OOM)

/// flags.bin is corrupted before Bugsnag starts at launch 1; flags added afterwards must still be
/// persisted and reported in the OOM event at launch 2.
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
