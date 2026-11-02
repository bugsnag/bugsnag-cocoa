//
//  FeatureFlagsPersistenceScenario.h
//  Shared scenarios
//
//  Helpers for scenarios that exercise how feature flags are persisted to
//  <storage>/featureFlags/flags.bin (and, in older SDKs, one JSON file per flag).
//

#import "Scenario.h"

NS_ASSUME_NONNULL_BEGIN

/// The SDK's featureFlags storage directory, mirroring -[BSGFileLocations initWithVersion1].
/// The directory is created if it does not already exist.
NSString * FeatureFlagsDirectoryPath(void);

/// The path of the memory-mapped feature flag file.
NSString * FeatureFlagsBinPath(void);

/// Writes a feature flag file in the format used by SDK versions that stored one JSON file per flag.
void FeatureFlagsWriteLegacyFile(NSString *name, NSString *_Nullable variant, uint64_t index);

/// Replaces flags.bin with invalid content. Modes: random, badSnapshot, truncated, empty, futureVersion.
void FeatureFlagsWriteCorruptFile(NSString *mode);

/// Describes the contents of the featureFlags directory, for adding to an event's metadata.
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

/// Base class for feature flag persistence scenarios.
///
/// Every event gets a "flagsDir" metadata section describing the featureFlags directory at the
/// time the event is sent, and a "flagsDirBeforeStart" section describing it before Bugsnag started.
@interface FeatureFlagsPersistenceScenario : Scenario

@property (nonatomic, copy, nullable) NSDictionary *summaryBeforeStart;

/// Called by -startBugsnag before Bugsnag is started. Subclasses override this to plant files.
- (void)prepareFilesBeforeStart;

/// Sends a handled error with the current flags directory summary in metadata.
- (void)notifyHandledError;

/// Kills the app with SIGKILL after allowing time for state to be flushed, which the SDK
/// detects as an Out Of Memory termination at next launch.
- (void)fakeOutOfMemoryAfterDelay;

@end

NS_ASSUME_NONNULL_END
