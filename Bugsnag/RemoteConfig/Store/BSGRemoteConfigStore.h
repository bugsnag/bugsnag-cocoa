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

NS_ASSUME_NONNULL_BEGIN

/**
 * Durable retry state for remote config fetches, scoped to the app version and build that wrote it.
 */
@interface BSGRemoteConfigFetchState: NSObject

@property (nullable, nonatomic, copy) NSString *appVersion;
@property (nullable, nonatomic, copy) NSString *bundleVersion;
@property (nonatomic) NSUInteger fetchFailureCount;
@property (nullable, nonatomic, strong) NSDate *nextAllowedFetchAt;
/// Set before a request is sent and cleared once its outcome is recorded.
@property (nonatomic) BOOL attemptInProgress;

+ (nullable instancetype)stateFromJson:(nullable NSDictionary *)json;
- (NSDictionary *)toJson;

@end

/// The outcome of revalidating the cached config after a 304 Not Modified response.
typedef NS_ENUM(NSInteger, BSGRemoteConfigExpiryUpdateResult) {
    /// The cached config matched and its new expiry date was saved.
    BSGRemoteConfigExpiryUpdateResultUpdated,
    /// No config is cached, so there is nothing to revalidate.
    BSGRemoteConfigExpiryUpdateResultMissing,
    /// The cached config's ETag differs from the server's, so the cache is out of date.
    BSGRemoteConfigExpiryUpdateResultTagMismatch,
    /// The cached config matched, but its new expiry date could not be saved.
    BSGRemoteConfigExpiryUpdateResultWriteFailed,
};

@interface BSGRemoteConfigStore: NSObject

+ (instancetype)storeWithLocations:(BSGFileLocations *)fileLocations
                     configuration:(BugsnagConfiguration *)configuration;

- (nullable BSGRemoteConfiguration *)saveConfiguration:(nullable BSGRemoteConfiguration *)configuration;
/**
 * Applies a 304 response's expiry date to the cached config.
 *
 * @param configuration Set to the revalidated config, with the new expiry date, when the result is
 *        Updated or WriteFailed. A WriteFailed config is still valid; only its new expiry is not on disk.
 */
- (BSGRemoteConfigExpiryUpdateResult)updateExpiryDate:(nullable NSDate *)expiryDate
                                     configurationTag:(nullable NSString *)configurationTag
                                        configuration:(BSGRemoteConfiguration *_Nullable __autoreleasing *_Nonnull)configuration;
- (nullable BSGRemoteConfiguration *)loadConfiguration;
- (void)clear;

- (nullable BSGRemoteConfigFetchState *)loadFetchState;
- (BOOL)saveFetchState:(nullable BSGRemoteConfigFetchState *)fetchState;
- (void)clearFetchState;

@end

NS_ASSUME_NONNULL_END
