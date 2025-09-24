//
//  BSGEventDiscardRulesetSource.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 22/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGEventDiscardRulesetSource.h"

@interface BSGEventDiscardRulesetSource ()

@property (nonatomic, strong) BSGRemoteConfigHandler *remoteConfigHandler;
@property (nonatomic, strong) BSGEventDiscardRuleFactory *discardRuleFactory;

@end


@implementation BSGEventDiscardRulesetSource

+ (instancetype)sourceWithRemoteConfigHandler:(BSGRemoteConfigHandler *)remoteConfigHandler
                           discardRuleFactory:(BSGEventDiscardRuleFactory *)discardRuleFactory {
    return [[self alloc] initWithRemoteConfigHandler:remoteConfigHandler
                                  discardRuleFactory:discardRuleFactory];
}

- (instancetype)initWithRemoteConfigHandler:(BSGRemoteConfigHandler *)remoteConfigHandler
                         discardRuleFactory:(BSGEventDiscardRuleFactory *)discardRuleFactory {
    self = [super init];
    if (self) {
        _remoteConfigHandler = remoteConfigHandler;
        _discardRuleFactory = discardRuleFactory;
    }
    return self;
}

- (BSGEventDiscardRuleset *)currentRuleset {
    BSGEventDiscardRuleset *ruleset = [BSGEventDiscardRuleset new];
    ruleset.createdAt = [NSDate date];
    ruleset.rules = [self discardRules];
    return ruleset;
}

- (BOOL)isRulesetValid:(BSGEventDiscardRuleset *)ruleset {
    return [ruleset.createdAt timeIntervalSinceDate:self.remoteConfigHandler.lastConfigUpdateTime] > 0 && [self.remoteConfigHandler hasValidConfig];
}

- (NSArray<id<BSGEventDiscardRule>> *)discardRules {
    NSMutableArray<id<BSGEventDiscardRule>> *rules = [NSMutableArray array];
    BSGRemoteConfiguration *remoteConfig = self.remoteConfigHandler.currentConfiguration;
    if (remoteConfig) {
        for (BSGRemoteConfigurationDiscardRule *rule in remoteConfig.internals.discardRules) {
            id<BSGEventDiscardRule> discardRule = [self.discardRuleFactory ruleFromRemoteConfig:rule];
            if (discardRule) {
                [rules addObject:discardRule];
            }
        }
    }
    return rules;
}

@end
