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

@end
