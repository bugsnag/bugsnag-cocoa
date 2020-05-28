//
//  UnhandledMachExceptionScenario.m
//  iOSTestApp
//
//  Created by Jamie Lynch on 26/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "UnhandledMachExceptionScenario.h"

@implementation UnhandledMachExceptionScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = NO;
    [super startBugsnag];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-noreturn"
- (void)run  __attribute__((noreturn)) {
    // Send a handled exception to confirm the scenario is running.
    [Bugsnag notify:[NSException exceptionWithName:NSGenericException reason:@"UnhandledMachExceptionScenario" userInfo:@{NSLocalizedDescriptionKey: @""}]];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        strcmp(0, ""); // Generate EXC_BAD_ACCESS (see e.g. https://stackoverflow.com/q/22488358/2431627)
    });
}
#pragma clang diagnostic pop

@end
