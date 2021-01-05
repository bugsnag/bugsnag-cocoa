//
//  BSGFileLocations.h
//  Bugsnag
//
//  Created by Karl Stenerud on 05.01.21.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BSGFileLocations : NSObject

@property(readonly) NSString *kvStore;
@property(readonly) NSString *breadcrumbs;
@property(readonly) NSString *kscrashReports;
@property(readonly) NSString *sessions;

/**
 * File whose presence indicates that the libary at least attempted to handle the last
 * crash (in case it crashed before writing enough information).
 */
@property(readonly) NSString *flagHandledCrash;

/**
 * Bugsnag client configuration
 */
@property(readonly) NSString *configuration;

/**
 * General per-launch metadata
 */
@property(readonly) NSString *metadata;

/**
 * State info that gets added to the low level crash report.
 */
@property(readonly) NSString *state;

/**
 * State information about the app and operating envronment.
 */
@property(readonly) NSString *systemState;

+ (instancetype) current;
+ (instancetype) v1;

@end

NS_ASSUME_NONNULL_END
