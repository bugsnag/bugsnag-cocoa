//
//  BSGHashDiscardRule.h
//  Bugsnag
//
//  Created by Robert Bartoszewski on 02/01/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import "BSGEventDiscardRule.h"
#import "BSGJsonDataExtractorFactory.h"

@interface BSGHashDiscardRule : NSObject <BSGEventDiscardRule>

+ (instancetype)fromJSON:(NSDictionary<NSString *, id> *)json
        extractorFactory:(BSGJsonDataExtractorFactory *)extractorFactory;

@end
