//
//  BugsnagErrorReportApiClient.m
//  Pods
//
//  Created by Jamie Lynch on 11/08/2017.
//
//

#import "BugsnagErrorReportApiClient.h"
#import "Bugsnag.h"
#import "BugsnagLogger.h"
#import "BugsnagNotifier.h"
#import "BugsnagSink.h"
#import "BugsnagKeys.h"
#import "BugsnagCrashSentry.h"

// This is private in Bugsnag, but really we want package private so define
// it here.
@interface Bugsnag ()
+ (BugsnagNotifier *)notifier;
@end

@interface BSGDeliveryOperation : NSOperation
@end

@implementation BugsnagErrorReportApiClient


// previous sync crash report impl

//- (void)sendReports:(NSArray<BugsnagCrashReport *> *)reports
//            payload:(NSDictionary *)reportData
//              toURL:(NSURL *)url
//       onCompletion:(BSG_KSCrashReportFilterCompletion)onCompletion {
//    @try {
//        NSArray *events = reportData[@"events"];
//        BOOL synchronous = [BugsnagCrashSentry isCrashOnLaunch:[Bugsnag configuration] events:events];
//
//        if (synchronous) {
//            bsg_log_info(@"Crash during launch period, sending sync");
//            [self sendReportData:reports
//                         payload:reportData
//                           toURL:url
//                    onCompletion:onCompletion];
//        } else {
//            bsg_log_info(@"Sending async");
//            [_sendQueue cancelAllOperations];
//            [_sendQueue addOperationWithBlock:^{
//                [self sendReportData:reports
//                             payload:reportData
//                               toURL:url
//                        onCompletion:onCompletion];
//            }];
//        }
//    } @catch (NSException *exception) {
//        if (onCompletion) {
//            onCompletion(reports, NO,
//                         [NSError errorWithDomain:exception.reason
//                                             code:420
//                                         userInfo:@{BSGKeyException : exception}]);
//        }
//    }
//}

            

            
            
            
- (NSOperation *)deliveryOperation {
    return [BSGDeliveryOperation new];
}

@end

@implementation BSGDeliveryOperation

- (void)main {
    @autoreleasepool {
        @try {
            [[BSG_KSCrash sharedInstance]
                    sendAllReportsWithCompletion:^(NSArray *filteredReports,
                            BOOL completed, NSError *error) {
                        if (error) {
                            bsg_log_warn(@"Failed to send reports: %@", error);
                        } else if (filteredReports.count > 0) {
                            bsg_log_info(@"Reports sent.");
                        }
                    }];
        } @catch (NSException *e) {
            bsg_log_err(@"Could not send report: %@", e);
        }
    }
}
            
@end
