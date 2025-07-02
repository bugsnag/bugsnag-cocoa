//
//  BSGCrashMonitor.h
//  Bugsnag
//
//  Created by Jamie Lynch on 11/08/2017.
//
//

#import <Foundation/Foundation.h>

#import "KSCrashReportWriter.h"
#import "KSCrashMonitorType.h"

@class BugsnagConfiguration;
@class BugsnagErrorTypes;

NS_ASSUME_NONNULL_BEGIN

void BSGCrashMonitorInstall(BugsnagConfiguration *, KSReportWriteCallback);

KSCrashMonitorType KSCrashTypeFromBugsnagErrorTypes(BugsnagErrorTypes *);

NS_ASSUME_NONNULL_END
