//
//  BSGEventDiscardRuleFactory.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 19/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGEventDiscardRuleFactory.h"
#import "Rules/BSGAllEventsDiscardRule.h"
#import "Rules/BSGAllHandledEventsDiscardRule.h"

static NSString *const BSGDiscardRuleTypeAllEvents = @"ALL";
static NSString *const BSGDiscardRuleTypeAllHandledEvents = @"ALL_HANDLED";

@implementation BSGEventDiscardRuleFactory

- (id<BSGEventDiscardRule>)ruleFromRemoteConfig:(BSGRemoteConfigurationDiscardRule *)rule {
    if ([rule.matchType isEqualToString:BSGDiscardRuleTypeAllEvents]) {
        return [BSGAllEventsDiscardRule new];
    }
    if ([rule.matchType isEqualToString:BSGDiscardRuleTypeAllHandledEvents]) {
        return [BSGAllHandledEventsDiscardRule new];
    }
    return nil;
}

@end
