//
//  BugsnagNotifier.m
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


#import "Bugsnag.h"
#import "ARCSafe_MemMgmt.h"
#import "BugsnagBreadcrumb.h"
#import "BugsnagNotifier.h"
#import "BugsnagSink.h"
#import "KSCrash.h"
#import "KSCrashAdvanced.h"
#import "KSCrashReportWriter.h"
#import "KSJSONCodecObjC.h"
#import "KSSafeCollections.h"
#import "NSDictionary+Merge.h"

#define NOTIFIER_VERSION @"4.1.0"
#define NOTIFIER_URL @"https://github.com/bugsnag/bugsnag-cocoa"

struct bugsnag_data_t {
    // Contains the user-specified metaData, including the user tab from config.
    char *metaDataJSON;
    // Contains the Bugsnag configuration, all under the "config" tab.
    char *configJSON;
    // Contains notifier state, under "deviceState" and crash-specific information under "crash".
    char *stateJSON;
};

static struct bugsnag_data_t g_bugsnag_data;

void serialize_bugsnag_data(const KSCrashReportWriter *writer) {
    if (g_bugsnag_data.configJSON) {
        writer->addJSONElement(writer, "config", g_bugsnag_data.configJSON);
    }
    if (g_bugsnag_data.metaDataJSON) {
        writer->addJSONElement(writer, "metaData", g_bugsnag_data.metaDataJSON);
    }
    if (g_bugsnag_data.stateJSON) {
        writer->addJSONElement(writer, "state", g_bugsnag_data.stateJSON);
    }
}

@implementation BugsnagNotifier

@synthesize configuration;

- (id) initWithConfiguration:(BugsnagConfiguration*) initConfiguration {
    if((self = [super init])) {
        self.configuration = initConfiguration;
        self.state = [[BugsnagMetaData alloc] init];
        self.details = [@{
                         @"name": @"Bugsnag Objective-C",
                         @"version": NOTIFIER_VERSION,
                         @"url": NOTIFIER_URL} mutableCopy];

        self.metaDataLock = [[NSLock alloc] init];
        self.configuration.metaData.delegate = self;
        self.configuration.config.delegate = self;
        self.state.delegate = self;

        [self metaDataChanged: self.configuration.metaData];
        [self metaDataChanged: self.configuration.config];
        [self metaDataChanged: self.state];
    }

    return self;
}

- (void) start {
    [KSCrash sharedInstance].sink = [[BugsnagSink alloc] init];
    // We don't use this feature yet, so we turn it off
    [KSCrash sharedInstance].introspectMemory = NO;

    [KSCrash sharedInstance].onCrash = &serialize_bugsnag_data;

    if (configuration.autoNotify) {
        [[KSCrash sharedInstance] install];
    }

    [self performSelectorInBackground:@selector(sendPendingReports) withObject:nil];
}

- (void)notify:(NSException *)exception withData:(NSDictionary *)metaData atSeverity:(NSString *)severity atDepth:(NSUInteger) depth {

    if (!metaData) {
        metaData = [[NSDictionary alloc] init];
    }
    metaData = [metaData mergedInto: [self.configuration.metaData toDictionary]];
    if (!severity) {
        severity = BugsnagSeverityWarning;
    }

    [self.metaDataLock lock];
    [self serializeDictionary: metaData toJSON: &g_bugsnag_data.metaDataJSON];
    [self.state addAttribute:@"severity" withValue: severity toTabWithName: @"crash"];
    [self.state addAttribute:@"depth" withValue: [NSNumber numberWithUnsignedInteger:depth + 3] toTabWithName: @"crash"];
    [self serializeBreadcrumbs];
    NSString *exceptionName = [exception name] != nil ? [exception name] : @"NSException";
    [[KSCrash sharedInstance] reportUserException:exceptionName reason:[exception reason] lineOfCode:@"" stackTrace:@[] terminateProgram:NO];

    // Restore metaData to pre-crash state.
    [self.metaDataLock unlock];
    [self metaDataChanged: self.configuration.metaData];
    [[self state] clearTab:@"crash"];

    [self performSelectorInBackground:@selector(sendPendingReports) withObject:nil];
}

- (void) serializeBreadcrumbs {
    BugsnagBreadcrumbs* crumbs = self.configuration.breadcrumbs;
    if (crumbs.count == 0) {
        return;
    }
    [self.state addAttribute:@"breadcrumbs" withValue:[crumbs arrayValue] toTabWithName:@"crash"];
}

- (void) sendPendingReports {
    @autoreleasepool {
        @try {
            [[KSCrash sharedInstance] sendAllReportsWithCompletion:^(NSArray *filteredReports, BOOL completed, NSError *error) {
                NSLog(@"Bugsnag reports sent.");
            }];
        }
        @catch (NSException* e) {
            NSLog(@"Error sending report to Bugsnag: %@", e);
        }
    }
}

- (void) metaDataChanged:(BugsnagMetaData *)metaData {

    if (metaData == self.configuration.metaData) {
        if ([self.metaDataLock tryLock]) {
            [self serializeDictionary: [metaData toDictionary] toJSON: &g_bugsnag_data.metaDataJSON];
            [self.metaDataLock unlock];
        }
    } else if (metaData == self.configuration.config) {
        [self serializeDictionary: [metaData getTab:@"config"] toJSON: &g_bugsnag_data.configJSON];
    } else if (metaData == self.state) {
        [self serializeDictionary: [metaData toDictionary] toJSON: &g_bugsnag_data.stateJSON];
    } else {
        NSLog(@"Unknown meta-Data dictionary changed");
    }
}

- (void) serializeDictionary: (NSDictionary*) dictionary toJSON: (char **) destination {
    NSError *error;
    NSData *json = [KSJSONCodec encode: dictionary options:0 error:&error];

    if (!json) {
        NSLog(@"Bugsnag could not serialize metaData: %@", error);
        return;
    }

    *destination = reallocf(*destination, [json length] + 1);
    if (*destination) {
        memcpy(*destination, [json bytes], [json length]);
        (*destination)[[json length]] = '\0';
    }
}
@end
