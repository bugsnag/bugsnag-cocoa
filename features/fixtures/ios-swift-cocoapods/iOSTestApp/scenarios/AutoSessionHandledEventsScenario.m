//
//  AutoSessionHandledEventsScenario.m
//  iOSTestApp
//
//  Created by Delisa on 7/13/18.
//  Copyright © 2018 Bugsnag. All rights reserved.
//

#import "AutoSessionHandledEventsScenario.h"

@implementation AutoSessionHandledEventsScenario

- (void)run {
    [Bugsnag notifyError:[NSError errorWithDomain:@"com.bugsnag" code:833 userInfo:nil]];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [Bugsnag notify:[NSException exceptionWithName:@"BugsnagsKnownUnknowns"
                                                reason:@"this event was very questionable"
                                              userInfo:nil]];
    });
}

@end
