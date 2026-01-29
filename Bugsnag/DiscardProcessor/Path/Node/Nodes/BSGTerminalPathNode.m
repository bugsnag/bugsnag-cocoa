//
//  BSGTerminalPathNode.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 24/11/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGTerminalPathNode.h"

@implementation BSGTerminalPathNode

+ (instancetype)node {
    return [[self alloc] init];
}

- (void)extractFromJSON:(id)json collector:(BSGPathNodeCollector)collector {
    if (collector) {
        collector(json);
    }
}

@end
