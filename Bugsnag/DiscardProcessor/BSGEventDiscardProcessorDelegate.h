//
//  BSGEventDiscardProcessorDelegate.h
//  Bugsnag
//
//  Created by Robert Bartoszewski on 19/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGEventDiscardRule.h"

@protocol BSGEventDiscardProcessorDelegate <NSObject>

- (NSArray<id<BSGEventDiscardRule>> *)discardRules;

@end
