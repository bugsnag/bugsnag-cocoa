//
//  BugsnagCorrelation.m
//  Bugsnag
//
//  Created by Karl Stenerud on 14.05.24.
//  Copyright © 2024 Bugsnag Inc. All rights reserved.
//

#import "BugsnagCorrelation.h"

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
        _traceId = (NSString *)dict[@"traceId"];
        if (_traceId == nsnull) {
            _traceId = nil;
        }

        _spanId = (NSString *)dict[@"spanId"];
        if (_spanId == nsnull) {
            _spanId = nil;
        }

    }
    return self;
}

- (NSDictionary<NSString *, NSObject *> *) toJsonDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[@"traceId"] = self.traceId;
    dict[@"spanId"] = self.spanId;
    return dict;
}

@end
