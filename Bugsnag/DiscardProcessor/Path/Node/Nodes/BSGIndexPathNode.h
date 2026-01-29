//
//  BSGIndexPathNode.h
//  Bugsnag
//
//  Created by Robert Bartoszewski on 24/11/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "../BSGPathNode.h"

NS_ASSUME_NONNULL_BEGIN

@interface BSGIndexPathNode : BSGPathNode

+ (instancetype)nodeWithIndex:(NSInteger)index next:(BSGPathNode *)next;

@end

NS_ASSUME_NONNULL_END
