//
//  FeatureFlagsPersistenceScenario.m
//  Shared scenarios
//
//  End-to-end scenarios for feature flag persistence (flags.bin, and the migration
//  from / downgrade to the legacy format of one JSON file per flag).
//
//  Scenarios that rely on Out Of Memory detection are in FeatureFlagsPersistenceOOMScenarios.m
//  (iOS only).
//

#import "FeatureFlagsPersistenceScenario.h"
#import "Logging.h"

#import <signal.h>
#import <unistd.h>

// Must match BSGPersistentFeatureFlagStore.m
static const uint32_t FeatureFlagFileMagic = 0x46465342; // "BSFF"
static const uint32_t FeatureFlagFileVersion = 1;

struct feature_flag_file_header {
    uint32_t magic;
    uint32_t version;
    uint32_t slotCapacity;
    uint32_t reserved;
    uint64_t active; // (length << 1) | slot
    uint64_t reserved2;
};

#pragma mark - Helpers

NSString * FeatureFlagsDirectoryPath(void) {
    // Mirrors cachesDirectory() and bugsnagPath() in BSGFileLocations.m
#if TARGET_OS_TV
    NSSearchPathDirectory directory = NSCachesDirectory;
#else
    NSSearchPathDirectory directory = NSApplicationSupportDirectory;
#endif
    NSURL *url = [NSFileManager.defaultManager URLForDirectory:directory inDomain:NSUserDomainMask
                                             appropriateForURL:nil create:NO error:nil];
    NSString *path = [NSString stringWithFormat:@"%@/com.bugsnag.Bugsnag/%@/v1/featureFlags", url.path,
                      NSBundle.mainBundle.bundleIdentifier ?: NSProcessInfo.processInfo.processName];
    NSError *error = nil;
    if (![NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES
                                                  attributes:nil error:&error]) {
        logError(@"Could not create %@: %@", path, error);
    }
    return path;
}

NSString * FeatureFlagsBinPath(void) {
    return [FeatureFlagsDirectoryPath() stringByAppendingPathComponent:@"flags.bin"];
}

void FeatureFlagsWriteLegacyFile(NSString *name, NSString *variant, uint64_t index) {
    // Format and file naming used by BSGPersistentFeatureFlagStore before flags.bin was introduced.
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    json[@"featureFlag"] = name;
    json[@"index"] = @(index);
    if (variant) {
        json[@"variant"] = variant;
    }
    NSString *fileName = [name stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.alphanumericCharacterSet];
    NSString *path = [FeatureFlagsDirectoryPath() stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"%@.json", fileName]];
    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
    if (![data writeToFile:path atomically:YES]) {
        logError(@"Could not write legacy feature flag file %@", path);
    }
    logInfo(@"Wrote legacy feature flag file %@", path);
}

void FeatureFlagsWriteCorruptFile(NSString *mode) {
    NSString *path = FeatureFlagsBinPath();
    [NSFileManager.defaultManager removeItemAtPath:path error:nil];

    NSMutableData *data = nil;
    const size_t fileSize = 4096;
    struct feature_flag_file_header header = {
        .magic = FeatureFlagFileMagic,
        .version = FeatureFlagFileVersion,
        .slotCapacity = (uint32_t)(fileSize - sizeof(header)) / 2,
        .active = (64 << 1) | 0,
    };

    if ([mode isEqualToString:@"empty"]) {
        data = [NSMutableData data];
    } else if ([mode isEqualToString:@"badSnapshot"]) {
        // A valid header whose active snapshot contains garbage (entry lengths of 0xFFFFFFFF)
        data = [NSMutableData dataWithLength:fileSize];
        memset(data.mutableBytes, 0xFF, fileSize);
        memcpy(data.mutableBytes, &header, sizeof(header));
    } else if ([mode isEqualToString:@"truncated"]) {
        // A valid header that describes a file much larger than the one on disk
        header.slotCapacity = 1000000;
        data = [NSMutableData dataWithLength:fileSize];
        memcpy(data.mutableBytes, &header, sizeof(header));
    } else if ([mode isEqualToString:@"futureVersion"]) {
        // As if written by a newer SDK with an incompatible format
        header.version = 99;
        data = [NSMutableData dataWithLength:fileSize];
        memset(data.mutableBytes, 'x', fileSize);
        memcpy(data.mutableBytes, &header, sizeof(header));
    } else {
        // random
        data = [NSMutableData dataWithLength:fileSize];
        arc4random_buf(data.mutableBytes, fileSize);
        ((uint8_t *)data.mutableBytes)[0] = 0; // Guarantee the magic number is wrong
    }

    if (![data writeToFile:path atomically:NO]) {
        logError(@"Could not write %@", path);
    }
    logInfo(@"Wrote corrupt (%@) %@", mode, path);
}

