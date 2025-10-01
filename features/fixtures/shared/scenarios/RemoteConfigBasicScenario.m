//
//  RemoteConfigBasicScenario.m
//  iOSTestApp
//
//  Created by Robert Bartoszewski on 26/09/2025.
//  Copyright © 2025 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"

@interface RemoteConfigError : NSError
@end
@implementation RemoteConfigError
@end

@interface RemoteConfigBasicScenario : Scenario
@end

@implementation RemoteConfigBasicScenario

- (void)configure {
    [super configure];
    self.config.endpoints.configuration = self.fixtureConfig.configurationURL.absoluteString;
}

- (void)run {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString *message = @"Err 0";
        [Bugsnag notifyError:[RemoteConfigError errorWithDomain:@"com.example"
                                                           code:401
                                                       userInfo:@{NSLocalizedDescriptionKey: message}]];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @throw [NSException exceptionWithName:NSGenericException reason:@"Uncaught exception!"
                                        userInfo:@{NSLocalizedDescriptionKey: @"I'm in your program, catching your exceptions!"}];
        });
    });
}

@end
