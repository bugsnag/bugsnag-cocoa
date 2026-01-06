//
//  BSGEventDiscardRuleFactory.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 19/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGEventDiscardRuleFactory.h"
#import "../Source/Model/Rules/BSGAllEventsDiscardRule.h"
#import "../Source/Model/Rules/BSGAllHandledEventsDiscardRule.h"
#import "../Source/Model/Rules/BSGHashDiscardRule.h"

static NSString *const BSGDiscardRuleTypeAllEvents = @"ALL";
static NSString *const BSGDiscardRuleTypeAllHandledEvents = @"ALL_HANDLED";
static NSString *const BSGDiscardRuleTypeHash = @"HASH";

@implementation BSGEventDiscardRuleFactory

- (id<BSGEventDiscardRule>)ruleFromRemoteConfig:(BSGRemoteConfigurationDiscardRule *)rule {
    if ([rule.matchType isEqualToString:BSGDiscardRuleTypeAllEvents]) {
        return [BSGAllEventsDiscardRule new];
    }
    if ([rule.matchType isEqualToString:BSGDiscardRuleTypeAllHandledEvents]) {
        return [BSGAllHandledEventsDiscardRule new];
    }
    if ([rule.matchType isEqualToString:BSGDiscardRuleTypeHash]) {
        return [BSGHashDiscardRule fromJSON:rule.json extractorFactory:[BSGJsonDataExtractorFactory new]];
    }
    return nil;
}

@end
