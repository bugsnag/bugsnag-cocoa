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

#import <Foundation/Foundation.h>

#import "BSG_KSCrashReportWriter.h"
#import "BugsnagBreadcrumb.h"
#import "BugsnagEvent.h"
#import "BugsnagMetadata.h"
#import "BugsnagPlugin.h"
#import "BugsnagMetadataStore.h"

@class BugsnagUser;

/**
 * BugsnagConfiguration error constants
 */
typedef NS_ENUM(NSInteger, BSGConfigurationErrorCode) {
    BSGConfigurationErrorInvalidApiKey = 0
};

/**
 *  A configuration block for modifying an error report
 *
 *  @param event the error report to be modified
 */
typedef void (^BugsnagOnErrorBlock)(BugsnagEvent *_Nonnull event);

/**
 *  A handler for modifying data before sending it to Bugsnag.
 *
 * onSendBlocks will be invoked on a dedicated
 * background queue, which will be different from the queue where the block was originally added.
 *
 *  @param event The event report.
 *
 *  @return YES if the event should be sent
 */
typedef bool (^BugsnagOnSendBlock)(BugsnagEvent *_Nonnull event);

/**
 *  A configuration block for modifying a captured breadcrumb
 *
 *  @param breadcrumb The breadcrumb
 */
typedef BOOL (^BugsnagOnBreadcrumbBlock)(BugsnagBreadcrumb *_Nonnull breadcrumb);

/**
 * A configuration block for modifying a session. Intended for internal usage only.
 *
 * @param sessionPayload The session about to be delivered
 */
typedef void(^BugsnagOnSessionBlock)(NSMutableDictionary *_Nonnull sessionPayload);

typedef NS_OPTIONS(NSUInteger, BSGEnabledErrorType) {
    BSGErrorTypesNone         NS_SWIFT_NAME(None)         = 0,
    BSGErrorTypesOOMs         NS_SWIFT_NAME(OOMs)         = 1 << 0,
    BSGErrorTypesNSExceptions NS_SWIFT_NAME(NSExceptions) = 1 << 1,
    BSGErrorTypesSignals      NS_SWIFT_NAME(Signals)      = 1 << 2,
    BSGErrorTypesCPP          NS_SWIFT_NAME(CPP)          = 1 << 3,
    BSGErrorTypesMach         NS_SWIFT_NAME(Mach)         = 1 << 4
};

// =============================================================================
// MARK: - BugsnagConfiguration
// =============================================================================

@interface BugsnagConfiguration : NSObject <BugsnagMetadataStore>

// -----------------------------------------------------------------------------
// MARK: - Properties
// -----------------------------------------------------------------------------

/**
 *  The API key of a Bugsnag project
 */
@property(readwrite, retain, nonnull) NSString *apiKey;
/**
 *  The release stage of the application, such as production, development, beta
 *  et cetera
 */
@property(readwrite, retain, nullable) NSString *releaseStage;
/**
 *  Release stages which are allowed to notify Bugsnag
 */
@property(readwrite, retain, nullable) NSArray *enabledReleaseStages;
/**
 *  A general summary of what was occuring in the application
 */
@property(readwrite, retain, nullable) NSString *context;
/**
 *  The version of the application
 */
@property(readwrite, retain, nullable) NSString *appVersion;

/**
 *  The URL session used to send requests to Bugsnag.
 */
@property(readwrite, strong, nonnull) NSURLSession *session;

/**
 *  Optional handler invoked when an error or crash occurs
 */
@property void (*_Nullable onCrashHandler)
    (const BSG_KSCrashReportWriter *_Nonnull writer);

/**
 *  YES if uncaught exceptions and other crashes should be reported automatically
 */
@property BOOL autoDetectErrors;

/**
 * Determines whether app sessions should be tracked automatically. By default this value is true.
 * If this value is updated after +[Bugsnag start] is called, only subsequent automatic sessions
 * will be captured.
 */
@property BOOL autoTrackSessions;

/**
 * The types of breadcrumbs which will be captured. By default, this is all types.
 */
@property BSGEnabledBreadcrumbType enabledBreadcrumbTypes;

@property(retain, nullable) NSString *codeBundleId;
@property(retain, nullable) NSString *appType;

/**
 * Sets the maximum number of breadcrumbs which will be stored. Once the threshold is reached,
 * the oldest breadcrumbs will be deleted.
 *
 * By default, 25 breadcrumbs are stored: this can be amended up to a maximum of 100.
 */
@property NSUInteger maxBreadcrumbs;

/**
 * Whether User information should be persisted to disk between application runs.
 * Defaults to True.
 */
