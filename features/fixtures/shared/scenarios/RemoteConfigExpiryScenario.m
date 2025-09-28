//
//  RemoteConfigExpiryScenario.m
//  iOSTestApp
//
//  Created by Robert Bartoszewski on 26/09/2025.
//  Copyright © 2025 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"

@interface RemoteConfigExpiryError : NSError
@end
@implementation RemoteConfigExpiryError
@end

@interface RemoteConfigExpiryScenario : Scenario
@end

@implementation RemoteConfigExpiryScenario

- (void)run {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString *message1 = @"Err 0";
        [Bugsnag notifyError:[RemoteConfigExpiryError errorWithDomain:@"com.example"
                                                                 code:401
                                                             userInfo:@{NSLocalizedDescriptionKey: message1}]];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSString *message2 = @"Err 1";
            [Bugsnag notifyError:[RemoteConfigExpiryError errorWithDomain:@"com.example"
                                                                     code:401
                                                                 userInfo:@{NSLocalizedDescriptionKey: message2}]];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSString *message3 = @"Err 2";
                [Bugsnag notifyError:[RemoteConfigExpiryError errorWithDomain:@"com.example"
                                                                         code:401
                                                                     userInfo:@{NSLocalizedDescriptionKey: message3}]];
            });
        });
    });
}

@end