NSDictionary<NSString *, id> * FeatureFlagsDirectorySummary(void) {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSString *directory = FeatureFlagsDirectoryPath();
    NSArray<NSString *> *entries = [[fileManager contentsOfDirectoryAtPath:directory error:nil]
                                    sortedArrayUsingSelector:@selector(compare:)] ?: @[];
    NSMutableArray<NSString *> *jsonFiles = [NSMutableArray array];
    for (NSString *entry in entries) {
        if ([entry.pathExtension isEqualToString:@"json"]) {
            [jsonFiles addObject:entry];
        }
    }

    NSString *binPath = FeatureFlagsBinPath();
    BOOL isDirectory = NO;
    BOOL exists = [fileManager fileExistsAtPath:binPath isDirectory:&isDirectory];
    BOOL validHeader = NO;
    if (exists && !isDirectory) {
        NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:binPath];
        NSData *data = [handle readDataOfLength:sizeof(struct feature_flag_file_header)];
        [handle closeFile];
        if (data.length == sizeof(struct feature_flag_file_header)) {
            struct feature_flag_file_header header;
            memcpy(&header, data.bytes, sizeof(header));
            validHeader = header.magic == FeatureFlagFileMagic && header.version == FeatureFlagFileVersion;
        }
    }

    return @{
        @"entries": entries,
        @"jsonFiles": jsonFiles,
        @"jsonFileCount": @(jsonFiles.count),
        @"flagsBinExists": exists ? @YES : @NO,
        @"flagsBinIsDirectory": (exists && isDirectory) ? @YES : @NO,
        @"flagsBinHasValidHeader": validHeader ? @YES : @NO,
    };
}

NSString * FeatureFlagsLongName(void) {
    return [NSString stringWithFormat:@"long-name-%@-end",
            [@"" stringByPaddingToLength:300 withString:@"n" startingAtIndex:0]];
}

NSString * FeatureFlagsLongVariant(void) {
    return [NSString stringWithFormat:@"long-variant-%@-end",
            [@"" stringByPaddingToLength:300 withString:@"v" startingAtIndex:0]];
}

NSString * const FeatureFlagsUnicodeName = @"🚩 機能フラグ/功能标志/флаг";
NSString * const FeatureFlagsUnicodeVariant = @"变体-🎉-ヴァリアント";

NSArray<BugsnagFeatureFlag *> * FeatureFlagsBulk(NSUInteger count) {
    NSMutableArray *flags = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i = 0; i < count; i++) {
        NSString *name = [NSString stringWithFormat:@"bulk-%03lu", (unsigned long)i];
        [flags addObject:[BugsnagFeatureFlag flagWithName:name variant:[name stringByAppendingString:@":v1"]]];
    }
    return flags;
}

#pragma mark - Base class

@implementation FeatureFlagsPersistenceScenario

- (void)configure {
    [super configure];
    self.config.autoTrackSessions = NO;
    __weak typeof(self) weakSelf = self;
    [self.config addOnSendErrorBlock:^BOOL(BugsnagEvent *event) {
        [event addMetadata:FeatureFlagsDirectorySummary() toSection:@"flagsDir"];
        NSDictionary *summaryBeforeStart = weakSelf.summaryBeforeStart;
        if (summaryBeforeStart) {
            [event addMetadata:summaryBeforeStart toSection:@"flagsDirBeforeStart"];
        }
        return YES;
    }];
}

