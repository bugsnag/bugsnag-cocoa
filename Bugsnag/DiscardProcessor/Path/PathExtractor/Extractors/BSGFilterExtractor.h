//
//  BSGFilterExtractor.h
//  Bugsnag
//
//  Created by Robert Bartoszewski on 20/11/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "../BSGJsonDataExtractor.h"

typedef NS_ENUM(NSInteger, BSGFilterExtractorMatchType) {
    BSGFilterExtractorMatchTypeEquals,
    BSGFilterExtractorMatchTypeNotEquals,
    BSGFilterExtractorMatchTypeIsNull
};

@class BSGJsonCollectionPath;

@interface BSGFilterExtractorCondition : NSObject

@property (nonatomic, strong, readonly) BSGJsonCollectionPath *filterPath;
@property (nonatomic, readonly) BSGFilterExtractorMatchType matchType;
@property (nonatomic, strong, readonly) NSString *expectedValue;

- (instancetype)initWithFilterPath:(BSGJsonCollectionPath *)filterPath
                         matchType:(BSGFilterExtractorMatchType)matchType
                     expectedValue:(NSString *)expectedValue;

@end

@interface BSGFilterExtractor : BSGJsonDataExtractor

- (instancetype)initWithPath:(BSGJsonCollectionPath *)path
                  conditions:(NSArray<BSGFilterExtractorCondition *> *)conditions
               subExtractors:(NSArray<BSGJsonDataExtractor *> *)subExtractors;

@end
