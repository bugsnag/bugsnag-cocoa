//
//  BSGJsonDataExtractorFactory.h
//  Bugsnag
//
//  Created by Robert Bartoszewski on 20/11/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "../BSGJsonDataExtractor.h"

NS_ASSUME_NONNULL_BEGIN

@interface BSGJsonDataExtractorFactory: NSObject

- (BSGJsonDataExtractor * _Nullable)extractorFromJSON:(NSDictionary<NSString *, id> *)json;

@end

NS_ASSUME_NONNULL_END
