//
// Created by Jamie Lynch on 23/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Bugsnag/Bugsnag.h>

@interface Scenario : NSObject

@property BugsnagConfiguration *config;

- (instancetype)initWithConfig:(BugsnagConfiguration *)config;

/**
 * Executes the test case
 */
- (void)run;

- (void)startBugsnag;

@end