//
//  BSGPathNode.h
//  Bugsnag
//
//  Created by Robert Bartoszewski on 24/11/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^BSGPathNodeCollector)(id value);

@interface BSGPathNode: NSObject

@property (nonatomic, readonly) BSGPathNode *_Nullable next;

+ (instancetype)nodeWithNext:(nullable BSGPathNode *)next;

- (instancetype)initWithNext:(BSGPathNode *)next;
- (void)extractFromJSON:(id)json collector:(BSGPathNodeCollector)collector;
- (void)extractFromJSONObject:(NSDictionary<NSString *, id> *)object collector:(BSGPathNodeCollector)collector;
- (void)extractFromJSONArray:(NSArray<id> *)array collector:(BSGPathNodeCollector)collector;

@end

NS_ASSUME_NONNULL_END
