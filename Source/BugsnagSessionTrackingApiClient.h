//
// Created by Jamie Lynch on 30/11/2017.
// Copyright (c) 2017 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BugsnagConfiguration;
@class BugsnagSessionTrackingPayload;


@interface BugsnagSessionTrackingApiClient : NSObject

- (instancetype)initWithConfig:(BugsnagConfiguration *)configuration;

@end