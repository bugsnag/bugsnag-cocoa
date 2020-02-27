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

#import "BugsnagSink.h"
#import "Bugsnag.h"
#import "BugsnagLogger.h"
#import "BugsnagCollections.h"
#import "BugsnagNotifier.h"
#import "BugsnagKeys.h"
#import "BSG_KSSystemInfo.h"
#import "Private.h"

// This is private in Bugsnag, but really we want package private so define
// it here.
@interface Bugsnag ()
+ (BugsnagNotifier *)notifier;
@end

@implementation BugsnagSink

- (instancetype)initWithApiClient:(BugsnagErrorReportApiClient *)apiClient {
    if (self = [super init]) {
        self.apiClient = apiClient;
    }
    return self;
}

// Entry point called by BSG_KSCrash when a report needs to be sent. Handles
// report filtering based on the configuration options for
// `notifyReleaseStages`. Removes all reports not meeting at least one of the
// following conditions:
// - the report-specific config specifies the `notifyReleaseStages` property and
// it contains the current stage
// - the report-specific and global `notifyReleaseStages` properties are unset
// - the report-specific `notifyReleaseStages` property is unset and the global
// `notifyReleaseStages` property
//   and it contains the current stage
- (void)filterReports:(NSDictionary <NSString *, NSDictionary *> *)reports
         onCompletion:(BSG_KSCrashReportFilterCompletion)onCompletion {
    NSMutableArray *bugsnagReports = [NSMutableArray new];
    BugsnagConfiguration *configuration = [Bugsnag configuration];
    
    for (NSString *fileKey in reports) {
        NSDictionary *report = reports[fileKey];
        BugsnagEvent *bugsnagReport = [[BugsnagEvent alloc] initWithKSReport:report];
        if (![bugsnagReport shouldBeSent])
            continue;
        BOOL shouldSend = YES;
        for (BugsnagOnSendBlock block in configuration.onSendBlocks) {
            @try {
                shouldSend = block(report, bugsnagReport);
                if (!shouldSend)
                    break;
            } @catch (NSException *exception) {
                bsg_log_err(@"Error from onSend callback: %@", exception);
            }
        }
        if (shouldSend) {
            [bugsnagReports addObject:bugsnagReport];
        }
    }

    if (bugsnagReports.count == 0) {
        if (onCompletion) {
            onCompletion(bugsnagReports.count, YES, nil);
        }
        return;
    }

    NSDictionary *reportData = [self getBodyFromReports:bugsnagReports];

    if (reportData == nil) {
        if (onCompletion) {
            onCompletion(0, YES, nil);
        }
        return;
    }

    [self.apiClient sendItems:bugsnagReports.count
                  withPayload:reportData
                        toURL:configuration.notifyURL
                      headers:[configuration errorApiHeaders]
                 onCompletion:onCompletion];
}


// Generates the payload for notifying Bugsnag
- (NSDictionary *)getBodyFromReports:(NSArray *)reports {
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    BSGDictSetSafeObject(data, [Bugsnag notifier].details, BSGKeyNotifier);
    BSGDictSetSafeObject(data, [Bugsnag notifier].configuration.apiKey, BSGKeyApiKey);
    BSGDictSetSafeObject(data, @"4.0", @"payloadVersion");

    NSMutableArray *formatted =
            [[NSMutableArray alloc] initWithCapacity:[reports count]];

    for (BugsnagEvent *report in reports) {
        BSGArrayAddSafeObject(formatted, [report toJson]);
    }

    BSGDictSetSafeObject(data, formatted, BSGKeyEvents);
    return data;
}

@end
