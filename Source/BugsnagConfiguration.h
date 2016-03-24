//
//  BugsnagConfiguration.h
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

#import "BSGKSCrashReportWriter.h"
#import "BugsnagBreadcrumb.h"
#import "BugsnagMetaData.h"
#import <Foundation/Foundation.h>

/**
 *  A handler for modifying data before sending it to Bugsnag
 *
 *  @param rawEventReports The raw event data written at crash time. This
 *                         includes data added in onCrashHandler.
 *  @param report          The default report payload
 *
 *  @return the report payload intended to be sent or nil to cancel sending
 */
typedef NSDictionary *_Nullable (^BugsnagBeforeNotifyHook)(
    NSArray *_Nonnull rawEventReports, NSDictionary *_Nonnull report);

@class BugsnagBreadcrumbs;

@interface BugsnagConfiguration : NSObject

@property(nonatomic, readwrite, retain, nullable) NSString *apiKey;
@property(nonatomic, readwrite, retain, nullable) NSURL *notifyURL;
@property(nonatomic, readwrite, retain, nullable) NSString *releaseStage;
@property(nonatomic, readwrite, retain, nullable) NSArray *notifyReleaseStages;
@property(nonatomic, readwrite, retain, nullable) NSString *context;
@property(nonatomic, readwrite, retain, nullable) NSString *appVersion;
@property(nonatomic, readwrite, retain, nullable) BugsnagMetaData *metaData;
@property(nonatomic, readwrite, retain, nullable) BugsnagMetaData *config;
@property(nonatomic, readonly, strong, nullable)
    BugsnagBreadcrumbs *breadcrumbs;
@property(nonatomic, readonly, strong, nullable) NSArray *beforeNotifyHooks;
@property(nonatomic) void (*_Nullable onCrashHandler)
    (const BSGKSCrashReportWriter *_Nonnull writer);

@property(nonatomic) BOOL autoNotify;

- (void)setUser:(NSString *_Nullable)userId
       withName:(NSString *_Nullable)name
       andEmail:(NSString *_Nullable)email;

- (void)addBeforeNotifyHook:(BugsnagBeforeNotifyHook _Nonnull)hook;

@end
