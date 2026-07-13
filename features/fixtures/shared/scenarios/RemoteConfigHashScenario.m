//
//  RemoteConfigHashScenario.m
//  iOSTestApp
//
//  Created on 09/07/2026.
//  Copyright © 2026 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"

// RemoteConfigError is defined in RemoteConfigBasicScenario.m
@interface RemoteConfigError : NSError
@end

@interface NonMatchingError : NSError
@end
@implementation NonMatchingError
@end

@interface RemoteConfigHashScenario : Scenario
@end

@implementation RemoteConfigHashScenario

- (void)configure {
    [super configure];
    self.config.endpoints.configuration = self.fixtureConfig.configurationURL.absoluteString;
}

- (void)run {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // This error should be discarded (matches hash)
        NSString *message1 = @"Matches hash";
        [Bugsnag notifyError:[RemoteConfigError errorWithDomain:@"com.example"
                                                           code:401
                                                       userInfo:@{NSLocalizedDescriptionKey: message1}]];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // This error should be delivered (does not match hash)
            NSString *message2 = @"Does not match hash";
            [Bugsnag notifyError:[NonMatchingError errorWithDomain:@"com.example"
                                                              code:402
                                                          userInfo:@{NSLocalizedDescriptionKey: message2}]];
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @throw [NSException exceptionWithName:NSGenericException reason:@"Uncaught exception!"
                                            userInfo:@{NSLocalizedDescriptionKey: @"I'm in your program, catching your exceptions!"}];
            });
        });
    });
}

@end
