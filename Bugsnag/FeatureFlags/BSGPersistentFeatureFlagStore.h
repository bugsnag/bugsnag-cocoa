//
//  BSGPersistentFeatureFlagStore.h
//  Bugsnag
//
//  Created by Robert B on 25/11/2024.
//  Copyright © 2024 Bugsnag. All rights reserved.
//

#import "BugsnagInternals.h"
#import "BSGDefines.h"
#import "BSGFeatureFlagStore.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


/// Persists feature flags in featureflag.bin in a directory so that they can be reported with an OOM or
/// thermal kill detected at the next launch (see BSGFeatureFlagFileFormat.h for the file format).
///
/// Nothing is created in the directory until there are flags to save: with no flags, neither featureflag.bin
/// nor featureflag.lock is created, and an existing featureflag.bin whose flags are all cleared is emptied in
/// place (or removed) so that they are never reported again.
///
/// One writer per directory: a store writes to (and deletes files in) the directory only while it holds
/// an exclusive flock() on featureflag.lock. It takes the lock when it is created if the directory holds
/// files for it to read or delete, and otherwise before its first write, and keeps it until it is
/// deallocated. flock() locks belong to an open file description, so a second store using the same
/// directory, in this process or another (e.g. a second instance of a macOS app), does not get the lock
/// while the first holds it. It still reads the flags saved by the previous launch when it is created and
/// keeps its flags in memory without changing anything in the directory. A store that could not take the
/// lock (because another store held it, or because the device was locked) tries again on later writes, at
/// most once per retry interval, and on iOS and tvOS when protected data becomes available. Once it has the
/// lock it examines the directory again and writes its current flags.
///
/// Durability: by design the file is not synchronised to disk (no fsync), so a power loss can lose recent
/// changes or leave the header ahead of the records it refers to. A reboot stops an OOM or thermal kill
/// being reported for the launch before it, so such a file is not used for a report.
@interface BSGPersistentFeatureFlagStore ()

- (instancetype)initWithStorageDirectory:(NSString *)directory;

@end

NS_ASSUME_NONNULL_END
