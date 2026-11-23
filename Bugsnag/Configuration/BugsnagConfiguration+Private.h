//
//  BugsnagConfiguration+Private.h
//  Bugsnag
//
//  Created by Nick Dowell on 26/11/2020.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import "BSGDefines.h"
#import "BugsnagInternals.h"

@class BugsnagNotifier;

NS_ASSUME_NONNULL_BEGIN


@interface BugsnagConfiguration ()

#pragma mark Initializers

- (instancetype)initWithDictionaryRepresentation:(NSDictionary<NSString *, id> *)JSONObject NS_DESIGNATED_INITIALIZER;

#pragma mark Properties

@property (readonly, nonatomic) NSDictionary<NSString *, id> *dictionaryRepresentation;

@property (nonatomic) BSGMemoryFeatureFlagStore *featureFlagStore;

@property (copy, nonatomic) BugsnagMetadata *metadata;

@property (readonly, nullable, nonatomic) NSURL *notifyURL;

@property (nonatomic) NSMutableSet *plugins;

@property (readonly, nonatomic) BOOL shouldSendReports;

@property (readonly, nonnull, nonatomic) NSURLSession *sessionOrDefault;

@property (readonly, nullable, nonatomic) NSURL *sessionURL;

@property (readonly, nullable, nonatomic) NSURL *configurationURL;

@property (readwrite, retain, nonnull, nonatomic) BugsnagUser *user;

/// Upper bound of the random delay before a device's first remote config fetch, so a fleet whose first
/// errors arrive together does not fetch config in the same second. Defaults to 10 seconds; 0 disables it.
@property (nonatomic) NSTimeInterval remoteConfigFirstFetchJitter;

#pragma mark Methods

+ (BOOL)isValidApiKey:(NSString *)apiKey;

+ (instancetype)bsg_loadConfigWithBundle:(NSBundle *)bundle;

- (BOOL)shouldDiscardErrorClass:(NSString *)errorClass;

- (BOOL)shouldRecordBreadcrumbType:(BSGBreadcrumbType)breadcrumbType;

/// Throws an NSInvalidArgumentException if the API key is empty or missing.
/// Logs a warning message if the API key is not in the expected format.
- (void)validate;

@end

@interface BugsnagConfiguration (/* not objc_direct */) <NSCopying>
@end

NS_ASSUME_NONNULL_END
