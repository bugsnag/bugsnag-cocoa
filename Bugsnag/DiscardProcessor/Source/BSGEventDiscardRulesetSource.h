//
//  BSGEventDiscardRulesetSource.h
//  Bugsnag
//
//  Created by Robert Bartoszewski on 22/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Model/BSGEventDiscardRuleset.h"
#import "../Factory/BSGEventDiscardRuleFactory.h"
#import "../../RemoteConfig/Handler/BSGRemoteConfigHandler.h"

@interface BSGEventDiscardRulesetSource: NSObject

+ (instancetype)sourceWithRemoteConfigHandler:(BSGRemoteConfigHandler *)remoteConfigHandler
                           discardRuleFactory:(BSGEventDiscardRuleFactory *)discardRuleFactory;

- (BSGEventDiscardRuleset *)currentRuleset;
- (BOOL)isRulesetValid:(BSGEventDiscardRuleset *)ruleset;

@end
