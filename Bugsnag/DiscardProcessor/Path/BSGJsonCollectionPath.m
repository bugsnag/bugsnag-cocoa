//
//  BSGJsonCollectionPath.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 20/11/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGJsonCollectionPath.h"
#import "Node/BSGPathNode.h"
#import "Node/Nodes/BSGTerminalPathNode.h"
#import "Node/Nodes/BSGWildcardPathNode.h"
#import "Node/Nodes/BSGIndexPathNode.h"
#import "Node/Nodes/BSGPropertyPathNode.h"

static NSString * const IdentityPath = @"$";
static NSString * const Wildcard = @"*";
static NSString * const SegmentSeparator = @".";

@interface BSGJsonCollectionPath ()
@property (nonatomic, strong) BSGPathNode *root;

@end

@implementation BSGJsonCollectionPath

+ (instancetype)pathFromString:(NSString *)path {
    if ([path isEqualToString:IdentityPath]) {
        return [self identityPath];
    }
    NSEnumerator<NSString *> *segments = [[path componentsSeparatedByString:SegmentSeparator] reverseObjectEnumerator];
    BSGPathNode *node = [BSGTerminalPathNode node];
    for (NSString *segment in segments) {
        node = [self nodeForSegment:segment nextNode:node];
    }
    
    return [[self alloc] initWithRoot:node];
}

+ (instancetype)identityPath {
    return [[self alloc] initWithRoot:[BSGTerminalPathNode node]];
}

+ (BSGPathNode *)nodeForSegment:(NSString *)segment nextNode:(BSGPathNode *)nextNode {
    if ([segment isEqualToString:Wildcard]) {
        return [BSGWildcardPathNode nodeWithNext:nextNode];
    }
    NSInteger index;
    NSScanner *scanner = [NSScanner scannerWithString:segment];
    if ([scanner scanInteger:&index] && [scanner isAtEnd]) {
        return [BSGIndexPathNode nodeWithIndex:index next:nextNode];
    }
    
    return [BSGPropertyPathNode nodeWithName:segment next:nextNode];
}

- (instancetype)initWithRoot:(BSGPathNode *)root {
    if ((self = [super init])) {
        _root = root;
    }
    return self;
}

- (NSArray<id> *)extractFromJSON:(NSDictionary<NSString *, id> *)json {
    NSMutableArray<id> *results = [NSMutableArray array];
    [self.root extractFromJSON:json collector:^(id  _Nonnull value) {
        [results addObject:value];
    }];
    return results;
}

@end

