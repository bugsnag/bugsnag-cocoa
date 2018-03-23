//
// Created by Jamie Lynch on 23/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BugsnagConfiguration;
@class Scenario;


@interface ClassUtils : NSObject

+ (Scenario *_Nonnull)instantiateClass:(NSString *_Nonnull)className
                            withConfig:(BugsnagConfiguration *_Nonnull)config;

@end