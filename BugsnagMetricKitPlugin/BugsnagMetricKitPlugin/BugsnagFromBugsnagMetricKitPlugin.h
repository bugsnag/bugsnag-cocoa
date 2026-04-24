//
//  BugsnagFromBugsnagMetricKitPlugin.h
//  BugsnagMetricKitPlugin
//
//  Created by Robert Bartoszewski on 27/03/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BugsnagEvent;
@class BugsnagStackframe;

NS_ASSUME_NONNULL_BEGIN

/**
 * Bridge from BugsnagMetricKitPlugin to Bugsnag.
 *
 * IMPORTANT: This class name MUST be globally unique across ALL Bugsnag libraries that contain native code!
 * When cloning this code as a template for your own bridge, always use the naming style "TargetLibraryFromSourceLibrary"
 * For example:
 * * "BugsnagCocoaPerformanceFromBugsnagUnity" (bridge from Bugsnag Unity to Bugsnag Cocoa Performance)
 * * "BugsnagFromBugsnagMetricKitPlugin" (bridge from BugsnagMetricKitPlugin to Bugsnag)
 */
@interface BugsnagFromBugsnagMetricKitPlugin : NSObject

#pragma mark - Methods that will be bridged to Bugsnag

/**
 * Symbolicate an array of stack frames.
 *
 * @param stackframes Array of BugsnagStackframe objects to symbolicate
 */
- (void)symbolicateStackframes:(NSArray<BugsnagStackframe *> *)stackframes;

/**
 * Create and notify a plain event without automatic enrichment.
 *
 * @param errorClass The error class name
 * @param errorMessage The error message
 * @param stacktrace Array of BugsnagStackframe objects
 * @param timestamp Event timestamp (or nil for current time)
 * @param block Optional callback to customize the event before sending
 */
- (void)notifyPlainEvent:(NSString *)errorClass
            errorMessage:(NSString *)errorMessage
              stacktrace:(NSArray<BugsnagStackframe *> *)stacktrace
               timestamp:(NSDate * _Nullable)timestamp
                   block:(BOOL (^ _Nullable)(BugsnagEvent *event))block;

#pragma mark - Shared Instance

+ (instancetype _Nullable)sharedInstance;

@end

NS_ASSUME_NONNULL_END
