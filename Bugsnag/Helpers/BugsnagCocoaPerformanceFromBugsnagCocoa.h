//
//  BugsnagCocoaPerformanceFromBugsnagCocoa.h
//  Bugsnag
//
//  Created by Karl Stenerud on 13.05.24.
//  Copyright © 2024 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Bridge from Bugsnag Coca to Bugsnag Cocoa Performance.
 *
 * IMPORTANT: This class name MUST be globally unique across ALL Bugsnag libraries that contain native code!
 * When cloning this code as a template for your own bridge, always use the naming style "YourLibraryFromMyLibrary"
 * For example:
 * * "BugsnagCocoaPerformanceFromBugsnagUnity" (bridge from Bugsnag Unity to Bugsnag Cocoa Performance)
 * * "BugsnagCocoaFromBugsnagReactNativePerformance" (bridge from Bugsnag Performance React Native to Bugsnag Cocoa)
 */
@interface BugsnagCocoaPerformanceFromBugsnagCocoa: NSObject

#pragma mark Methods that will be bridged to BugsnagPerformance

/**
 * Return the current trace and span IDs as strings in a 2-entry array, or return nil if no current span exists.
 *
 * array[0] is an NSString containing the trace ID
 * array[1] is an NSString containing the span ID
 */
- (NSArray * _Nullable)getCurrentTraceAndSpanId;

#pragma mark Shared Instance

+ (instancetype _Nullable) sharedInstance;

@end

NS_ASSUME_NONNULL_END
