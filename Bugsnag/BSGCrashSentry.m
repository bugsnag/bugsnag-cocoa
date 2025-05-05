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
#import "KSDebug.h"
#import "KSCrashConfiguration.h"
#import "KSCrashReportFields.h"
#import "BugsnagClient+Private.h"
#import "BugsnagInternals.h"
#import "BugsnagLogger.h"

NSTimeInterval BSGCrashDeliveryTimeout = 3;

static void BSGCrashAttemptDelivery(int64_t);

void BSGCrashSentryInstall(BugsnagConfiguration *config, KSReportWriteCallback onCrash) {
    KSCrash *ksCrash = [KSCrash sharedInstance];

    // REPORT STORE CONFIGURATION
    KSCrashReportStoreConfiguration *ksReportStore = [[KSCrashReportStoreConfiguration alloc] init];

    NSString *crashReportsDirectory = BSGFileLocations.current.kscrashReports;
    // NSFileProtectionComplete prevents new crash reports being written when
    // the device is locked, so must be disabled.
    BSGDisableNSFileProtectionComplete(crashReportsDirectory);
    ksReportStore.reportsPath = crashReportsDirectory;
    ksReportStore.reportCleanupPolicy = KSCrashReportCleanupPolicyNever;

    // KSCRASH CONFIGURATION
    KSCrashConfiguration *ksConfig = [[KSCrashConfiguration alloc] init];
    ksConfig.crashNotifyCallback = ^(const struct KSCrashReportWriter *_Nonnull writer, bool requiresAsyncSafety) {
        onCrash(writer, requiresAsyncSafety);
    };

    KSCrashMonitorType crashTypes = 0;
    if (config.autoDetectErrors) {
        if (ksdebug_isBeingTraced()) {
            // TODO: To be fixed in PLAT-13869
            crashTypes = (KSCrashMonitorTypeDebuggerSafe & ~KSCrashMonitorTypeMemoryTermination);
        } else {
            crashTypes = KSCrashTypeFromBugsnagErrorTypes(config.enabledErrorTypes);
        }
        if (config.attemptDeliveryOnCrash) {
            bsg_log_debug(@"Enabling on-crash delivery");
            ksConfig.reportWrittenCallback = ^(int64_t reportID) {
                BSGCrashAttemptDelivery(reportID);
            };
        }
    }
    ksConfig.monitors = crashTypes;
    ksConfig.reportStoreConfiguration = ksReportStore;

    // In addition to installing crash handlers, KSCrash installation initializes various
    // subsystems that Bugsnag relies on, so needs to be called even if autoDetectErrors is disabled.
    NSError *ksError = nil;
    if (![ksCrash installWithConfiguration:ksConfig error:&ksError] && crashTypes) {
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
KSCrashMonitorType KSCrashTypeFromBugsnagErrorTypes(BugsnagErrorTypes *errorTypes) {
    return ((errorTypes.unhandledExceptions ?   KSCrashMonitorTypeNSException : 0)     |
            (errorTypes.cppExceptions ?         KSCrashMonitorTypeCPPException : 0)    |
#if !TARGET_OS_WATCH
            (errorTypes.signals ?               KSCrashMonitorTypeSignal : 0)          |
            (errorTypes.machExceptions ?        KSCrashMonitorTypeMachException : 0)   |
#endif
            0);
}

static void BSGCrashAttemptDelivery(int64_t reportID) {
    // Reading the report to check if appropriate type - allowed mach & nsexception
    KSCrashReportStore *reportStore = [[KSCrash sharedInstance] reportStore];
    if (reportStore == nil) {
        bsg_log_debug(@"Report store is nil, could not perform crash-time delivery.");
        return;
    }
    KSCrashReportDictionary *reportDict = [reportStore reportForID:reportID];
    if (reportDict == nil) {
        bsg_log_debug(@"Report is nil, could not perform crash-time delivery.");
        return;
    }

    NSString *errorTypePath = [NSString stringWithFormat:@"%@.%@.%@", KSCrashField_Crash, KSCrashField_Error, KSCrashField_Type];
    NSString *crashErrorType = [NSObject valueForKeyPath:errorTypePath];

    if (![crashErrorType isEqualToString:@"mach"] && ![crashErrorType isEqualToString:@"nsexception"])
    {
        bsg_log_debug(@"Crash type is not mach or nsexception, could not perform crash-time delivery.");
        return;
    }

    // Extract file name from reportID
    NSString *file = [reportStore crashReportPathForID:reportID];
    if (file == nil) {
        bsg_log_debug(@"Report path not found, could not perform crash-time delivery.");
        return;
    }

    bsg_log_info(@"Attempting crash-time delivery of %@", file);
    int64_t timeout = (int64_t)(BSGCrashDeliveryTimeout * NSEC_PER_SEC);
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
