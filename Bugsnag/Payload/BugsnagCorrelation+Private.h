//
//  BugsnagCorrelation+Private.h
//  Bugsnag
//
//  Created by Karl Stenerud on 14.05.24.
//  Copyright © 2024 Bugsnag Inc. All rights reserved.
//

#import "BugsnagCorrelation.h"

#ifndef BugsnagCorrelation_Private_h
#define BugsnagCorrelation_Private_h

NS_ASSUME_NONNULL_BEGIN

@interface BugsnagCorrelation ()

- (instancetype) initWithTraceId:(NSString * _Nullable) traceId spanId:(NSString * _Nullable)spanId;

- (instancetype) initWithJsonDictionary:(NSDictionary<NSString *, NSObject *> * _Nullable) dict;

- (NSDictionary<NSString *, NSObject *> *) toJsonDictionary;

@end

NS_ASSUME_NONNULL_END

#endif /* BugsnagCorrelation_Private_h */
