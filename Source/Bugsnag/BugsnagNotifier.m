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

NSString *const NOTIFIER_VERSION = @"4.1.0";
NSString *const NOTIFIER_URL = @"https://github.com/bugsnag/bugsnag-cocoa";
NSString *const BSTabCrash = @"crash";
NSString *const BSTabConfig = @"config";
NSString *const BSAttributeSeverity = @"severity";
NSString *const BSAttributeDepth = @"depth";
NSString *const BSAttributeBreadcrumbs = @"breadcrumbs";

struct bugsnag_data_t {
    // Contains the user-specified metaData, including the user tab from config.
    char *metaDataJSON;
    // Contains the Bugsnag configuration, all under the "config" tab.
    char *configJSON;
    // Contains notifier state, under "deviceState" and crash-specific information under "crash".
    char *stateJSON;
};

static struct bugsnag_data_t g_bugsnag_data;

/**
 *  Handler executed when the application crashes. Writes information about the
 *  current application state using the crash report writer.
 *
 *  @param writer report writer which will receive updated metadata
 */
void BSSerializeDataCrashHandler(const KSCrashReportWriter *writer) {
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

/**
 *  Writes a dictionary to a destination using the KSCrash JSON encoding
 *
 *  @param dictionary  data to encode
 *  @param destination target location of the data
 */
void BSSerializeJSONDictionary(NSDictionary *dictionary, char **destination) {
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
    [KSCrash sharedInstance].deleteBehaviorAfterSendAll = KSCDeleteOnSucess;
    [KSCrash sharedInstance].onCrash = &BSSerializeDataCrashHandler;

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
    BSSerializeJSONDictionary(metaData, &g_bugsnag_data.metaDataJSON);
    [self.state addAttribute:BSAttributeSeverity withValue:severity toTabWithName:BSTabCrash];
    [self.state addAttribute:BSAttributeDepth withValue:@(depth + 3) toTabWithName:BSTabCrash];
    NSString *exceptionName = [exception name] ?: NSStringFromClass([NSException class]);
    [[KSCrash sharedInstance] reportUserException:exceptionName reason:[exception reason] lineOfCode:@"" stackTrace:@[] terminateProgram:NO];

    // Restore metaData to pre-crash state.
    [self.metaDataLock unlock];
    [self metaDataChanged: self.configuration.metaData];
    [[self state] clearTab:BSTabCrash];

    [self performSelectorInBackground:@selector(sendPendingReports) withObject:nil];
}

- (void) serializeBreadcrumbs {
    BugsnagBreadcrumbs* crumbs = self.configuration.breadcrumbs;
    NSArray* arrayValue = crumbs.count == 0 ? nil : [crumbs arrayValue];
    [self.state addAttribute:BSAttributeBreadcrumbs withValue:arrayValue toTabWithName:BSTabCrash];
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
            BSSerializeJSONDictionary([metaData toDictionary], &g_bugsnag_data.metaDataJSON);
            [self.metaDataLock unlock];
        }
    } else if (metaData == self.configuration.config) {
        BSSerializeJSONDictionary([metaData getTab:BSTabConfig], &g_bugsnag_data.configJSON);
    } else if (metaData == self.state) {
        BSSerializeJSONDictionary([metaData toDictionary], &g_bugsnag_data.stateJSON);
    } else {
        NSLog(@"Unknown metadata dictionary changed");
    }
}

@end
