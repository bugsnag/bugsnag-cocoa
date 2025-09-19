//
//  BSGEventDiscardProcessor.h
//  Bugsnag
//
//  Created by Robert Bartoszewski on 19/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BSGEventDiscardProcessorDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface BSGEventDiscardProcessor : NSObject

- (instancetype)initWithDelegate:(id<BSGEventDiscardProcessorDelegate>)delegate;

- (BOOL)shouldDiscardEvent:(NSDictionary *)eventPayload;

@end

NS_ASSUME_NONNULL_END
