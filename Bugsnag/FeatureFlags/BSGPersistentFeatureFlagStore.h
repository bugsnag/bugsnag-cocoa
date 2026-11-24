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


/// Persists feature flags in featureflag.bin in a directory so that they can be reported with an OOM or thermal kill
/// detected at the next launch. File format: BSGFeatureFlagFileFormat.h; design: BSGPersistentFeatureFlagStore.m.
///
/// - Nothing is created in the directory until there are flags to save. When all flags are cleared, an existing
///   featureflag.bin is emptied in place (or removed) so that they are never reported again.
/// - One writer per directory: a store reads, writes and deletes files there only while it holds an exclusive flock()
///   on featureflag.lock. flock() locks belong to an open file description, so a second store using the directory, in
///   this process or another (e.g. a second instance of a macOS app), does not get the lock while the first holds it.
/// - The lock is taken at creation if the directory holds files to read or delete, otherwise before the first write,
///   and kept until dealloc. A missing directory is created when the lock is taken.
/// - A store without the lock at creation reports no persisted flags: it never reads featureflag.bin or the JSON files
///   of earlier SDK versions (another store may be writing them; a consistent read is not worth it for this rare case),
///   and keeps its flags in memory without changing anything in the directory.
/// - EWOULDBLOCK (another store holds the lock, for its lifetime) is logged once and never retried. Failures that can
///   clear (e.g. featureflag.lock cannot be opened while the device is locked) are retried on later writes, at most
///   once per retry interval, and on iOS, tvOS and visionOS when protected data becomes available. An interrupted
///   open, or featureflag.lock removed while being created, is retried at once, so it does not stop the read at
///   creation.
/// - A store that takes the lock later examines the directory again and writes its current flags, but does not read
///   the previous launch's flags: its OOM or thermal kill event was built when Bugsnag started, before the first write.
/// - ENOTSUP or EOPNOTSUPP from flock() (e.g. an NFS volume without a lock daemon) is logged once, and the store
///   proceeds as the only writer, as the JSON files of earlier SDK versions did, rather than never saving flags.
/// - If the directory is removed after the lock is taken, the store keeps writing to its open files, now outside the
///   directory, so the rest of this launch's flags are lost, and a larger file cannot be created (retried with the
///   usual delay). The directory is not recreated: that needs a check before every write, and the run context file is
///   gone too, so no OOM or thermal kill is reported for this launch. A store that recreates the directory creates and
///   locks a new featureflag.lock, so two stores could both write featureflag.bin; this is not guarded against.
@interface BSGPersistentFeatureFlagStore () <BSGPreviousLaunchFeatureFlagStore>

- (instancetype)initWithStorageDirectory:(NSString *)directory;

@end

#if defined(DEBUG) && DEBUG

#pragma mark - For unit tests only (debug builds)

/// Schedules `retry` to run after `delay` seconds. By default retries are scheduled with dispatch_after.
typedef void (^ BSGFeatureFlagRetryScheduler)(NSTimeInterval delay, dispatch_block_t retry);

@interface BSGPersistentFeatureFlagStore ()

/// Replaces dispatch_after for scheduling retries, so a test decides when they run. Only the latest retry acts.
@property (nonatomic, copy, nullable) BSGFeatureFlagRetryScheduler retryScheduler;

@end

/// The function used to lock featureflag.lock, with flock()'s signature.
typedef int (*BSGFeatureFlagLockFunction)(int fd, int operation);

/// Replaces flock() for featureflag.lock (NULL restores it) and returns the previous function, so tests can simulate
/// errors such as ENOTSUP. Not thread safe.
__BEGIN_DECLS
BSGFeatureFlagLockFunction BSGSetFeatureFlagLockFunction(BSGFeatureFlagLockFunction _Nullable function);
__END_DECLS

#endif

NS_ASSUME_NONNULL_END
