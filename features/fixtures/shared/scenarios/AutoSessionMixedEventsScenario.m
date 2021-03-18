//
//  AutoSessionMixedEventsScenario.m
//  iOSTestApp
//
//  Created by Delisa on 7/16/18.
//  Copyright © 2018 Bugsnag. All rights reserved.
//

#import "AutoSessionMixedEventsScenario.h"

@interface FirstErr : NSError
@end

@interface SecondErr : NSError
@end

@implementation FirstErr
@end

@implementation SecondErr
@end

@implementation AutoSessionMixedEventsScenario

- (void)startBugsnag {
    self.config.session = [self URLSessionWithObserver:^(NSURLRequest *request, NSData *responseData, NSURLResponse *response, NSError *error) {
        if (self.onEventDelivery && [request.URL.absoluteString isEqual:self.config.endpoints.notify]) {
            self.onEventDelivery();
        }
    }];
    [super startBugsnag];
}

- (void)run {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self performBlockAndWaitForEventDelivery:^{
            [Bugsnag notifyError:[FirstErr errorWithDomain:@"com.bugsnag" code:833 userInfo:nil]];
        }];
        [self performBlockAndWaitForEventDelivery:^{
            [Bugsnag notifyError:[SecondErr errorWithDomain:@"com.bugsnag" code:831 userInfo:nil]];
        }];
        @throw [NSException exceptionWithName:@"Kaboom" reason:@"The connection exploded" userInfo:nil];
    });
}

- (void)performBlockAndWaitForEventDelivery:(dispatch_block_t)block {
    NSCondition *condition = [[NSCondition alloc] init];
    self.onEventDelivery = ^{
        [condition signal];
    };
    block();
    [condition wait];
}

@end
