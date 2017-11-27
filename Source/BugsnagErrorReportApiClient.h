//
//  BugsnagErrorReportApiClient.h
//  Pods
//
//  Created by Jamie Lynch on 11/08/2017.
//
//

#import <Foundation/Foundation.h>

#import "BSG_KSCrashReportFilterCompletion.h"
#import "BugsnagCrashReport.h"
#import "BugsnagConfiguration.h"

@interface BugsnagErrorReportApiClient : NSObject

- (instancetype)initWithConfig:(BugsnagConfiguration *)config;

/**
 * Send outstanding error reports
 */
- (void)sendPendingReports;

- (void)sendReports:(NSArray<BugsnagCrashReport *> *)reports
            payload:(NSDictionary *)reportData
              toURL:(NSURL *)url
       onCompletion:(BSG_KSCrashReportFilterCompletion)onCompletion;

@end
