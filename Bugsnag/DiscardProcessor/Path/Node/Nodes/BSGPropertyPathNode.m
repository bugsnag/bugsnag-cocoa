//
//  BSGPropertyPathNode.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 24/11/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGPropertyPathNode.h"

@interface BSGPropertyPathNode ()
@property (nonatomic, strong) NSString *name;

@end

@implementation BSGPropertyPathNode

+ (instancetype)nodeWithName:(NSString *)name next:(nonnull BSGPathNode *)next {
    return [[self alloc] initWithName:name next:next];
}

- (instancetype)initWithName:(NSString *)name next:(BSGPathNode *)next {
    if ((self = [super initWithNext:next])) {
        _name = name;
    }
    return self;
}

- (void)extractFromJSONObject:(NSDictionary<NSString *,id> *)object collector:(BSGPathNodeCollector)collector {
    id value = object[self.name];
    if (value) {
        [self.next extractFromJSON:value collector:collector];
    }
}

@end
