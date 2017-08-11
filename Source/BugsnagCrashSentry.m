//
//  BugsnagCrashSentry.m
//  Pods
//
//  Created by Jamie Lynch on 11/08/2017.
//
//

#import <KSCrash/KSCrashAdvanced.h>
#import <KSCrash/KSCrashC.h>

#import "BugsnagCrashSentry.h"
#import "BugsnagLogger.h"
#import "BugsnagSink.h"

NSUInteger const BSG_MAX_STORED_REPORTS = 12;

@implementation BugsnagCrashSentry

- (void)install:(BugsnagConfiguration *)config
      apiClient:(BugsnagErrorReportApiClient *)apiClient
        onCrash:(KSReportWriteCallback)onCrash {
    
    BugsnagSink *sink = [[BugsnagSink alloc] initWithApiClient:apiClient];
    [KSCrash sharedInstance].sink = sink;
    // We don't use this feature yet, so we turn it off
    [KSCrash sharedInstance].introspectMemory = NO;
    [KSCrash sharedInstance].deleteBehaviorAfterSendAll = KSCDeleteOnSucess;
    [KSCrash sharedInstance].onCrash = onCrash;
    [KSCrash sharedInstance].maxStoredReports = BSG_MAX_STORED_REPORTS;
    [KSCrash sharedInstance].demangleLanguages = 0;
    
    if (!config.autoNotify) {
        kscrash_setHandlingCrashTypes(KSCrashTypeUserReported);
    }
    if (![[KSCrash sharedInstance] install]) {
        bsg_log_err(@"Failed to install crash handler. No exceptions will be reported!");
    }
    
    [sink.apiClient sendPendingReports];
}

@end
