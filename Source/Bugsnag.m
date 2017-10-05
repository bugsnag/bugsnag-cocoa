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
#import "BSG_KSCrash.h"
#import "BugsnagBreadcrumb.h"
#import "BugsnagCrashReport.h"
#import "BugsnagLogger.h"
#import "BugsnagNotifier.h"
#import "BugsnagSink.h"

static BugsnagNotifier *bsg_g_bugsnag_notifier = NULL;

@interface Bugsnag ()
+ (BugsnagNotifier *)notifier;
+ (BOOL)bugsnagStarted;
@end

@interface NSDictionary (BSGKSMerge)
- (NSDictionary *)BSG_mergedInto:(NSDictionary *)dest;
@end

@implementation Bugsnag

+ (void)startBugsnagWithApiKey:(NSString *)apiKey {
    BugsnagConfiguration *configuration = [BugsnagConfiguration new];
    configuration.apiKey = apiKey;
    [self startBugsnagWithConfiguration:configuration];
}

+ (void)startBugsnagWithConfiguration:(BugsnagConfiguration *)configuration {
    bsg_g_bugsnag_notifier =
        [[BugsnagNotifier alloc] initWithConfiguration:configuration];
    [bsg_g_bugsnag_notifier start];
}

+ (BugsnagConfiguration *)configuration {
    if ([self bugsnagStarted]) {
        return self.notifier.configuration;
    }
    return nil;
}

+ (BugsnagConfiguration *)instance {
    return [self configuration];
}

+ (BugsnagNotifier *)notifier {
    return bsg_g_bugsnag_notifier;
}

+ (void)notify:(NSException *)exception {
    [self.notifier notifyException:exception
                             block:^(BugsnagCrashReport *_Nonnull report) {
                               report.depth += 2;
                             }];
}

+ (void)notify:(NSException *)exception block:(BugsnagNotifyBlock)block {
    [[self notifier] notifyException:exception
                               block:^(BugsnagCrashReport *_Nonnull report) {
                                 report.depth += 2;

                                 if (block) {
                                     block(report);
                                 }
                               }];
}

+ (void)notifyError:(NSError *)error {
    [self.notifier notifyError:error
                         block:^(BugsnagCrashReport *_Nonnull report) {
                           report.depth += 2;
                         }];
}

+ (void)notifyError:(NSError *)error block:(BugsnagNotifyBlock)block {
    [[self notifier] notifyError:error
                           block:^(BugsnagCrashReport *_Nonnull report) {
                             report.depth += 2;

                             if (block) {
                                 block(report);
                             }
                           }];
}

+ (void)notify:(NSException *)exception withData:(NSDictionary *)metaData {

    [[self notifier]
        notifyException:exception
                  block:^(BugsnagCrashReport *_Nonnull report) {
                    report.depth += 2;
                    report.metaData = [metaData
                        BSG_mergedInto:[self.notifier.configuration
                                               .metaData toDictionary]];
                  }];
}

+ (void)notify:(NSException *)exception
      withData:(NSDictionary *)metaData
    atSeverity:(NSString *)severity {

    [[self notifier]
        notifyException:exception
             atSeverity:BSGParseSeverity(severity)
                  block:^(BugsnagCrashReport *_Nonnull report) {
                    report.depth += 2;
                    report.metaData = [metaData
                        BSG_mergedInto:[self.notifier.configuration
                                               .metaData toDictionary]];
                    report.severity = BSGParseSeverity(severity);
                  }];
}

+ (void)internalClientNotify:(NSException *_Nonnull)exception
                    withData:(NSDictionary *_Nullable)metaData
                       block:(BugsnagNotifyBlock _Nullable)block {
    [self.notifier internalClientNotify:exception
                               withData:metaData
                                  block:block];
}

+ (void)addAttribute:(NSString *)attributeName
           withValue:(id)value
       toTabWithName:(NSString *)tabName {
    if ([self bugsnagStarted]) {
        [self.notifier.configuration.metaData addAttribute:attributeName
                                                 withValue:value
                                             toTabWithName:tabName];
    }
}

+ (void)clearTabWithName:(NSString *)tabName {
    if ([self bugsnagStarted]) {
        [self.notifier.configuration.metaData clearTab:tabName];
    }
}

+ (BOOL)bugsnagStarted {
    if (self.notifier == nil) {
        bsg_log_err(@"Ensure you have started Bugsnag with startWithApiKey: "
                    @"before calling any other Bugsnag functions.");

        return NO;
    }
    return YES;
}

+ (void)leaveBreadcrumbWithMessage:(NSString *)message {
    [self leaveBreadcrumbWithBlock:^(BugsnagBreadcrumb *_Nonnull crumbs) {
      crumbs.metadata = @{@"message" : message};
    }];
}

+ (void)leaveBreadcrumbWithBlock:
    (void (^_Nonnull)(BugsnagBreadcrumb *_Nonnull))block {
    [self.notifier addBreadcrumbWithBlock:block];
}

+ (void)leaveBreadcrumbForNotificationName:
    (NSString *_Nonnull)notificationName {
    [self.notifier crumbleNotification:notificationName];
}

+ (void)setBreadcrumbCapacity:(NSUInteger)capacity {
    self.notifier.configuration.breadcrumbs.capacity = capacity;
}

+ (void)clearBreadcrumbs {
    [self.notifier clearBreadcrumbs];
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

+ (void)setSuspendThreadsForUserReported:(BOOL)suspendThreadsForUserReported {
    [[BSG_KSCrash sharedInstance]
        setSuspendThreadsForUserReported:suspendThreadsForUserReported];
}

+ (void)setReportWhenDebuggerIsAttached:(BOOL)reportWhenDebuggerIsAttached {
    [[BSG_KSCrash sharedInstance]
        setReportWhenDebuggerIsAttached:reportWhenDebuggerIsAttached];
}

+ (void)setThreadTracingEnabled:(BOOL)threadTracingEnabled {
    [[BSG_KSCrash sharedInstance] setThreadTracingEnabled:threadTracingEnabled];
}

+ (void)setWriteBinaryImagesForUserReported:
    (BOOL)writeBinaryImagesForUserReported {
    [[BSG_KSCrash sharedInstance]
        setWriteBinaryImagesForUserReported:writeBinaryImagesForUserReported];
}

@end

//
//  NSDictionary+Merge.m
//
//  Created by Karl Stenerud on 2012-10-01.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
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

@implementation NSDictionary (BSGKSMerge)

- (NSDictionary *)BSG_mergedInto:(NSDictionary *)dest {
    if ([dest count] == 0) {
        return self;
    }
    if ([self count] == 0) {
        return dest;
    }

    NSMutableDictionary *dict = [dest mutableCopy];
    for (id key in [self allKeys]) {
        id srcEntry = [self objectForKey:key];
        id dstEntry = [dest objectForKey:key];
        if ([dstEntry isKindOfClass:[NSDictionary class]] &&
            [srcEntry isKindOfClass:[NSDictionary class]]) {
            srcEntry = [srcEntry BSG_mergedInto:dstEntry];
        }
        [dict setObject:srcEntry forKey:key];
    }
    return dict;
}

@end
