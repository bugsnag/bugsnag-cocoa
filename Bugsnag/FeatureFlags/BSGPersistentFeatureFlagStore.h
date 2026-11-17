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
/// One writer per directory: a store reads from, writes to and deletes files in the directory only while it holds an
/// exclusive flock() on featureflag.lock. It takes the lock when it is created if the directory holds files for it to
/// read or delete, and otherwise before its first write, and keeps it until it is deallocated. flock() locks belong to an
/// open file description, so a second store using the same directory, in this process or another (e.g. a second
/// instance of a macOS app), does not get the lock while the first holds it. A store that does not get the lock when it
/// is created reports no persisted flags: it never reads featureflag.bin (or the JSON files of earlier versions of the
/// SDK), so an OOM or thermal kill reported for the previous launch has no flags. It keeps its flags in memory without
/// changing anything in the directory. Because the first store keeps the lock for its lifetime, a store that finds the
/// lock held by another (EWOULDBLOCK) logs that once and never tries again. A store that could not take the lock for a
/// reason that can clear (e.g. featureflag.lock could not be opened while the device was locked) tries again on later
/// writes, at most once per retry interval, and on iOS, tvOS and visionOS when protected data becomes available. Once
/// it has the lock it examines the directory again and writes its current flags. If the directory itself is missing,
/// it is created when the lock is taken.
///
/// A store that takes the lock later does not read the previous launch's flags then, although no other store can be
/// writing them any more. The OOM or thermal kill event for the previous launch is built from the persisted flags when
/// Bugsnag starts, before the first write (and so before the lock can be tried again), so flags read later could not
/// be reported. They are replaced by this launch's flags instead. Failures that normally clear at once (an interrupted
/// open, or featureflag.lock being removed while it is created) are retried once straight away, so they do not stop
/// the flags being read when the store is created.
///
/// If the directory is removed after the lock has been taken (e.g. the app deletes Bugsnag's directory while it runs),
/// the store keeps writing to the files it has open, which are no longer in the directory, so the rest of this
/// launch's flags are not saved, and a larger file that is needed cannot be created and is retried with the usual
/// delay. The directory is not recreated then: that would need a check before every write, and when Bugsnag's whole
/// directory is removed, the run context file goes with it, so no OOM or thermal kill is reported for this launch
/// anyway. Removing the directory also removes featureflag.lock while this store holds the lock on it: another store
/// (in this process or another) that then creates the directory again creates a new featureflag.lock, which it can
/// lock, so two stores could each believe that they are the only writer and both write featureflag.bin in that
/// directory. This is not guarded against, for the same reasons.
///
/// Only EWOULDBLOCK from flock() means that another store holds the lock. On a file system that does not support
/// flock() (ENOTSUP or EOPNOTSUPP, e.g. an NFS volume without a lock daemon) the store logs that once and proceeds
/// as the only writer, as the JSON files written by earlier versions of the SDK did, rather than never saving flags.
///
/// Durability: by design the file is not synchronised to disk (no fsync), so a power loss can lose recent
/// changes or leave the header ahead of the records it refers to. A reboot stops an OOM or thermal kill
/// being reported for the launch before it, so such a file is not used for a report.
@interface BSGPersistentFeatureFlagStore ()

- (instancetype)initWithStorageDirectory:(NSString *)directory;

@end

#if defined(DEBUG) && DEBUG

#pragma mark - For unit tests only (debug builds)

/// Schedules `retry` to run after `delay` seconds. By default retries are scheduled with dispatch_after.
typedef void (^ BSGFeatureFlagRetryScheduler)(NSTimeInterval delay, dispatch_block_t retry);

@interface BSGPersistentFeatureFlagStore ()

/// For unit tests only: replaces dispatch_after for scheduling retries, so that a test decides when they run.
/// Only the most recently scheduled retry does anything when it runs.
@property (nonatomic, copy, nullable) BSGFeatureFlagRetryScheduler retryScheduler;

@end

/// The function used to lock featureflag.lock, with flock()'s signature.
typedef int (*BSGFeatureFlagLockFunction)(int fd, int operation);

/// For unit tests only: replaces flock() for locking featureflag.lock (NULL restores it) and returns the function
/// that was in use, so that tests can simulate errors such as ENOTSUP. Not thread safe.
__BEGIN_DECLS
BSGFeatureFlagLockFunction BSGSetFeatureFlagLockFunction(BSGFeatureFlagLockFunction _Nullable function);
__END_DECLS

#endif

NS_ASSUME_NONNULL_END
