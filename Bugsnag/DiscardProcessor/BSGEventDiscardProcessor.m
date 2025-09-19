//
//  BSGEventDiscardProcessor.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 19/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGEventDiscardProcessor.h"
#import "BSGEventDiscardRule.h"

@interface BSGEventDiscardProcessor ()

@property (nonatomic, weak) id<BSGEventDiscardProcessorDelegate> delegate;

@end

@implementation BSGEventDiscardProcessor

- (instancetype)initWithDelegate:(id<BSGEventDiscardProcessorDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
    }
    return self;
}

- (BOOL)shouldDiscardEvent:(NSDictionary *)eventPayload {
    for (id<BSGEventDiscardRule> rule in [self.delegate discardRules]) {
        if ([rule shouldDiscardEvent:eventPayload]) {
            return YES;
        }
    }
    return NO;
}

@end
