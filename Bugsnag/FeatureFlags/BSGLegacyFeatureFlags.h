//
//  BSGLegacyFeatureFlags.h
//  Bugsnag
//
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "BSGDefines.h"

@class BugsnagFeatureFlag;

// Earlier versions of the SDK saved each flag in a separate JSON file in the same directory,
// containing its name, variant and the order it was added in. They are read once, to import them.
//
// The imported flags only matter if the launch before the upgrade ended in an OOM or thermal kill
// that is reported. That is only reported when CFBundleVersion and the main executable's UUID are
// unchanged (see BSGRunContextWasKilled), and an SDK upgrade normally relinks the app, so in practice
// they are almost never reported. The import is kept as a safe, cheap migration that also deletes the
// old files.

NS_ASSUME_NONNULL_BEGIN

__BEGIN_DECLS

/// Whether a file in the directory is one of the JSON files. A flag with an empty name was saved as
/// ".json", which pathExtension treats as having no extension.
BOOL BSGIsLegacyFeatureFlagFile(NSString *file);

/// The flags saved in the JSON files, in the order they were added. Files that cannot be read or
/// decoded are skipped.
NSArray<BugsnagFeatureFlag *> * BSGLegacyFeatureFlags(NSArray<NSString *> *paths);

/// Deletes the JSON files, logging any error other than a file that no longer exists. Returns the paths of the
/// files that could not be deleted, so that deleting them can be tried again.
NSArray<NSString *> * BSGRemoveLegacyFeatureFlagFiles(NSArray<NSString *> *paths);

__END_DECLS

NS_ASSUME_NONNULL_END
