//
//  BugsnagCorrelation.h
//  Bugsnag
//
//  Created by Karl Stenerud on 13.05.24.
//  Copyright © 2024 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Bugsnag/BugsnagDefines.h>

NS_ASSUME_NONNULL_BEGIN

BUGSNAG_EXTERN
@interface BugsnagCorrelation: NSObject

@property (readonly, nonatomic, strong, nullable) NSString *traceId;

@property (readonly, nonatomic, strong, nullable) NSString *spanId;

- (instancetype) initWithTraceId:(NSString * _Nullable) traceId spanId:(NSString * _Nullable)spanId;

- (instancetype) initWithJsonDictionary:(NSDictionary<NSString *, NSObject *> * _Nullable) dict;

- (NSDictionary<NSString *, NSObject *> *) toJsonDictionary;

@end

NS_ASSUME_NONNULL_END
