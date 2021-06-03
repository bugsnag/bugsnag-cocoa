//
// Created by Jamie Lynch on 23/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

#import <Bugsnag/Bugsnag.h>

// These headers expose some Bugsnag private APIs
#import "AttachCustomStacktraceHook.h"
#import "BugsnagHooks.h"

NS_ASSUME_NONNULL_BEGIN

void markErrorHandledCallback(const BSG_KSCrashReportWriter *writer);

@interface Scenario : NSObject

@property (strong, nonatomic, nonnull) BugsnagConfiguration *config;

+ (Scenario *)createScenarioNamed:(NSString *)className withConfig:(BugsnagConfiguration *)config;

- (instancetype)initWithConfig:(BugsnagConfiguration *)config;

/**
 * Blocks the calling thread until network connectivity to the notify endpoint has been verified.
 */
- (void)waitForNetworkConnectivity;

/**
 * Executes the test case
 */
- (void)run;

- (void)startBugsnag;

- (void)didEnterBackgroundNotification;

@property (nonatomic, strong, nullable) NSString *eventMode;

- (void)performBlockAndWaitForEventDelivery:(dispatch_block_t)block NS_SWIFT_NAME(performBlockAndWaitForEventDelivery(_:));

@end

NS_ASSUME_NONNULL_END
