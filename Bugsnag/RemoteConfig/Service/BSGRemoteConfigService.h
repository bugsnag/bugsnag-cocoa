//
//  BSGRemoteConfigService.h
//  Bugsnag
//
//  Created by Robert Bartoszewski on 11/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import <Bugsnag/BugsnagConfiguration.h>
#import "BSGRemoteConfiguration.h"
#import "BugsnagNotifier.h"
#import "BugsnagDevice.h"
#import "BugsnagApp.h"

typedef void (^BSGRemoteConfigServiceCompletion)(BSGRemoteConfiguration *_Nullable, NSError *_Nullable error);

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
