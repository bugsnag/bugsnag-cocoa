//
//  Bugsnag.m
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
#import "BugsnagBreadcrumb.h"
#import "BugsnagConfiguration.h"
#import "BugsnagNotifier.h"
#import "BugsnagSink.h"
#import <KSCrash/KSCrashAdvanced.h>

static BugsnagNotifier* g_bugsnag_notifier = NULL;

@interface Bugsnag ()
+ (BugsnagNotifier*)notifier;
+ (BOOL) bugsnagStarted;
@end

@implementation Bugsnag

+ (void)startBugsnagWithApiKey:(NSString*)apiKey {
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] init];
    configuration.apiKey = apiKey;

    [self startBugsnagWithConfiguration:configuration];
}

+ (void)startBugsnagWithConfiguration:(BugsnagConfiguration*) configuration {
    g_bugsnag_notifier = [[BugsnagNotifier alloc] initWithConfiguration:configuration];
    [g_bugsnag_notifier start];
}

+ (BugsnagConfiguration*)configuration {
    if([self bugsnagStarted]) {
        return self.notifier.configuration;
    }
    return nil;
}

+ (BugsnagConfiguration*)instance {
    return [self configuration];
}

+ (BugsnagNotifier*)notifier {
    return g_bugsnag_notifier;
}

+ (void) notify:(NSException *)exception {
    [self.notifier notify:exception withData:nil atSeverity: BugsnagSeverityWarning atDepth: 1];
}

+ (void) notify:(NSException *)exception withData:(NSDictionary*)metaData {
    [self.notifier notify:exception withData:metaData atSeverity: BugsnagSeverityWarning atDepth: 1];
}

+ (void) notify:(NSException *)exception withData:(NSDictionary*)metaData atSeverity:(NSString*)severity {
    [self.notifier notify:exception withData:metaData atSeverity: severity atDepth: 1];
}

+ (void) addAttribute:(NSString*)attributeName withValue:(id)value toTabWithName:(NSString*)tabName {
    if([self bugsnagStarted]) {
        [self.notifier.configuration.metaData addAttribute:attributeName withValue:value toTabWithName:tabName];
    }
}

+ (void) clearTabWithName:(NSString*)tabName {
    if([self bugsnagStarted]) {
        [self.notifier.configuration.metaData clearTab:tabName];
    }
}

+ (BOOL) bugsnagStarted {
    if (self.notifier == nil) {
        NSLog(@"Ensure you have started Bugsnag with startWithApiKey: before calling any other Bugsnag functions.");

        return false;
    }
    return true;
}

+ (void) leaveBreadcrumbWithMessage:(NSString *)message {
    [self.notifier.configuration.breadcrumbs addBreadcrumb:message];
    [self.notifier serializeBreadcrumbs];
}

+ (void) setBreadcrumbCapacity:(NSUInteger)capacity {
    self.notifier.configuration.breadcrumbs.capacity = capacity;
}

+ (void) clearBreadcrumbs {
    [self.notifier.configuration.breadcrumbs clearBreadcrumbs];
    [self.notifier serializeBreadcrumbs];
}

+ (NSDateFormatter *)payloadDateFormatter {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        formatter.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ssZZZ";
    });
    return formatter;
}

@end
