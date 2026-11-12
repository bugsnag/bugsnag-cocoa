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
/// One writer per directory: a store writes to (and deletes files in) the directory only while it holds
/// an exclusive flock() on featureflag.lock, which it takes when it is created and keeps until it is
/// deallocated. flock() locks belong to an open file description, so a second store using the same
/// directory, in this process or another (e.g. a second instance of a macOS app), does not get the lock.
/// It still reads the flags saved by the previous launch when it is created and keeps its flags in
/// memory, but never changes anything in the directory.
@interface BSGPersistentFeatureFlagStore ()

- (instancetype)initWithStorageDirectory:(NSString *)directory;

@end

NS_ASSUME_NONNULL_END
