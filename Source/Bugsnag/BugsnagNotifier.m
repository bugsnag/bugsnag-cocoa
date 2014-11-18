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
#import "BugsnagNotifier.h"
#import "BugsnagSink.h"
#import "KSCrash.h"
#import "KSCrashAdvanced.h"
#import "KSCrashReportWriter.h"
#import "KSJSONCodecObjC.h"
#import "KSSafeCollections.h"
#import "NSDictionary+Merge.h"

@implementation BugsnagNotifier

@synthesize configuration;

- (id) initWithConfiguration:(BugsnagConfiguration*) initConfiguration {
    if((self = [super init])) {
        self.configuration = initConfiguration;
        self.configuration.metaData.delegate = self;
        [self metaDataChanged:self.configuration.metaData];
    }
    return self;
}

- (void) start {
    [KSCrash sharedInstance].sink = [[BugsnagSink alloc] init];
    // We don't use this feature yet, so we turn it off to avoid any possibility of bugs.
    [KSCrash sharedInstance].introspectMemory = NO;
    
    if (configuration.autoNotify) {
        [[KSCrash sharedInstance] install];
    }
    
    [self performSelectorInBackground:@selector(sendPendingReports) withObject:nil];
}

- (void)notify:(NSException *)exception withData:(NSDictionary *)metaData atSeverity:(NSString *)severity atDepth:(NSUInteger) depth {
    
    if (!metaData) {
        metaData = [[NSDictionary alloc] init];
    }
    [KSCrash sharedInstance].userInfo = @{@"metaData": [metaData mergedInto: [[self configuration].metaData toDictionary]],
                                          @"context": [self configuration].context ? [self configuration].context : [NSNull null],
                                          @"severity": severity ? severity : BugsnagSeverityWarning,
                                          @"depth": [NSNumber numberWithUnsignedInteger:depth + 3]};
    
    [[KSCrash sharedInstance] reportUserException:[exception name] reason:[exception reason] lineOfCode:@"" stackTrace:@[] terminateProgram:NO];
    
    // Reset the KSCrash userInfo.
    [self metaDataChanged:[self configuration].metaData];
    
    [self performSelectorInBackground:@selector(sendPendingReports) withObject:nil];
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
    [KSCrash sharedInstance].userInfo = @{@"metaData": [metaData toDictionary],
                                          @"severity": BugsnagSeverityError,
                                          @"context": [self configuration].context ? [self configuration].context : [NSNull null],
                                          @"depth": [NSNumber numberWithUnsignedInteger:0]};
}
@end
