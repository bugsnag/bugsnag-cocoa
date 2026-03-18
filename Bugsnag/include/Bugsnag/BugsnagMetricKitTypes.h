//
//  BugsnagMetricKitTypes.h
//  Bugsnag
//
//  Created by Robert Bartoszewski on 09/03/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Bugsnag/BugsnagDefines.h>

/**
 * The types of MetricKit diagnostics that should be reported.
 */
BUGSNAG_EXTERN
@interface BugsnagMetricKitTypes : NSObject

/**
 * Determines whether MetricKit integration is enabled.
 *
 * This flag is false by default (opt-in).
 */
@property (nonatomic) BOOL enabled;

/**
 * Determines whether MetricKit crash diagnostics should be reported to Bugsnag.
 *
 * This flag is true by default when MetricKit is enabled.
 */
@property (nonatomic) BOOL crashDiagnostics;

/**
 * Determines whether MetricKit CPU exception diagnostics should be reported to Bugsnag.
 *
 * This flag is true by default when MetricKit is enabled.
 */
@property (nonatomic) BOOL cpuExceptionDiagnostics;

/**
 * Determines whether MetricKit app launch diagnostics should be reported to Bugsnag.
 *
 * This flag is true by default when MetricKit is enabled.
 */
@property (nonatomic) BOOL appLaunchDiagnostics;

/**
 * Determines whether MetricKit hang diagnostics should be reported to Bugsnag.
 *
 * This flag is true by default when MetricKit is enabled.
 */
@property (nonatomic) BOOL hangDiagnostics;

/**
 * Determines whether MetricKit disk write exception diagnostics should be reported to Bugsnag.
 *
 * This flag is true by default when MetricKit is enabled.
 */
@property (nonatomic) BOOL diskWriteExceptionDiagnostics;

@end
