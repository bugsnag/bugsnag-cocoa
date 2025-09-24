//
//  BSGEventDiscardProcessor.h
//  Bugsnag
//
//  Created by Robert Bartoszewski on 19/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "../Source/BSGEventDiscardRulesetSource.h"

NS_ASSUME_NONNULL_BEGIN

@interface BSGEventDiscardProcessor : NSObject

@property (nonatomic, strong) BSGEventDiscardRulesetSource *source;

- (BOOL)shouldDiscardEvent:(NSDictionary *)eventPayload;

@end

NS_ASSUME_NONNULL_END
