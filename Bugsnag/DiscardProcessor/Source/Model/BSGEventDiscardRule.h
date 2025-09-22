//
//  BSGEventDiscardRule.h
//  Bugsnag
//
//  Created by Robert Bartoszewski on 19/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol BSGEventDiscardRule <NSObject>

- (BOOL)shouldDiscardEvent:(NSDictionary *)eventPayload;

@end

NS_ASSUME_NONNULL_END
