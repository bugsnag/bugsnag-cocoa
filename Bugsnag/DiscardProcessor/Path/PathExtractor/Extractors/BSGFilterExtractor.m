//
//  BSGFilterExtractor.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 20/11/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGFilterExtractor.h"

@interface BSGFilterExtractorCondition ()

@property (nonatomic, strong) BSGJsonCollectionPath *filterPath;
@property (nonatomic) BSGFilterExtractorMatchType matchType;
@property (nonatomic, strong, nullable) NSString *expectedValue;

- (BOOL)matches:(NSDictionary<NSString *,id> *)json;

@end

@interface BSGFilterExtractor ()

@property (nonatomic, strong) NSArray<BSGFilterExtractorCondition *> *conditions;
@property (nonatomic, strong) NSArray<BSGJsonDataExtractor *> *subExtractors;

@end

@implementation BSGFilterExtractor

- (instancetype)initWithPath:(BSGJsonCollectionPath *)path
                  conditions:(NSArray<BSGFilterExtractorCondition *> *)conditions
               subExtractors:(NSArray<BSGJsonDataExtractor *> *)subExtractors {
    self = [super initWithPath:path];
    if (self) {
        _conditions = conditions;
        _subExtractors = subExtractors;
    }
    return self;
}

- (void)extractFromJSON:(NSDictionary<NSString *,id> *)json onElementExtracted:(void (^)(NSString *))onElementExtracted {
    for (id element in [self.path extractFromJSON:json]) {
        NSArray *list;
        if ([element isKindOfClass:[NSArray class]]) {
            list = element;
        } else {
            list = @[element];
        }
        for (id subJson in list) {
            if (![subJson isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            if (![self matchesAllConditions:subJson]) {
                continue;
            }
            for (BSGJsonDataExtractor *extractor in self.subExtractors) {
                [extractor extractFromJSON:subJson onElementExtracted:onElementExtracted];
            }
        }
    }
}

- (BOOL)matchesAllConditions:(NSDictionary<NSString *,id> *)json {
    for (BSGFilterExtractorCondition *condition in self.conditions) {
        if (![condition matches:json]) {
            return NO;
        }
    }
    return YES;
}

@end

@implementation BSGFilterExtractorCondition

- (instancetype)initWithFilterPath:(BSGJsonCollectionPath *)filterPath
                         matchType:(BSGFilterExtractorMatchType)matchType
                     expectedValue:(NSString * _Nullable)expectedValue {
    self = [super init];
    if (self) {
        _filterPath = filterPath;
        _matchType = matchType;
        _expectedValue = expectedValue;
    }
    return self;
}

- (BOOL)matches:(NSDictionary<NSString *,id> *)json {
    NSArray *allValues = [self.filterPath extractFromJSON:json];
    id extractedValue = [allValues firstObject];
    
    switch (self.matchType) {
        case BSGFilterExtractorMatchTypeEquals:
            return [extractedValue isEqual:self.expectedValue];
        case BSGFilterExtractorMatchTypeNotEquals:
            return ![extractedValue isEqual:self.expectedValue];
        case BSGFilterExtractorMatchTypeIsNull:
            if ([self.expectedValue isEqualToString:@"true"]) {
                return extractedValue == nil;
            } else {
                return extractedValue != nil;
            }
            
        default:
            return false;
    }
}

@end
