//
//  BugsnagSink.m
//
//  Created by Conrad Irwin on 2014-10-01.
//
//  Copyright (c) 2014 Bugsnag, Inc. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import <KSCrash/KSCrash.h>
#import "BugsnagSink.h"
#import "BugsnagNotifier.h"
#import "Bugsnag.h"
#import "BugsnagCrashReport.h"
#import "BugsnagCollections.h"

// This is private in Bugsnag, but really we want package private so define
// it here.
@interface Bugsnag ()
+ (BugsnagNotifier*)notifier;
@end

@implementation BugsnagSink

// Entry point called by KSCrash when a report needs to be sent. Handles report filtering based on the configuration
// options for `notifyReleaseStages`.
// Removes all reports not meeting at least one of the following conditions:
// - the report-specific config specifies the `notifyReleaseStages` property and it contains the current stage
// - the report-specific and global `notifyReleaseStages` properties are unset
// - the report-specific `notifyReleaseStages` property is unset and the global `notifyReleaseStages` property
//   and it contains the current stage
- (void) filterReports:(NSArray*) reports onCompletion:(KSCrashReportFilterCompletion) onCompletion
{
    NSError *error = nil;
    NSMutableArray *bugsnagReports = [NSMutableArray arrayWithCapacity:[reports count]];
    BugsnagConfiguration *configuration = [Bugsnag configuration];
    BOOL configuredShouldNotify = configuration.notifyReleaseStages.count == 0
        || [configuration.notifyReleaseStages containsObject:configuration.releaseStage];
    for (NSDictionary* report in reports) {
        BugsnagCrashReport *bugsnagReport = [[BugsnagCrashReport alloc] initWithKSReport:report];
        
        // Filter the reports here, we have to do it now as we dont want to hack KSCrash to do it at crash time.
        // We also in the docs imply that the filtering happens when the crash happens - so we use the values
        // saved in the report.
        BOOL shouldNotify = [bugsnagReport.notifyReleaseStages containsObject:bugsnagReport.releaseStage]
            || (bugsnagReport.notifyReleaseStages.count == 0 && configuredShouldNotify);
        if(shouldNotify) {
            [bugsnagReports addObject:bugsnagReport];
        }
    }
    
    if (bugsnagReports.count == 0) {
        if (onCompletion) {
            onCompletion(reports, YES, nil);
        }
        return;
    }

    NSDictionary *reportData = [self getBodyFromReports:bugsnagReports];
    for (BugsnagBeforeNotifyHook hook in configuration.beforeNotifyHooks) {
        if (reportData) {
            reportData = hook(reports, reportData);
        } else {
            break;
        }
    }
    if (reportData == nil) {
        if (onCompletion) {
            onCompletion(@[], YES, nil);
        }
        return;
    }
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:reportData
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    
    if (jsonData == nil) {
        if (onCompletion) {
            onCompletion(reports, NO, error);
        }
        return;
    }
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL: configuration.notifyURL
                                                           cachePolicy: NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval: 15];
    request.HTTPMethod = @"POST";
    request.HTTPBody = jsonData;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [NSURLConnection sendSynchronousRequest:request
                          returningResponse:NULL
                                      error:&error];
#pragma clang diagnostic pop
    
    if (onCompletion) {
        onCompletion(reports, error == nil, error);
    }
}

// Generates the payload for notifying Bugsnag
- (NSDictionary*) getBodyFromReports:(NSArray*) reports {
    NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
    BSGDictSetSafeObject(data, [Bugsnag configuration].apiKey, @"apiKey");
    BSGDictSetSafeObject(data, [Bugsnag notifier].details, @"notifier");
    
    NSMutableArray* formatted = [[NSMutableArray alloc] initWithCapacity:[reports count]];
    
    for (BugsnagCrashReport* report in reports) {
        BSGArrayAddSafeObject(formatted, [report serializableValueWithTopLevelData:data]);
    }

    BSGDictSetSafeObject(data, formatted, @"events");
    
    return data;
}

@end
