//
//  BSGCrashSentry.m
//  Bugsnag
//
//  Created by Jamie Lynch on 11/08/2017.
//
//

#import "BSGCrashSentry.h"

#import "BSGEventUploader.h"
#import "BSGFileLocations.h"
#import "BSGUtils.h"
#import "KSCrash.h"
#import "KSCrashC.h"
#import "KSMach.h"
#import "BugsnagClient+Private.h"
#import "BugsnagInternals.h"
#import "BugsnagLogger.h"

NSTimeInterval BSGCrashSentryDeliveryTimeout = 3;

static void BSGCrashSentryAttemptyDelivery(void);

void BSGCrashSentryInstall(BugsnagConfiguration *config, KSReportWriteCallback onCrash) {
    KSCrash *ksCrash = [KSCrash sharedInstance];

    kscrash_setCrashNotifyCallback(onCrash);

#if BSG_HAVE_MACH_THREADS
    // overridden elsewhere for handled errors, so we can assume that this only
    // applies to unhandled errors
    kscrash_setThreadTracingEnabled(config.sendThreads != BSGThreadSendPolicyNever);
#endif

    KSCrashType crashTypes = 0;
    if (config.autoDetectErrors) {
        if (ksmachisBeingTraced()) {
            bsg_log_info(@"Unhandled errors will not be reported because a debugger is attached");
        } else {
            crashTypes = KSCrashTypeFromBugsnagErrorTypes(config.enabledErrorTypes);
        }
        if (config.attemptDeliveryOnCrash) {
            bsg_log_debug(@"Enabling on-crash delivery");
            crashContext()->crash.attemptDelivery = BSGCrashSentryAttemptyDelivery;
        }
    }

    NSString *crashReportsDirectory = BSGFileLocations.current.kscrashReports;

    // NSFileProtectionComplete prevents new crash reports being written when
    // the device is locked, so must be disabled.
    BSGDisableNSFileProtectionComplete(crashReportsDirectory);

    // In addition to installing crash handlers, -[KSCrash install:] initializes various
    // subsystems that Bugsnag relies on, so needs to be called even if autoDetectErrors is disabled.
    if ((![ksCrash install:crashTypes directory:crashReportsDirectory] && crashTypes)) {
        bsg_log_err(@"Failed to install crash handlers; no exceptions or crashes will be reported");
    }
}

/**
 * Map the BSGErrorType bitfield of reportable events to the equivalent KSCrash one.
 * OOMs are dealt with exclusively in the Bugsnag layer so omitted from consideration here.
 * User reported events should always be included and so also not dealt with here.
 *
 * @param errorTypes The enabled error types
 * @returns A KSCrashType equivalent (with the above caveats) to the input
 */
KSCrashType KSCrashTypeFromBugsnagErrorTypes(BugsnagErrorTypes *errorTypes) {
    return ((errorTypes.unhandledExceptions ?   KSCrashTypeNSException : 0)     |
            (errorTypes.cppExceptions ?         KSCrashTypeCPPException : 0)    |
#if !TARGET_OS_WATCH
            (errorTypes.signals ?               KSCrashTypeSignal : 0)          |
            (errorTypes.machExceptions ?        KSCrashTypeMachException : 0)   |
#endif
            0);
}

static void BSGCrashSentryAttemptyDelivery(void) {
    NSString *file = @(crashContext()->config.crashReportFilePath);
    bsg_log_info(@"Attempting crash-time delivery of %@", file);
    int64_t timeout = (int64_t)(BSGCrashSentryDeliveryTimeout * NSEC_PER_SEC);
    dispatch_time_t deadline = dispatch_time(DISPATCH_TIME_NOW, timeout);
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [Bugsnag.client.eventUploader uploadKSCrashReportWithFile:file completionHandler:^{
        bsg_log_debug(@"Sent crash.");
        dispatch_semaphore_signal(semaphore);
    }];
    if (dispatch_semaphore_wait(semaphore, deadline)) {
        bsg_log_debug(@"Timed out waiting for crash to be sent.");
    }
}
