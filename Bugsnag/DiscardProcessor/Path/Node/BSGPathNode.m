//
//  BSGPathNode.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 25/11/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGPathNode.h"

@interface BSGPathNode ()
@property (nonatomic, strong) BSGPathNode *next;
@end

@implementation BSGPathNode

+ (instancetype)nodeWithNext:(BSGPathNode *)next {
    return [[self alloc] initWithNext:next];
}

- (instancetype)initWithNext:(BSGPathNode *)next {
    if ((self = [super init])) {
        _next = next;
    }
    return self;
}

- (void)extractFromJSON:(id)json collector:(BSGPathNodeCollector)collector {
    if ([json isKindOfClass:[NSDictionary class]]) {
        return [self extractFromJSONObject:json collector:collector];
    }
    if ([json isKindOfClass:[NSArray class]]) {
        return [self extractFromJSONArray:json collector:collector];
    }
}

- (void)extractFromJSONObject:(__unused NSDictionary<NSString *,id> *)object collector:(__unused BSGPathNodeCollector)collector {}

- (void)extractFromJSONArray:(__unused NSArray<id> *)array collector:(__unused BSGPathNodeCollector)collector {}

@end
