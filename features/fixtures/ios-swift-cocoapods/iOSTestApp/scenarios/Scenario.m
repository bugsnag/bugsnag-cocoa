//
// Created by Jamie Lynch on 23/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

#import "Scenario.h"


@implementation Scenario

- (instancetype)initWithConfig:(BugsnagConfiguration *)config {
    if (self = [super init]) {
        self.config = config;
    }
    return self;
}

- (void)run {
}

- (void)startBugsnag {
    [Bugsnag startBugsnagWithConfiguration:self.config];
}

@end