//
//  BugsnagCrashSentry.h
//  Pods
//
//  Created by Jamie Lynch on 11/08/2017.
//
//

#import <Foundation/Foundation.h>

#import "BSG_KSCrashReportWriter.h"
#import "BugsnagConfiguration.h"
#import "BugsnagErrorReportApiClient.h"

@interface BugsnagCrashSentry : NSObject

- (void)install:(BugsnagConfiguration *)config
      apiClient:(BugsnagErrorReportApiClient *)apiClient
        onCrash:(BSG_KSReportWriteCallback)onCrash;

+ (BOOL)isCrashOnLaunch:(BugsnagConfiguration *)config currentDate:(NSDate *)now;

- (void)reportUserException:(NSString *)reportName
                     reason:(NSString *)reportMessage;

@end
