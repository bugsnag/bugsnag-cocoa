//
//  BSGEventDiscardRulesetSource.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 22/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGEventDiscardRulesetSource.h"
#import "../../KSCrash/Source/KSCrash/Recording/Tools/BSG_KSLogger.h"

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
    return [self.remoteConfigHandler.lastConfigUpdateTime timeIntervalSinceDate:ruleset.createdAt] > 0 && [self.remoteConfigHandler hasValidConfig];
}

- (NSArray<id<BSGEventDiscardRule>> *)discardRules {
    NSMutableArray<id<BSGEventDiscardRule>> *rules = [NSMutableArray array];
    BSGRemoteConfiguration *remoteConfig = self.remoteConfigHandler.currentConfiguration;
    bsg_i_kslog_logCBasic("Has config?");
    if (remoteConfig) {
        bsg_i_kslog_logCBasic("Parsing config");
        for (BSGRemoteConfigurationDiscardRule *rule in remoteConfig.discardRules) {
            id<BSGEventDiscardRule> discardRule = [self.discardRuleFactory ruleFromRemoteConfig:rule];
            if (discardRule) {
                [rules addObject:discardRule];
            }
        }
    } else {
        bsg_i_kslog_logCBasic("No config");
    }
    return rules;
}

@end
