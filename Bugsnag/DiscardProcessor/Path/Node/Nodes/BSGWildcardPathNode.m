//
//  BSGWildcardPathNode.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 24/11/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGWildcardPathNode.h"

@implementation BSGWildcardPathNode

- (void)extractFromJSONObject:(NSDictionary<NSString *,id> *)object collector:(BSGPathNodeCollector)collector {
    NSArray *sortedKeys = [[object allKeys] sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *key in sortedKeys) {
        id value = object[key];
        if (value) {
            [self.next extractFromJSON:value collector:collector];
        }
    }
        
}

- (void)extractFromJSONArray:(NSArray<id> *)array collector:(BSGPathNodeCollector)collector {
    for (id value in array) {
        [self.next extractFromJSON:value collector:collector];
    }
}

@end
