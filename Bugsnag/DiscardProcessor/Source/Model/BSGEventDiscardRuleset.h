//
//  BSGEventDiscardRuleset.h
//  Bugsnag
//
//  Created by Robert Bartoszewski on 22/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BSGEventDiscardRule.h"

@interface BSGEventDiscardRuleset : NSObject

@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic, strong) NSArray<id<BSGEventDiscardRule>> *rules;

@end