@property BOOL persistUser;

// -----------------------------------------------------------------------------
// MARK: - Methods
// -----------------------------------------------------------------------------

/**
 * A bitfield defining the types of error that are reported.
 * Passed down to KSCrash in BugsnagCrashSentry.
 * Defaults to all-true
 */
@property BSGEnabledErrorType enabledErrorTypes;

/**
 * Required declaration to suppress a superclass designated-initializer error
 */
- (instancetype _Nonnull )init NS_UNAVAILABLE NS_SWIFT_UNAVAILABLE("Use initWithApiKey:");

/**
 * The designated initializer.
 */
- (instancetype _Nonnull)initWithApiKey:(NSString *_Nonnull)apiKey
    NS_DESIGNATED_INITIALIZER
    NS_SWIFT_NAME(init(_:));

/**
 * Set the endpoints to send data to. By default we'll send error reports to
 * https://notify.bugsnag.com, and sessions to https://sessions.bugsnag.com, but you can
 * override this if you are using Bugsnag Enterprise to point to your own Bugsnag endpoint.
 *
 * Please note that it is recommended that you set both endpoints. If the notify endpoint is
 * missing, an assertion will be thrown. If the session endpoint is missing, a warning will be
 * logged and sessions will not be sent automatically.
 *
 * @param notify the notify endpoint
 * @param sessions the sessions endpoint
 *
 * @throws an assertion if the notify endpoint is not a valid URL
 */

- (void)setEndpointsForNotify:(NSString *_Nonnull)notify
                     sessions:(NSString *_Nonnull)sessions NS_SWIFT_NAME(setEndpoints(notify:sessions:));

// =============================================================================
// MARK: - User
// =============================================================================

/**
 * The current user
 */
@property(readonly, retain, nonnull) BugsnagUser *user;

/**
 *  Set user metadata
 *
 *  @param userId ID of the user
 *  @param name   Name of the user
 *  @param email  Email address of the user
 */
- (void)setUser:(NSString *_Nullable)userId
      withEmail:(NSString *_Nullable)email
        andName:(NSString *_Nullable)name;

// =============================================================================
// MARK: - onSession
// =============================================================================

/**
 *  Add a callback to be invoked before a session is sent to Bugsnag.
 *
 *  @param block A block which can modify the session
 */
- (void)addOnSessionBlock:(BugsnagOnSessionBlock _Nonnull)block
    NS_SWIFT_NAME(addOnSession(block:));

/**
 * Remove a callback that would be invoked before a session is sent to Bugsnag.
 *
 * @param block The block to be removed.
 */
- (void)removeOnSessionBlock:(BugsnagOnSessionBlock _Nonnull)block
    NS_SWIFT_NAME(removeOnSession(block:));;

// =============================================================================
// MARK: - onSend
// =============================================================================

/**
 *  Add a callback to be invoked before a report is sent to Bugsnag, to
 *  change the report contents as needed
 *
 *  @param block A block which returns YES if the report should be sent
 */
- (void)addOnSendBlock:(BugsnagOnSendBlock _Nonnull)block
    NS_SWIFT_NAME(addOnSend(block:));

/**
 * Remove the callback that would be invoked before an event is sent.
 *
 * @param block The block to be removed.
 */
- (void)removeOnSendBlock:(BugsnagOnSendBlock _Nonnull)block
    NS_SWIFT_NAME(removeOnSend(block:));

// =============================================================================
// MARK: - onBreadcrumb
// =============================================================================

/**
 *  Add a callback to be invoked when a breadcrumb is captured by Bugsnag, to
 *  change the breadcrumb contents as needed
 *
 *  @param block A block which returns YES if the breadcrumb should be captured
 */
- (void)addOnBreadcrumbBlock:(BugsnagOnBreadcrumbBlock _Nonnull)block
    NS_SWIFT_NAME(addOnBreadcrumb(block:));

/**
 * Remove the callback that would be invoked when a breadcrumb is captured.
 *
 * @param block The block to be removed.
 */
- (void)removeOnBreadcrumbBlock:(BugsnagOnBreadcrumbBlock _Nonnull)block
    NS_SWIFT_NAME(removeOnBreadcrumb(block:));

- (void)addPlugin:(id<BugsnagPlugin> _Nonnull)plugin;

/**
 * Should the specified type of breadcrumb be recorded?
 *
 * @param type The type of breadcrumb
 *
 * @returns A boolean indicating whether the specified breadcrumb type should be recorded
 */
- (BOOL)shouldRecordBreadcrumbType:(BSGBreadcrumbType)type;
@end
