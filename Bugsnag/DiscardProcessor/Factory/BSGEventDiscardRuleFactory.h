//
//  BSGEventDiscardRuleFactory.h
//  Bugsnag
//
//  Created by Robert Bartoszewski on 19/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "../Source/Model/BSGEventDiscardRule.h"
#import "../../RemoteConfig/Store/Model/BSGRemoteConfiguration.h"

@interface BSGEventDiscardRuleFactory : NSObject

- (id<BSGEventDiscardRule>)ruleFromRemoteConfig:(BSGRemoteConfigurationDiscardRule *)rule;

@end
