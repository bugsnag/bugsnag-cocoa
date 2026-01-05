//
//  BSGJsonDataExtractorFactory.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 20/11/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGJsonDataExtractorFactory.h"
#import "BSGSimplePathExtractor.h"

@implementation BSGJsonDataExtractorFactory

- (BSGJsonDataExtractor * _Nullable)extractorFromJSON:(NSDictionary<NSString *, id> *)json {
    NSString *path = json[JsonKeyPath];
    if (path == nil) {
        return nil;
    }
    BSGJsonCollectionPath *collectionPath = [BSGJsonCollectionPath pathFromString:path];
    return [[BSGSimplePathExtractor alloc] initWithPath:collectionPath];
}

@end
