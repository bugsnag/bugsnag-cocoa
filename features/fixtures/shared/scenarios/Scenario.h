//
// Created by Jamie Lynch on 23/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

#import <Bugsnag/Bugsnag.h>
#import <BugsnagNetworkRequestPlugin/BugsnagNetworkRequestPlugin.h>
#import "FixtureConfig.h"

NS_ASSUME_NONNULL_BEGIN

void logInternal(const char* level, NSString *format, va_list args);

void markErrorHandledCallback(const BSG_KSCrashReportWriter *writer);

@interface Scenario : NSObject

@property (strong, nonatomic, nonnull) FixtureConfig *fixtureConfig;
@property (strong, nonatomic, nonnull) BugsnagConfiguration *config;
@property (strong, nonatomic, nonnull) NSArray<NSString *> *args;
@property (nonatomic) NSInteger launchCount;

- (instancetype)initWithFixtureConfig:(FixtureConfig *)config args:( NSArray<NSString *> * _Nonnull )args launchCount:(NSInteger)launchCount;

- (void)configure;

    /**
 * Executes the test case
 */
- (void)run;

- (void)startBugsnag;

- (void)didEnterBackgroundNotification;

/**
 * Background the app for the specified number of seconds.
 * If the value is < 0, background forever.
 */
- (void)enterBackgroundForSeconds:(NSInteger)seconds;

// Wait for the next event to be delivered, and then run a block on the main thread.
- (void)waitForEventDelivery:(dispatch_block_t)deliveryBlock andThen:(dispatch_block_t)thenBlock;

// Wait for the next session to be delivered, and then run a block on the main thread.
- (void)waitForSessionDelivery:(dispatch_block_t)deliveryBlock andThen:(dispatch_block_t)thenBlock;

+ (void)clearPersistentData;

@end

NS_ASSUME_NONNULL_END
