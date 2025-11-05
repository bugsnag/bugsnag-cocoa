//
//  BugsnagCaptureOptions.h
//  Bugsnag
//
//  Created by Daria Bialobrzeska on 25/10/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Bugsnag/BugsnagDefines.h>

/**
 * The `BugsnagCaptureOptions` interface defines the set of granular flags for controlling data capture at `notify` time.
 * All properties are optional, and default to `true` unless otherwise stated.
 */
BUGSNAG_EXTERN
@interface BugsnagCaptureOptions : NSObject

/**
 * When `breadcrumbs` is `false`, the `Event` shall be created without populating the `breadcrumbs` property.
 */
@property (readwrite, nonatomic) BOOL breadcrumbs;

/**
 * When `featureFlags` is `false`, the `Event` shall be created without populating the `featureFlags` property.
 */
@property (readwrite, nonatomic) BOOL featureFlags;

/**
 * Controls which **custom metadata tabs** are included.
 * `app` and `device` data will **always** be added.
 * When `metadata` is not provided or is `nil`, all custom metadata tabs shall be captured.
 * When `metadata` is provided as an empty array (`[]`), no custom metadata tabs shall be captured.
 * When `metadata` is provided as a string array:
 *  - Each value shall represent a metadata tab name to include.
 *  - If a tab name does not exist, it shall be ignored without error.
 */
@property (copy, nullable, nonatomic) NSArray<NSString *> *metadata;

/**
 * When `stacktrace` is `false`, the `Error` objects in the `Event` shall be created without populating the `stacktrace` property.
 */
@property (readwrite, nonatomic) BOOL stacktrace;

/**
 * When `threads` is `false`, the `Event` shall be created without populating the `threads` property.
 */
@property (readwrite, nonatomic) BOOL threads;

/**
 * When `user` is `false`, the `Event` shall be created without populating the `user` property.
 */
@property (readwrite, nonatomic) BOOL user;

@end

/**
 * The `BugsnagErrorOptions` interface allows developers to control how handled errors are reported and which optional data fields should be captured.
 * `capture` shall only affect handled errors reported through the `notify` method.
 * `capture` shall have no effect on automatically detected errors.
 * When a capture flag is set to `false`, the corresponding data shall **not be captured** during `Event` creation (rather than being captured and removed later).
 * The `Error` properties (`errorClass`, `errorMessage`, `type`) shall **always** be captured regardless of capture settings.
 */
BUGSNAG_EXTERN
@interface BugsnagErrorOptions : NSObject

@property (strong, nullable, nonatomic) BugsnagCaptureOptions *capture;

@end
