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

@end

typedef void (^BSGRemoteConfigServiceCompletion)(BSGRemoteConfigServiceResponse *_Nonnull response);

NS_ASSUME_NONNULL_BEGIN

@interface BSGRemoteConfigService: NSObject

+ (instancetype)serviceWithSession:(NSURLSession *)session
                     configuration:(BugsnagConfiguration *)configuration
                          notifier:(BugsnagNotifier *)notifier
                            device:(BugsnagDevice *)device
                               app:(BugsnagApp *)app;

- (void)loadRemoteConfigWithCurrentTag:(NSString *)tag completion:(BSGRemoteConfigServiceCompletion)completion;

@end

NS_ASSUME_NONNULL_END
