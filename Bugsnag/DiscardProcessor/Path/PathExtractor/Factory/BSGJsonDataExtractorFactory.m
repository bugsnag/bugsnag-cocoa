//
//  BSGJsonDataExtractorFactory.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 20/11/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGJsonDataExtractorFactory.h"
#import "../Extractors/BSGFilterExtractor.h"
#import "../Extractors/BSGRegexExtractor.h"
#import "../Extractors/BSGRelativeAddressExtractor.h"
#import "../Extractors/BSGSimplePathExtractor.h"

static NSString * const JsonKeyPathMode = @"pathMode";
static NSString * const JsonKeyPath = @"path";
static NSString * const JsonKeyRegex = @"regex";
static NSString * const JsonKeyFilter = @"filter";
static NSString * const JsonKeyConditions = @"conditions";
static NSString * const JsonKeySubPaths = @"subPaths";
static NSString * const JsonKeyFilterPath = @"filterPath";
static NSString * const JsonKeyMatchType = @"matchType";
static NSString * const JsonKeyValue = @"value";

static NSString * const PathModeRegex = @"REGEX";
static NSString * const PathModeFilter = @"FILTER";
static NSString * const PathModeRelativeAddress = @"RELATIVE_ADDRESS";

static NSString * const MatchTypeEquals = @"EQUALS";
static NSString * const MatchTypeNotEquals = @"NOT_EQUALS";
static NSString * const MatchTypeIsNull = @"IS_NULL";

@implementation BSGJsonDataExtractorFactory

- (BSGJsonDataExtractor * _Nullable)extractorFromJSON:(NSDictionary<NSString *, id> *)json {
    NSString *path = json[JsonKeyPath];
    if (path == nil) {
        return nil;
    }
    BSGJsonCollectionPath *collectionPath = [BSGJsonCollectionPath pathFromString:path];
    
    NSString *pathMode = json[JsonKeyPathMode];
    
    if ([pathMode isEqualToString:PathModeFilter]) {
        NSDictionary *filterJson = json[JsonKeyFilter];
        return [[BSGFilterExtractor alloc] initWithPath:collectionPath
                                             conditions:[self conditionsFromFilter:filterJson]
                                          subExtractors:[self subExtractorsFromFilter:filterJson]];
    }
    
    if ([pathMode isEqualToString:PathModeRegex]) {
        NSString *regex = json[JsonKeyRegex];
        return [[BSGRegexExtractor alloc] initWithPath:collectionPath regex:regex];
    }
    
    if ([pathMode isEqualToString:PathModeRelativeAddress]) {
        return [[BSGRelativeAddressExtractor alloc] initWithPath:collectionPath];
    }

    return [[BSGSimplePathExtractor alloc] initWithPath:collectionPath];
}

- (NSArray<BSGFilterExtractorCondition *> *)conditionsFromFilter:(id)filter {
    if (![filter isKindOfClass:[NSDictionary class]]) {
        return @[];
    }
    
    NSDictionary *filterDict = (NSDictionary *)filter;
    NSArray *conditionsArray = filterDict[JsonKeyConditions];
    
    if (![conditionsArray isKindOfClass:[NSArray class]]) {
        return @[];
    }
    
    NSMutableArray<BSGFilterExtractorCondition *> *result = [NSMutableArray array];
    
    for (id element in conditionsArray) {
        if (![element isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        
        NSDictionary *conditionDict = (NSDictionary *)element;
        
        // Parse filterPath
        NSString *filterPathString = conditionDict[JsonKeyFilterPath];
        NSString *matchTypeString = conditionDict[JsonKeyMatchType];
        if (![filterPathString isKindOfClass:[NSString class]] ||
            ![matchTypeString isKindOfClass:[NSString class]]) {
            continue;
        }
        BSGJsonCollectionPath *filterPath = [BSGJsonCollectionPath pathFromString:filterPathString];
        
        BSGFilterExtractorMatchType matchType;
        if ([matchTypeString isEqualToString:MatchTypeEquals]) {
            matchType = BSGFilterExtractorMatchTypeEquals;
        } else if ([matchTypeString isEqualToString:MatchTypeNotEquals]) {
            matchType = BSGFilterExtractorMatchTypeNotEquals;
        } else if ([matchTypeString isEqualToString:MatchTypeIsNull]) {
            matchType = BSGFilterExtractorMatchTypeIsNull;
        } else {
            continue; // Unknown match type
        }
        
        NSString *expectedValue = conditionDict[JsonKeyValue];
        
        // Create condition object
        BSGFilterExtractorCondition *condition = [[BSGFilterExtractorCondition alloc] initWithFilterPath:filterPath
                                                                                                matchType:matchType
                                                                                            expectedValue:expectedValue];
        [result addObject:condition];
    }
    
    return result;
}

- (NSArray<BSGJsonDataExtractor *> *)subExtractorsFromFilter:(id)filter {
    if (![filter isKindOfClass:[NSDictionary class]]) {
        return @[];
    }
    
    NSDictionary *filterDict = (NSDictionary *)filter;
    NSArray *subPathsArray = filterDict[JsonKeySubPaths];
    
    if (![subPathsArray isKindOfClass:[NSArray class]] || subPathsArray.count == 0) {
        return nil; // We require at least one valid subPath
    }
    
    NSMutableArray<BSGJsonDataExtractor *> *result = [NSMutableArray array];
    
    for (id element in subPathsArray) {
        if (![element isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        
        BSGJsonDataExtractor *extractor = [self extractorFromJSON:element];
        if (extractor != nil) {
            [result addObject:extractor];
        }
    }
    
    // We require at least one valid subPath
    return result.count > 0 ? result : nil;
}

@end