- (void)prepareFilesBeforeStart {
}

- (void)startBugsnag {
    [self prepareFilesBeforeStart];
    self.summaryBeforeStart = FeatureFlagsDirectorySummary();
    logInfo(@"Feature flags directory before start: %@", self.summaryBeforeStart);
    [super startBugsnag];
}

- (void)run {
    [self doesNotRecognizeSelector:_cmd];
}

- (void)notifyHandledError {
    NSString *message = NSStringFromClass([self class]);
    [Bugsnag notifyError:[NSError errorWithDomain:@"FeatureFlagsPersistence" code:1
                                         userInfo:@{NSLocalizedDescriptionKey: message}]];
}

- (void)fakeOutOfMemoryAfterDelay {
    // Allow time for state metadata to be flushed to disk (see OOMSessionlessScenario)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        logInfo(@"Faking an OOM with SIGKILL");
        kill(getpid(), SIGKILL);
    });
}

@end

#pragma mark - 1. API behaviour

/// Adds, overwrites and clears flags, then sends a handled error.
@interface FeatureFlagsAPIBehaviourScenario : FeatureFlagsPersistenceScenario
@end

@implementation FeatureFlagsAPIBehaviourScenario

- (void)configure {
    [super configure];
    [self.config addFeatureFlagWithName:@"config-flag" variant:@"config-variant"];
    [self.config addFeatureFlagWithName:@"config-cleared"];
}

- (void)run {
    [Bugsnag addFeatureFlagWithName:@"flag-a" variant:@"a1"];
    [Bugsnag addFeatureFlagWithName:@"flag-b"];
    [Bugsnag addFeatureFlagWithName:@"flag-c" variant:@"c1"];
    // Overwrite: variant changed, nil -> variant, variant -> nil
    [Bugsnag addFeatureFlagWithName:@"flag-a" variant:@"a2"];
    [Bugsnag addFeatureFlagWithName:@"flag-b" variant:@"b1"];
    [Bugsnag addFeatureFlagWithName:@"flag-c"];
    [Bugsnag addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:@"flag-d" variant:@"d1"],
                               [BugsnagFeatureFlag flagWithName:@"flag-e"]]];
    [Bugsnag clearFeatureFlagWithName:@"flag-e"];
    [Bugsnag clearFeatureFlagWithName:@"config-cleared"];
    [Bugsnag clearFeatureFlagWithName:@"does-not-exist"];
    [self notifyHandledError];
}

@end

#pragma mark - 2. Bulk flags then a crash

/// Adds 500 flags in one call, updates one, clears one, then calls abort().
@interface FeatureFlagsBulkCrashScenario : FeatureFlagsPersistenceScenario
@end

@implementation FeatureFlagsBulkCrashScenario

- (void)run {
    [Bugsnag addFeatureFlags:FeatureFlagsBulk(500)];
    [Bugsnag addFeatureFlagWithName:@"bulk-123" variant:@"bulk-123:updated"];
    [Bugsnag clearFeatureFlagWithName:@"bulk-456"];
    abort();
}

@end

#pragma mark - 3. Clear all flags then a crash

@interface FeatureFlagsClearAllCrashScenario : FeatureFlagsPersistenceScenario
@end

@implementation FeatureFlagsClearAllCrashScenario

- (void)configure {
    [super configure];
    [self.config addFeatureFlagWithName:@"config-flag" variant:@"config-variant"];
}

- (void)run __attribute__((noreturn)) {
    [Bugsnag addFeatureFlagWithName:@"flag-a" variant:@"a1"];
    [Bugsnag addFeatureFlags:FeatureFlagsBulk(10)];
    [Bugsnag clearFeatureFlags];
    @throw [NSException exceptionWithName:NSGenericException reason:@"FeatureFlagsClearAllCrashScenario"
                                 userInfo:nil];
}

