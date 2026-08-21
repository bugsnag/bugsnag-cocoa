//
//  BSGIndexPathNode.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 25/11/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGIndexPathNode.h"

@interface BSGIndexPathNode ()
@property (nonatomic) NSInteger index;

@end

@implementation BSGIndexPathNode

+ (instancetype)nodeWithIndex:(NSInteger)index next:(nonnull BSGPathNode *)next {
    return [[self alloc] initWithIndex:index next:next];
}

- (instancetype)initWithIndex:(NSInteger)index next:(BSGPathNode *)next {
    if ((self = [super initWithNext:next])) {
        _index = index;
    }
    return self;
}

- (void)extractFromJSONObject:(NSDictionary<NSString *,id> *)object collector:(BSGPathNodeCollector)collector {
    id value = object[[@(self.index) stringValue]];
    if (value != nil) {
        [self.next extractFromJSON:value collector:collector];
    }
}

- (void)extractFromJSONArray:(NSArray<id> *)array collector:(BSGPathNodeCollector)collector {
    NSNumber *normalisedIndex = [self normalisedIndexWithArrayCount:(NSInteger)array.count];
    if (normalisedIndex != nil) {
        id value = array[normalisedIndex.unsignedIntegerValue];
        [self.next extractFromJSON:value collector:collector];
    }
}

- (NSNumber *)normalisedIndexWithArrayCount:(NSInteger)arrayCount {
    if (self.index >= 0) {
        if (self.index < arrayCount) {
            return @(self.index);
        } else {
            return nil;
        }
    }
    NSInteger negativeIndex = -self.index;
    if (negativeIndex <= arrayCount) {
        return @(arrayCount - negativeIndex);
    } else {
        return nil;
    }
}

@end
