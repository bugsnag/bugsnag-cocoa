//
//  BSGRegexExtractor.h
//  Bugsnag
//
//  Created by Robert Bartoszewski on 20/11/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGJsonDataExtractor.h"

@interface BSGRegexExtractor : BSGJsonDataExtractor

- (instancetype)initWithPath:(BSGJsonCollectionPath *)path regex:(NSString *)regex;

@end
