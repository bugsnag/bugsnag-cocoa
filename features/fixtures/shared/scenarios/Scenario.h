//
// Created by Jamie Lynch on 23/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

#import <Bugsnag/Bugsnag.h>
#import <BugsnagNetworkRequestPlugin/BugsnagNetworkRequestPlugin.h>
#import "BugsnagInternals.h"

NS_ASSUME_NONNULL_BEGIN

void logInternal(const char* level, NSString *format, va_list args);

void markErrorHandledCallback(const BSG_KSCrashReportWriter *writer);

@interface Scenario : NSObject

@property (strong, nonatomic, nonnull) BugsnagConfiguration *config;

+ (Scenario *)createScenarioNamed:(NSString *)className
                       withConfig:(nullable BugsnagConfiguration *)config;
    
@property (class, readwrite) NSString *baseMazeAddress;
@property (class, readonly, nullable) Scenario *currentScenario;

- (instancetype)initWithConfig:(nullable BugsnagConfiguration *)config;

/**
 * Executes the test case
 */
- (void)run;

- (void)startBugsnag;

- (void)didEnterBackgroundNotification;

@property (nonatomic, strong, nullable) NSString *eventMode;

- (void)performBlockAndWaitForEventDelivery:(dispatch_block_t)block NS_SWIFT_NAME(performBlockAndWaitForEventDelivery(_:));

- (void)performBlockAndWaitForSessionDelivery:(dispatch_block_t)block NS_SWIFT_NAME(performBlockAndWaitForSessionDelivery(_:));

+ (void)clearPersistentData;

+ (void)executeMazeRunnerCommand:(nullable void (^)(NSString *scenarioName, NSString *scenarioMode))preHandler;

@end

NS_ASSUME_NONNULL_END
