//
//  BSGRemoteConfigStore.h
//  Bugsnag
//
//  Created by Robert Bartoszewski on 11/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import <Bugsnag/BugsnagConfiguration.h>
#import "BSGRemoteConfiguration.h"
#import "BSGFileLocations.h"

@interface BSGRemoteConfigStore: NSObject

+ (instancetype)storeWithLocations:(BSGFileLocations *)fileLocations
                     configuration:(BugsnagConfiguration *)configuration;

- (void)saveConfiguration:(BSGRemoteConfiguration *)configuration;
- (BSGRemoteConfiguration *)loadConfiguration;
- (void)clear;

@end
