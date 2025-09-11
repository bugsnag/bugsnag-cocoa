//
//  BSGRemoteConfigStore.h
//  Bugsnag
//
//  Created by Robert Bartoszewski on 11/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGRemoteConfiguration.h"
#import "BSGFileLocations.h"

@interface BSGRemoteConfigStore: NSObject

+ (instancetype)repositoryWithLocations:(BSGFileLocations *)fileLocations
                             appVersion:(NSString *)appVersion;

- (void)saveConfiguration:(BSGRemoteConfiguration *)configuration;
- (BSGRemoteConfiguration *)loadConfiguration;

@end
