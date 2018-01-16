//
//  BugsnagCrashSentry.m
//  Pods
//
//  Created by Jamie Lynch on 11/08/2017.
//
//

#import "BSG_KSCrashAdvanced.h"
#import "BSG_KSCrashC.h"

#import "BugsnagCrashSentry.h"
#import "BugsnagLogger.h"
#import "BugsnagSink.h"
#import "BugsnagNotifier.h"

@interface Bugsnag
+ (BugsnagNotifier *)notifier;
@end

NSUInteger const BSG_MAX_STORED_REPORTS = 12;

@implementation BugsnagCrashSentry

- (void)install:(BugsnagConfiguration *)config
      apiClient:(BugsnagApiClient *)apiClient
        onCrash:(BSG_KSReportWriteCallback)onCrash {

    BugsnagSink *sink = [[BugsnagSink alloc] initWithApiClient:apiClient];
    [BSG_KSCrash sharedInstance].sink = sink;
    [BSG_KSCrash sharedInstance].introspectMemory = YES;
    [BSG_KSCrash sharedInstance].deleteBehaviorAfterSendAll =
        BSG_KSCDeleteOnSucess;
    [BSG_KSCrash sharedInstance].onCrash = onCrash;
    [BSG_KSCrash sharedInstance].maxStoredReports = BSG_MAX_STORED_REPORTS;
    [BSG_KSCrash sharedInstance].demangleLanguages = 0;

    if (!config.autoNotify) {
        bsg_kscrash_setHandlingCrashTypes(BSG_KSCrashTypeUserReported);
    }
    if (![[BSG_KSCrash sharedInstance] install]) {
        bsg_log_err(@"Failed to install crash handler. No exceptions will be "
                    @"reported!");
    }
    [[Bugsnag notifier] flushPendingReports];
}

- (void)reportUserException:(NSString *)reportName
                     reason:(NSString *)reportMessage {

    [[BSG_KSCrash sharedInstance] reportUserException:reportName
                                               reason:reportMessage
                                             language:NULL
                                           lineOfCode:@""
                                           stackTrace:@[]
                                     terminateProgram:NO];
}

+ (BOOL)isCrashOnLaunch:(BugsnagConfiguration *)config events:(NSArray *)events {
    for (NSDictionary *event in events) {
        NSTimeInterval duration = [[event valueForKeyPath:@"app.duration"] unsignedIntegerValue];
        if (duration > 0) {
            duration /= 1000;
        }
        BOOL unhandled = [[event valueForKeyPath:@"handledState.unhandled"] boolValue];
        if (unhandled && duration >= 0 && duration <= config.launchCrashThreshold) {
            return YES;
        }
    }
    return NO;
}

@end
