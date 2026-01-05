//
//  BSGJsonDataExtractorFactory.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 20/11/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGJsonDataExtractorFactory.h"
#import "BSGRegexExtractor.h"
#import "BSGSimplePathExtractor.h"

static NSString * const JsonKeyPathMode = @"pathMode";
static NSString * const JsonKeyPath = @"path";
static NSString * const JsonKeyRegex = @"regex";
static NSString * const PathModeRegex = @"REGEX";

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
    return [[BSGSimplePathExtractor alloc] initWithPath:collectionPath];
}

@end
