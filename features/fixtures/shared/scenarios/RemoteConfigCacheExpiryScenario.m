//
//  RemoteConfigCacheExpiryScenario.m
//  iOSTestApp
//
//  Created on 09/07/2026.
//  Copyright © 2026 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"

// RemoteConfigExpiryError is defined in RemoteConfigExpiryScenario.m
@interface RemoteConfigExpiryError : NSError
@end

@interface RemoteConfigCacheExpiryScenario : Scenario
@end

@implementation RemoteConfigCacheExpiryScenario

- (void)configure {
    [super configure];
    self.config.endpoints.configuration = self.fixtureConfig.configurationURL.absoluteString;
}

- (void)run {
    // Send a single error after waiting for config to expire and be refetched
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString *message = @"Err 0";
        [Bugsnag notifyError:[RemoteConfigExpiryError errorWithDomain:@"com.example"
                                                                 code:401
                                                             userInfo:@{NSLocalizedDescriptionKey: message}]];
    });
}

@end
