//
//  BugsnagClient+Private.h
//  Bugsnag
//
//  Created by Nick Dowell on 26/11/2020.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import "BSGDefines.h"
#import "BugsnagInternals.h"

@class BSGAppHangDetector;
@class BSGEventUploader;
@class BugsnagAppWithState;
@class BugsnagBreadcrumbs;
@class BugsnagConfiguration;
@class BugsnagDeviceWithState;
@class BugsnagMetadata;
@class BugsnagNotifier;
@class BugsnagSessionTracker;
@class BugsnagSystemState;
@class BSGPersistentFeatureFlagStore;

NS_ASSUME_NONNULL_BEGIN

BSG_OBJC_DIRECT_MEMBERS
@interface BugsnagClient ()

#pragma mark Properties

@property (nonatomic) BOOL appDidCrashLastLaunch;

@property (nonatomic) BSGAppHangDetector *appHangDetector;

@property (nullable, nonatomic) BugsnagEvent *appHangEvent;

/// The App hang or OOM event that caused the last launch to crash.
@property (nullable, nonatomic) BugsnagEvent *eventFromLastLaunch;

@property (strong, nonatomic) BSGEventUploader *eventUploader;

@property (nonatomic) NSMutableDictionary *extraRuntimeInfo;

@property (atomic) BOOL isStarted;

/// YES if BugsnagClient is ready to handle some internal method calls.
/// It does not mean that it is fully started and ready to receive method calls from outside of the library.
@property (atomic) BOOL readyForInternalCalls;

/// State related metadata
///
/// Upon change this is automatically persisted to disk, making it available when contructing OOM payloads.
/// Is it also added to KSCrashReports under `user.state` by `BSSerializeDataCrashHandler()`.
///
/// Example contents:
///
/// {
///     "app": {
///         "codeBundleId": "com.example.app",
///     },
///     "client": {
///         "context": "MyViewController",
///     },
///     "user": {
///         "id": "abc123",
///         "name": "bob"
///     }
/// }
@property (strong, nonatomic) BugsnagMetadata *state;

@property (strong, nonatomic) NSMutableArray *stateEventBlocks;

@property (strong, nonatomic) BugsnagSystemState *systemState;

#pragma mark Methods

- (void)start;

/**
 * Common entry point to notify an error or an exception.
 * Bugsnag components MUST NOT call the regular notify methods in this class. ALWAYS call
 * this method instead.
 *
 * You must provide the number of stack trace entries to strip from the top of the stack
 * (INCLUDING this method) so that our own reporting methods don't show up in the reported stack trace.
 *
 * Example: stackStripDepth = 2 would strip the top two entries, which we would expect to be
 * 1. +[Bugsnag notifyError:block:]
 * 2. -[BugsnagClient notifyErrorOrException:stackStripDepth:block:]
 *
 * @param errorOrException the error or exception to report.
 * @param stackStripDepth The number of stack trace entries to strip from the top of the stack.
 * @param block Called after reporting.
 */
- (void)notifyErrorOrException:(id)errorOrException
               stackStripDepth:(NSUInteger)stackStripDepth
                         block:(_Nullable BugsnagOnErrorBlock)block;

@end

NS_ASSUME_NONNULL_END
