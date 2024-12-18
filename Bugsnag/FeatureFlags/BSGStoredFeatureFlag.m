//
//  BSGStoredFeatureFlag.m
//  Bugsnag
//
//  Created by Robert B on 25/11/2024.
//  Copyright © 2024 Bugsnag. All rights reserved.
//

#import "BSGStoredFeatureFlag.h"
#import "BSGKeys.h"

@implementation BSGStoredFeatureFlag

+ (instancetype)fromJSON:(NSDictionary *)json {
    BSGStoredFeatureFlag *result = [self new];
    result.name = json[BSGKeyFeatureFlag] ?: @"";
    result.variant = json[BSGKeyVariant];
    result.index = [json[@"index"] unsignedLongLongValue];
    
    return result;
}

- (instancetype)initWithName:(NSString *)name variant:(nullable NSString *)variant index:(uint64_t)index
{
    self = [super init];
    if (self) {
        self.name = name;
        self.variant = variant;
        self.index = index;
    }
    return self;
}

- (NSDictionary *)toJson {
    NSMutableDictionary *result = [NSMutableDictionary new];
    result[BSGKeyFeatureFlag] = self.name;
    result[@"index"] = @(self.index);
    if (self.variant) {
        result[BSGKeyVariant] = self.variant;
    }
    return result;
}

@end
