//
//  TestSupport.m
//  Bugsnag
//
//  Created by Karl Stenerud on 25.09.20.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import "TestSupport.h"
#import "BugsnagSystemState.h"
#import "BSGConfigurationBuilder.h"
#import "BugsnagTestConstants.h"
#import "Bugsnag+Private.h"


@implementation TestSupport

+ (void) purgePersistentData {
    // TODO: Purge crash reports, breadcrumbs

    BugsnagConfiguration *config = [BSGConfigurationBuilder
            configurationFromOptions:@{@"apiKey": DUMMY_APIKEY_32CHAR_1}];
    [[[BugsnagSystemState alloc] initWithConfiguration:config] purge];
    [Bugsnag purge];
}

@end
