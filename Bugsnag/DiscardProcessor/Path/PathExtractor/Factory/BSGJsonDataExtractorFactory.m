//
//  BSGJsonDataExtractorFactory.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 20/11/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGJsonDataExtractorFactory.h"
#import "BSGRegexExtractor.h"
#import "BSGRelativeAddressExtractor.h"
#import "BSGSimplePathExtractor.h"

static NSString * const JsonKeyPathMode = @"pathMode";
static NSString * const JsonKeyPath = @"path";
static NSString * const JsonKeyRegex = @"regex";
static NSString * const PathModeRegex = @"REGEX";
static NSString * const PathModeRelativeAddress = @"RELATIVE_ADDRESS";

@implementation BSGJsonDataExtractorFactory

- (BSGJsonDataExtractor * _Nullable)extractorFromJSON:(NSDictionary<NSString *, id> *)json {
    NSString *path = json[JsonKeyPath];
    if (path == nil) {
        return nil;
    }
    BSGJsonCollectionPath *collectionPath = [BSGJsonCollectionPath pathFromString:path];
    
    NSString *pathMode = json[JsonKeyPathMode];
    if ([pathMode isEqualToString:PathModeRegex]) {
        NSString *regex = json[JsonKeyRegex];
        return [[BSGRegexExtractor alloc] initWithPath:collectionPath regex:regex];
    }
    
    if ([pathMode isEqualToString:PathModeRelativeAddress]) {
        return [[BSGRelativeAddressExtractor alloc] initWithPath:collectionPath];
    }

    return [[BSGSimplePathExtractor alloc] initWithPath:collectionPath];
}

@end
