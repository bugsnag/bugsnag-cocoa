//
//  BSGRemoteConfigService.h
//  Bugsnag
//
//  Created by Robert Bartoszewski on 11/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import <Bugsnag/BugsnagConfiguration.h>
#import "../Store/Model/BSGRemoteConfiguration.h"
#import "BugsnagNotifier.h"
#import "BugsnagDevice.h"
#import "BugsnagApp.h"

typedef NS_ENUM(NSUInteger, BSGRemoteConfigServiceResponseType) {
    BSGRemoteConfigServiceResponseTypeSuccess,
    BSGRemoteConfigServiceResponseTypeError,
    BSGRemoteConfigServiceResponseTypeNotModified,
};

@interface BSGRemoteConfigServiceResponse: NSObject

@property (nonatomic) BSGRemoteConfigServiceResponseType type;
@property (nonatomic, nullable) BSGRemoteConfiguration *configuration;
@property (nonatomic, nullable) NSError *error;
@property (nonatomic, nullable) NSString *configurationTag;
@property (nonatomic, nullable) NSDate *expiryDate;
/// Server-requested minimum wait in seconds from a Retry-After header on a failed response, or 0.
@property (nonatomic) NSTimeInterval retryAfter;
/// The request failed because the device had no network connection, not because of the config service.
@property (nonatomic) BOOL networkUnavailable;
/// The request failed before the config service answered (a connection, DNS, socket or timeout error),
/// so the cause may be the device losing its network rather than the service.
@property (nonatomic) BOOL failedWithoutResponse;

@end

typedef void (^BSGRemoteConfigServiceCompletion)(BSGRemoteConfigServiceResponse *_Nonnull response);

NS_ASSUME_NONNULL_BEGIN

@interface BSGRemoteConfigService: NSObject

+ (instancetype)serviceWithSession:(NSURLSession *)session
                     configuration:(BugsnagConfiguration *)configuration
                          notifier:(BugsnagNotifier *)notifier
                            device:(BugsnagDevice *)device
                               app:(BugsnagApp *)app;

- (void)loadRemoteConfigWithCurrentTag:(nullable NSString *)tag completion:(BSGRemoteConfigServiceCompletion)completion;

/**
 * The cached lifetime for a config the server said lasts `lifetime` seconds, shortened by up to 10%:
 * lifetime * (1 - 0.1 * randomFraction), where randomFraction is in the range [0, 1].
 * Spreads refreshes across a fleet that fetched config at the same time.
 */
+ (NSTimeInterval)jitteredLifetime:(NSTimeInterval)lifetime randomFraction:(double)randomFraction;

@end

NS_ASSUME_NONNULL_END
