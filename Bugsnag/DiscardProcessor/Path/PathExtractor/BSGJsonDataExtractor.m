//
//  BSGJsonDataExtractor.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 20/11/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGJsonDataExtractor.h"
#import "BSGJsonCollectionPath.h"

@interface BSGJsonDataExtractor ()
@property (nonatomic, strong) BSGJsonCollectionPath *path;
@end

@implementation BSGJsonDataExtractor

+ (NSString *)stringifyElement:(id)element {
    if ([element isKindOfClass:[NSString class]]) {
        return element;
    } else if ([element isKindOfClass:[NSNumber class]]) {
        return [element stringValue];
    } else if ([element isKindOfClass:[NSNull class]]) {
        return nil;
    }
    // For other types, try description
    return [element description];
}

- (instancetype)initWithPath:(BSGJsonCollectionPath *)path {
    self = [super init];
    if (self) {
        _path = path;
    }
    return self;
}

- (void)extractFromJSON:(NSDictionary<NSString *, id> *)json
     onElementExtracted:(BSGJsonDataOnElementExtracedBlock)onElementExtracted {}

@end
