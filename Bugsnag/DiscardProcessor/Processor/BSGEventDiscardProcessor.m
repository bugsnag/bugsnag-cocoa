//
//  BSGEventDiscardProcessor.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 19/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGEventDiscardProcessor.h"

@interface BSGEventDiscardProcessor ()

@property (nonatomic, strong) BSGEventDiscardRuleset *ruleset;

@end

@implementation BSGEventDiscardProcessor

- (BOOL)shouldDiscardEvent:(NSDictionary *)eventPayload {
    [self updateRulesetIfNeeded];
    for (id<BSGEventDiscardRule> rule in self.ruleset.rules) {
        if ([rule shouldDiscardEvent:eventPayload]) {
            return YES;
        }
    }
    return NO;
}

#pragma mark Helpers

- (void)updateRulesetIfNeeded {
    if (![self.source isRulesetValid:self.ruleset]) {
        self.ruleset = [self.source currentRuleset];
    }
}

@end
