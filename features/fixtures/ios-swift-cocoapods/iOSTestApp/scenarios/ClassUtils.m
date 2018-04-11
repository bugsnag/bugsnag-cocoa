//
// Created by Jamie Lynch on 23/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

#import <Bugsnag/BugsnagConfiguration.h>
#import "ClassUtils.h"
#import "Scenario.h"

@implementation ClassUtils

+ (Scenario *)instantiateClass:(NSString *)className
                    withConfig:(BugsnagConfiguration *)config {

    if ([@"none" isEqualToString:className]) {
        className = @"Wait";
    }
    Class clz = NSClassFromString(className);

    if (clz == nil) { // swift class
        clz = NSClassFromString([NSString stringWithFormat:@"iOSTestApp.%@", className]);
    }

    id obj = [[clz alloc] performSelector:NSSelectorFromString(@"initWithConfig:") withObject:config];

    if (![obj isKindOfClass:[Scenario class]]) {
        [[NSException exceptionWithName:@"ClassNotFound"
                                 reason:[NSString stringWithFormat:@"Could not find scenario %@", className]
                               userInfo:nil] raise];
    }
    return obj;
}

@end
