//
//  BSGEventDiscardProcessor.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 19/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGEventDiscardProcessor.h"
#import "../../KSCrash/Source/KSCrash/Recording/Tools/BSG_KSLogger.h"

@interface BSGEventDiscardProcessor ()

@property (nonatomic, strong) BSGEventDiscardRuleset *ruleset;

@end

@implementation BSGEventDiscardProcessor

- (BOOL)shouldDiscardEvent:(NSDictionary *)eventPayload {
    [self updateRulesetIfNeeded];
    bsg_i_kslog_logCBasic("RULES %lu", (unsigned long)self.ruleset.rules.count);
    for (id<BSGEventDiscardRule> rule in self.ruleset.rules) {
        if ([rule shouldDiscardEvent:eventPayload]) {
            return YES;
        }
    }
    return NO;
}

#pragma mark Helpers

- (void)updateRulesetIfNeeded {
    bsg_i_kslog_logCBasic("updateRulesetIfNeeded");
    if (![self.source isRulesetValid:self.ruleset]) {
        bsg_i_kslog_logCBasic("Ruleset not valid");
        self.ruleset = [self.source currentRuleset];
    }
    bsg_i_kslog_logCBasic("updateRulesetIfNeeded complete");
}

@end
