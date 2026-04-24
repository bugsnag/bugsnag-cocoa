//
//  BugsnagCrossTalkAPI.h
//  Bugsnag
//
//  Created by Robert Bartoszewski on 27/03/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

// Bugsnag CrossTalk API
//
// CrossTalk is an Objective-C layer for sharing private APIs between Bugsnag libraries.
// It allows client libraries (like BugsnagMetricKitPlugin) to call internal functions
// without the usual worries of breaking downstream clients whenever internal code changes.
//
// This API exposes methods for:
// - Reporting errors (notifyError:block:)
// - Symbolicating stack frames (symbolicateStackframes:)
//
// NOTE: This class name MUST be globally unique across ALL Bugsnag libraries!

#import <Foundation/Foundation.h>

@class BugsnagClient;
@class BugsnagEvent;
@class BugsnagStackframe;

NS_ASSUME_NONNULL_BEGIN

/**
 * CrossTalk API for Bugsnag error reporting and symbolication.
 * Allows plugins like BugsnagMetricKitPlugin to access Bugsnag functionality.
 */
@interface BugsnagCrossTalkAPI : NSObject

+ (instancetype) sharedInstance;

/**
 * Initialize the CrossTalk API with a Bugsnag client.
 * This should be called during Bugsnag startup.
 *
 * @param client The BugsnagClient instance to use for error reporting
 */
+ (void)initializeWithClient:(BugsnagClient *)client;

/**
 * Map a named API to a method with the specified selector.
 * This is used by client libraries to safely access versioned APIs.
 *
 * @param apiName The name of the API version (e.g., "notifyErrorV1")
 * @param toSelector The selector to map the API to
 * @return An error if mapping failed, or nil on success
 */
+ (NSError * _Nullable)mapAPINamed:(NSString *)apiName toSelector:(SEL)toSelector;

#pragma mark - Internal API Methods (Not for direct use - accessed via mapAPINamed:)

// These methods are internal and accessed via runtime mapping.
// DO NOT call these directly - use the mapped selectors instead.

/**
 * Create a plain event without automatic enrichment (V1).
 * Internal versioned method - access via mapAPINamed:@"notifyPlainEventV1:errorMessage:stacktrace:timestamp:block:"
 *
 * @param errorClass The error class name
 * @param errorMessage The error message
 * @param stacktrace Array of BugsnagStackframe objects
 * @param timestamp Event timestamp (or nil for current time)
 * @param block Optional callback to customize the event before sending
 */
- (void)notifyPlainEventV1:(NSString *)errorClass
              errorMessage:(NSString *)errorMessage
                stacktrace:(NSArray<BugsnagStackframe *> *)stacktrace
                 timestamp:(NSDate * _Nullable)timestamp
                     block:(BOOL (^ _Nullable)(BugsnagEvent *event))block;

@end

/**
 * A very permissive proxy that won't crash if a method or property doesn't exist.
 *
 * When returning instances of Bugsnag classes, wrap them in this proxy so that
 * they don't crash when that class's API changes.
 *
 * WARNING: Returning internal classes is effectively creating a contract between Bugsnag libraries!
 * Be VERY conservative about any internal class you expose, because its interfaces will effectively
 * be "published", and changing a method's signature could break client libraries that use it.
 *
 * Adding/removing methods/properties is fine, but changing signatures WILL break things.
 *
 * Some ways to protect against breakage due to changed method signatures:
 * - Convert to maps and arrays instead
 * - Create custom classes designed specifically for library interop
 * - Create versioned wrapper methods in the classes and access those instead (doStuffV1, doStuffV2, etc)
 */
@interface BugsnagCrossTalkProxiedObject : NSProxy

+ (instancetype _Nullable) proxied:(id _Nullable)delegate;

@end

NS_ASSUME_NONNULL_END
