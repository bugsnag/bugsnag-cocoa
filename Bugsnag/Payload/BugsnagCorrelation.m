//
//  BugsnagCorrelation.m
//  Bugsnag
//
//  Created by Karl Stenerud on 14.05.24.
//  Copyright © 2024 Bugsnag Inc. All rights reserved.
//

#import "BugsnagCorrelation+Private.h"

@implementation BugsnagCorrelation

- (instancetype) initWithTraceId:(NSString *) traceId spanId:(NSString *)spanId {
    if ((self = [super init])) {
        _traceId = traceId;
        _spanId = spanId;
    }
    return self;
}

- (instancetype) initWithJsonDictionary:(NSDictionary<NSString *, NSObject *> *) dict {
    if (dict.count == 0) {
        return nil;
    }

    if ((self = [super init])) {
        id nsnull = NSNull.null;
        _traceId = (NSString *)dict[@"traceid"];
        if (_traceId == nsnull) {
            _traceId = nil;
        }

        _spanId = (NSString *)dict[@"spanid"];
        if (_spanId == nsnull) {
            _spanId = nil;
        }

    }
    return self;
}

- (NSDictionary<NSString *, NSObject *> *) toJsonDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[@"traceid"] = self.traceId;
    dict[@"spanid"] = self.spanId;
    return dict;
}

@end
