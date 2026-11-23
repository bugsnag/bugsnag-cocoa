//
//  BSGRemoteConfigStore.h
//  Bugsnag
//
//  Created by Robert Bartoszewski on 11/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import <Bugsnag/BugsnagConfiguration.h>
#import "Model/BSGRemoteConfiguration.h"
#import "BSGFileLocations.h"

/**
 * Durable retry state for remote config fetches, scoped to the app version that wrote it.
 */
@interface BSGRemoteConfigFetchState: NSObject

@property (nonatomic, copy) NSString *appVersion;
@property (nonatomic) NSUInteger fetchFailureCount;
@property (nonatomic, strong) NSDate *nextAllowedFetchAt;
/// Set before a request is sent and cleared once its outcome is recorded.
@property (nonatomic) BOOL attemptInProgress;

+ (instancetype)stateFromJson:(NSDictionary *)json;
- (NSDictionary *)toJson;

@end

@interface BSGRemoteConfigStore: NSObject

+ (instancetype)storeWithLocations:(BSGFileLocations *)fileLocations
                     configuration:(BugsnagConfiguration *)configuration;

- (BSGRemoteConfiguration *)saveConfiguration:(BSGRemoteConfiguration *)configuration;
- (BSGRemoteConfiguration *)updateExpiryDate:(NSDate *)expiryDate configurationTag:(NSString *)configurationTag;
- (BSGRemoteConfiguration *)loadConfiguration;
- (void)clear;

- (BSGRemoteConfigFetchState *)loadFetchState;
- (BOOL)saveFetchState:(BSGRemoteConfigFetchState *)fetchState;
- (void)clearFetchState;

@end