@end

#pragma mark - 4. Unusual names and variants

/// Long, Unicode, empty-variant and nil-variant flags, reported in a handled error and then a crash.
@interface FeatureFlagsUnusualValuesScenario : FeatureFlagsPersistenceScenario
@end

@implementation FeatureFlagsUnusualValuesScenario

- (void)run {
    [Bugsnag addFeatureFlagWithName:FeatureFlagsLongName() variant:FeatureFlagsLongVariant()];
    [Bugsnag addFeatureFlagWithName:FeatureFlagsUnicodeName variant:FeatureFlagsUnicodeVariant];
    [Bugsnag addFeatureFlagWithName:@"empty-variant" variant:@""];
    [Bugsnag addFeatureFlagWithName:@"nil-variant" variant:nil];
    [self waitForEventDelivery:^{
        [self notifyHandledError];
    } andThen:^{
        @throw [NSException exceptionWithName:NSGenericException reason:@"FeatureFlagsUnusualValuesScenario"
                                     userInfo:nil];
    }];
}

@end

#pragma mark - 5. Concurrent changes while crashing

/// Four threads add and clear flags while the main thread crashes.
///
/// Every flag's variant is "<name>:<counter>" so that each reported entry can be checked for consistency.
@interface FeatureFlagsConcurrentCrashScenario : FeatureFlagsPersistenceScenario
@end

@implementation FeatureFlagsConcurrentCrashScenario

- (void)configure {
    [super configure];
    [self.config addFeatureFlagWithName:@"config-flag" variant:@"config-flag:config"];
}

- (void)run {
    [Bugsnag addFeatureFlagWithName:@"main-flag" variant:@"main-flag:0"];
    for (int t = 0; t < 4; t++) {
        NSThread *thread = [[NSThread alloc] initWithBlock:^{
            for (unsigned long i = 1; ; i++) {
                @autoreleasepool {
                    NSString *name = [NSString stringWithFormat:@"t%d-f%02lu", t, i % 16];
                    if (i % 5 == 0) {
                        [Bugsnag clearFeatureFlagWithName:name];
                    } else {
                        [Bugsnag addFeatureFlagWithName:name
                                                variant:[NSString stringWithFormat:@"%@:%lu", name, i]];
                    }
                }
            }
        }];
        thread.name = [NSString stringWithFormat:@"FeatureFlagsThread%d", t];
        [thread start];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(300 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        abort();
    });
}

@end

#pragma mark - 6. Flags do not leak between launches

/// Launch 1 adds "old"; after being killed and relaunched, launch 2 adds "new". Both send a handled error.
@interface FeatureFlagsRelaunchScenario : FeatureFlagsPersistenceScenario
@end

@implementation FeatureFlagsRelaunchScenario

- (void)configure {
    [super configure];
    [self.config addFeatureFlagWithName:@"config-flag" variant:@"config-variant"];
}

- (void)run {
    if (self.launchCount <= 1) {
        [Bugsnag addFeatureFlagWithName:@"old" variant:@"launch1"];
        // Lets the test wait for launch 1 to have run before the app is killed
        [self notifyHandledError];
    } else {
        [Bugsnag addFeatureFlagWithName:@"new" variant:@"launch2"];
        [self notifyHandledError];
    }
}

@end

#pragma mark - 8. Migration from legacy JSON files

/// Plants legacy JSON flag files (and no flags.bin) before Bugsnag starts, as left by an older SDK.
@interface FeatureFlagsLegacyMigrationScenario : FeatureFlagsPersistenceScenario
@end

@implementation FeatureFlagsLegacyMigrationScenario

- (void)configure {
    [super configure];
    [self.config addFeatureFlagWithName:@"config-flag" variant:@"config-variant"];
}

