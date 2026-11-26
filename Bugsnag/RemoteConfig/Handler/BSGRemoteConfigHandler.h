//
//  BSGRemoteConfigHandler.h
//  Bugsnag
//
//  Created by Robert Bartoszewski on 12/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "../Service/BSGRemoteConfigService.h"
#import "../Store/BSGRemoteConfigStore.h"

@interface BSGRemoteConfigHandler : NSObject

+ (instancetype)handlerWithService:(BSGRemoteConfigService *)service
                             store:(BSGRemoteConfigStore *)store
                     configuration:(BugsnagConfiguration *)configuration;

- (BSGRemoteConfiguration *)currentConfiguration;
- (void)initialize;
- (void)start;
- (NSDate *)lastConfigUpdateTime;
- (BOOL)hasValidConfig;
- (BOOL)isRemoteConfigEnabled;
/**
 * Starts a background refresh if the current config is in the last part of its lifetime. For callers that
 * reuse rules built from a valid config without asking for the config again.
 */
- (void)refreshConfigurationIfDue;

/**
 * Exponential backoff delay ceiling for the given consecutive failure index (k):
 * min(24h, 15min * 4^k)
 */
+ (NSTimeInterval)backoffDelayForFailureIndex:(NSUInteger)failureIndex;

/**
 * Equal Jitter wait for the given failure index: (delay / 2) + (delay / 2) * randomFraction,
 * where randomFraction is in the range [0, 1].
 */
+ (NSTimeInterval)backoffWaitForFailureIndex:(NSUInteger)failureIndex randomFraction:(double)randomFraction;

@end
