//
// Created by Jamie Lynch on 12/04/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

#import "Scenario.h"

/**
 * Calls a non-existent method on an object
 */
@interface NonExistentMethodScenario : Scenario
@end

@implementation NonExistentMethodScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = NO;
    [super startBugsnag];
}

- (void)run {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector:NSSelectorFromString(@"santaclaus:")];
#pragma clang diagnostic pop
}


@end
