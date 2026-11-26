//
//  FeatureFlagsPersistenceScenario.h
//  Shared scenarios
//
//  Helpers for feature flag persistence scenarios (<storage>/featureFlags/featureflag.bin, or legacy JSON files).
//

#import "Scenario.h"

NS_ASSUME_NONNULL_BEGIN

/// The SDK's featureFlags directory (as in -[BSGFileLocations initWithVersion1]), created if missing.
NSString * FeatureFlagsDirectoryPath(void);

/// Path of featureflag.bin, which the SDK creates when it first has flags to save.
NSString * FeatureFlagsFilePath(void);

/// Writes a flag in the legacy one-JSON-file-per-flag format.
void FeatureFlagsWriteLegacyFile(NSString *name, NSString *_Nullable variant, uint64_t index);

/// Replaces featureflag.bin with invalid content. Modes: random, badSnapshot, truncated, empty, futureVersion.
void FeatureFlagsWriteCorruptFile(NSString *mode);

/// Describes the featureFlags directory, for event metadata.
NSDictionary<NSString *, id> * FeatureFlagsDirectorySummary(void);

/// "long-name-" + 300 x "n" + "-end" (314 characters)
NSString * FeatureFlagsLongName(void);

/// "long-variant-" + 300 x "v" + "-end" (317 characters)
NSString * FeatureFlagsLongVariant(void);

/// A name with emoji, CJK and Cyrillic characters that is longer than 32 bytes in UTF-8.
extern NSString * const FeatureFlagsUnicodeName;
extern NSString * const FeatureFlagsUnicodeVariant;

/// Flags named "bulk-000" ... with variants "bulk-000:v1" ...
NSArray<BugsnagFeatureFlag *> * FeatureFlagsBulk(NSUInteger count);

/// Base class for feature flag persistence scenarios. Events get "flagsDir" and "flagsDirBeforeStart" metadata
/// describing the featureFlags directory when sent and before Bugsnag started.
@interface FeatureFlagsPersistenceScenario : Scenario

@property (nonatomic, copy, nullable) NSDictionary *summaryBeforeStart;

/// Called by -startBugsnag before starting Bugsnag; override to plant files.
- (void)prepareFilesBeforeStart;

/// Sends a handled error with the current flags directory summary in metadata.
- (void)notifyHandledError;

/// Kills the app with SIGKILL after a 1 s delay to let state be flushed; the next launch detects an OOM.
- (void)fakeOutOfMemoryAfterDelay;

@end

NS_ASSUME_NONNULL_END
