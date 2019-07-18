//
//  BSG_KSCrash.h
//
//  Created by Karl Stenerud on 2012-01-28.
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

#import <Foundation/Foundation.h>

#import "BSG_KSSystemCapabilities.h"
#import "BSG_KSCrashReportFilterCompletion.h"
#import "BSG_KSCrashReportWriter.h"
#import "BSG_KSCrashType.h"

typedef enum {
    BSG_KSCDeleteNever,
    BSG_KSCDeleteOnSucess,
    BSG_KSCDeleteAlways
} BSG_KSCDeleteBehavior;

/**
 * Reports any crashes that occur in the application.
 *
 * The crash reports will be located in $APP_HOME/Library/Caches/KSCrashReports
 */
@interface BSG_KSCrash : NSObject

/** A dictionary containing any info you'd like to appear in crash reports. Must
 * contain only JSON-safe data: NSString for keys, and NSDictionary, NSArray,
 * NSString, NSDate, and NSNumber for values.
 *
 * Default: nil
 */
@property(nonatomic, readwrite, retain) NSDictionary *userInfo;

/** What to do after sending reports via sendAllReportsWithCompletion:
 *
 * - Use KSCDeleteNever if you will manually manage the reports.
 * - Use KSCDeleteAlways if you will be using an alert confirmation (otherwise
 * it will nag the user incessantly until he selects "yes").
 * - Use KSCDeleteOnSuccess for all other situations.
 *
 * Default: KSCDeleteAlways
 */
@property(nonatomic, readwrite, assign)
    BSG_KSCDeleteBehavior deleteBehaviorAfterSendAll;

/** The crash types that are being handled.
 * Note: This value may change once BSG_KSCrash is installed if some handlers
 *       fail to install.
 */
@property(nonatomic, readwrite, assign) BSG_KSCrashType handlingCrashTypes;

/** Maximum time to allow the main thread to run without returning.
 * If a task occupies the main thread for longer than this interval, the
 * watchdog will consider the queue deadlocked and shut down the app and write a
 * crash report.
 *
 * Warning: Make SURE that nothing in your app that runs on the main thread
 * takes longer to complete than this value or it WILL get shut down! This
 * includes your app startup process, so you may need to push app initialization
 * to another thread, or perhaps set this to a higher value until your
 * application has been fully initialized.
 *
 * WARNING: This is still causing false positives in some cases. Use at own
 * risk!
 *
 * 0 = Disabled.
 *
 * Default: 0
 */
@property(nonatomic, readwrite, assign) double deadlockWatchdogInterval;

/** If YES, introspect memory contents during a crash.
 * Any Objective-C objects or C strings near the stack pointer or referenced by
 * cpu registers or exceptions will be recorded in the crash report, along with
 * their contents.
 *
 * Default: YES
 */
@property(nonatomic, readwrite, assign) bool introspectMemory;


/** List of Objective-C classes that should never be introspected.
 * Whenever a class in this list is encountered, only the class name will be
 * recorded. This can be useful for information security concerns.
 *
 * Default: nil
 */
@property(nonatomic, readwrite, retain) NSArray *doNotIntrospectClasses;

/** Get the singleton instance of the crash reporter.
 */
+ (BSG_KSCrash *)sharedInstance;

/** Install the crash reporter.
 * The reporter will record crashes, but will not send any crash reports unless
 * sink is set.
 *
 * @return YES if the reporter successfully installed.
 */
- (BOOL)install;

/** Send any outstanding crash reports to the current sink.
 * It will only attempt to send the most recent 5 reports. All others will be
 * deleted. Once the reports are successfully sent to the server, they may be
 * deleted locally, depending on the property "deleteAfterSendAll".
 *
 * Note: property "sink" MUST be set or else this method will call onCompletion
 *       with an error.
 *
 * @param onCompletion Called when sending is complete (nil = ignore).
 */
- (void)sendAllReportsWithCompletion:
    (BSG_KSCrashReportFilterCompletion)onCompletion;

/** Delete all unsent reports.
 */
- (void)deleteAllReports;

/** Report a custom, user defined exception.
 * This can be useful when dealing with scripting languages.
 *
 * If terminateProgram is true, all sentries will be uninstalled and the
 * application will terminate with an abort().
 *
 * @param name The exception name (for namespacing exception types).
 * @param reason A description of why the exception occurred
 * @param exception The exception which was thrown (if any)
 * @param handledState The severity, reason, and handled-ness of the report
 * @param appState breadcrumbs and other app environmental info
 * @param overrides Report fields overridden by callbacks, collated in the
 *        final report
 * @param metadata additional information to attach to the report
 * @param config delivery options
 * @param depth The number of frames to discard from the top of the stacktrace
 * @param terminateProgram If true, do not return from this function call.
 * Terminate the program instead.
 */
- (void)reportUserException:(NSString *)name
                     reason:(NSString *)reason
          originalException:(NSException *)exception
               handledState:(NSDictionary *)handledState
                   appState:(NSDictionary *)appState
          callbackOverrides:(NSDictionary *)overrides
                   metadata:(NSDictionary *)metadata
                     config:(NSDictionary *)config
               discardDepth:(int)depth
           terminateProgram:(BOOL)terminateProgram;

/** If YES, user reported exceptions will suspend all threads during report
 * generation. All threads will be suspended while generating a crash report for
 * a user reported exception.
 *
 * Default: YES
 */
@property(nonatomic, readwrite, assign) BOOL suspendThreadsForUserReported;

/** If YES, reports will be sent even if a debugger is attached
 *
 * Default: NO
 */
@property(nonatomic, readwrite, assign) BOOL reportWhenDebuggerIsAttached;

/**
 * If YES, thread traces will be collected with each report.
 */
@property(nonatomic, readwrite, assign) BOOL threadTracingEnabled;

/**
 * If YES, binary images will be collected for each report.
 */
@property(nonatomic, readwrite, assign) BOOL writeBinaryImagesForUserReported;

@end

//! Project version number for BSG_KSCrashFramework.
FOUNDATION_EXPORT const double BSG_KSCrashFrameworkVersionNumber;

//! Project version string for BSG_KSCrashFramework.
FOUNDATION_EXPORT const unsigned char BSG_KSCrashFrameworkVersionString[];