- (void)prepareFilesBeforeStart {
    [NSFileManager.defaultManager removeItemAtPath:FeatureFlagsBinPath() error:nil];
    FeatureFlagsWriteLegacyFile(@"legacy-a", @"variant-a", 0);
    FeatureFlagsWriteLegacyFile(@"legacy-b", nil, 1);
    FeatureFlagsWriteLegacyFile(@"legacy flag/ü 🚩", @"", 2);
}

- (void)run {
    [Bugsnag addFeatureFlagWithName:@"current" variant:@"current-variant"];
    [self notifyHandledError];
}

@end

#pragma mark - 9. Stale legacy JSON files alongside flags.bin

/// At launch 1, flags.bin does not exist and Bugsnag creates it.
/// At subsequent launches, legacy JSON files are planted next to the existing flags.bin before
/// Bugsnag starts, as if a file could not be deleted after a downgrade to an SDK that stored one
/// JSON file per flag. Both are discarded, and the JSON files are deleted.
@interface FeatureFlagsStaleJSONScenario : FeatureFlagsPersistenceScenario
@end

@implementation FeatureFlagsStaleJSONScenario

- (void)configure {
    [super configure];
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
    if (self.launchCount <= 1) {
        [Bugsnag addFeatureFlagWithName:@"launch1-flag" variant:@"launch1"];
        // Lets the test wait for launch 1 to have run before the app is killed
        [self notifyHandledError];
    } else {
        [Bugsnag addFeatureFlagWithName:@"launch2-flag" variant:@"launch2"];
        [self notifyHandledError];
    }
}

@end

#pragma mark - 10. Corrupt flags.bin

/// Replaces flags.bin with invalid content before Bugsnag starts at launch 1.
/// The scenario mode selects the kind of corruption; see FeatureFlagsWriteCorruptFile().
@interface FeatureFlagsCorruptFileScenario : FeatureFlagsPersistenceScenario
@end

@implementation FeatureFlagsCorruptFileScenario

- (void)configure {
    [super configure];
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
    [self notifyHandledError];
}

@end

#pragma mark - 11. A directory where flags.bin should be

/// Creates a (non-empty) directory at the flags.bin path before Bugsnag starts.
@interface FeatureFlagsDirectoryAtFilePathScenario : FeatureFlagsPersistenceScenario
@end

@implementation FeatureFlagsDirectoryAtFilePathScenario

- (void)configure {
    [super configure];
    [self.config addFeatureFlagWithName:@"config-flag" variant:@"config-variant"];
}

- (void)prepareFilesBeforeStart {
    NSString *path = FeatureFlagsBinPath();
    BOOL isDirectory = NO;
    if ([NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory) {
        return;
    }
    [NSFileManager.defaultManager removeItemAtPath:path error:nil];
    NSError *error = nil;
    if (![NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES
                                                  attributes:nil error:&error]) {
        logError(@"Could not create directory %@: %@", path, error);
    }
    [[@"occupied" dataUsingEncoding:NSUTF8StringEncoding]
     writeToFile:[path stringByAppendingPathComponent:@"occupant.txt"] atomically:NO];
}

- (void)addFlags {
    [Bugsnag addFeatureFlagWithName:@"after-start" variant:@"current"];
    [Bugsnag addFeatureFlags:FeatureFlagsBulk(3)];
    [Bugsnag addFeatureFlagWithName:@"bulk-000" variant:@"bulk-000:updated"];
    [Bugsnag clearFeatureFlagWithName:@"bulk-001"];
}

- (void)run {
    [self addFlags];
    [self notifyHandledError];
}

@end

@interface FeatureFlagsDirectoryAtFilePathCrashScenario : FeatureFlagsDirectoryAtFilePathScenario
@end

@implementation FeatureFlagsDirectoryAtFilePathCrashScenario

- (void)run __attribute__((noreturn)) {
    [self addFlags];
    @throw [NSException exceptionWithName:NSGenericException reason:@"FeatureFlagsDirectoryAtFilePathCrashScenario"
                                 userInfo:nil];
}

@end
