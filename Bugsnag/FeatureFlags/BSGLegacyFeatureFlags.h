//
//  BSGLegacyFeatureFlags.h
//  Bugsnag
//
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "BSGDefines.h"

@class BugsnagFeatureFlag;

// Earlier SDK versions saved each flag (name, variant, order added) as a JSON file in the same directory. They are
// read once, to import them, and deleted once the flags are written to featureflag.bin. The imported flags:
// - Are the previous launch's flags, for an OOM or thermal kill of the launch before the upgrade. Rare in practice:
//   that needs CFBundleVersion and the main executable's UUID unchanged (see BSGRunContextWasKilled), and an SDK
//   upgrade normally relinks the app.
// - Are copied into featureflag.bin when Bugsnag starts, ahead of the app's flags, so they survive the upgrade. A flag
//   the app sets again takes the app's variant; one it clears (or all, on clear all) is removed. Like any persisted
//   flag, they are replaced when Bugsnag next starts.

NS_ASSUME_NONNULL_BEGIN

__BEGIN_DECLS

/// Whether a file in the directory is one of the JSON files. A flag with an empty name was saved as ".json", which
/// pathExtension treats as having no extension.
BOOL BSGIsLegacyFeatureFlagFile(NSString *file);

/// The flags in the JSON files, in the order added. Files that cannot be read or decoded are skipped (and logged).
NSArray<BugsnagFeatureFlag *> * BSGLegacyFeatureFlags(NSArray<NSString *> *paths);

/// Deletes the JSON files with unlink(), returning the paths that could not be deleted so it can be retried. Errors
/// other than ENOENT are logged. Only regular files and symbolic links (the link, never its target) are deleted;
/// anything else, such as a directory named "*.json", is left alone and not returned.
NSArray<NSString *> * BSGRemoveLegacyFeatureFlagFiles(NSArray<NSString *> *paths);

__END_DECLS

NS_ASSUME_NONNULL_END
