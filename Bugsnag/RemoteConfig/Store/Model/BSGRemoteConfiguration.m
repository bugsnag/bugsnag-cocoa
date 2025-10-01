//
//  BSGRemoteConfiguration.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 11/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGRemoteConfiguration.h"
#import "BSG_RFC3339DateTool.h"

static NSString const *ConfigurationTagKey = @"configurationTag";
static NSString const *ExpiryDateKey = @"expiryDate";
static NSString const *DiscardRulesKey = @"discardRules";
static NSString const *MatchTypeKey = @"matchType";

@implementation BSGRemoteConfigurationDiscardRule

+ (instancetype)ruleFromJson:(NSDictionary *)json {
    NSString *matchType = json[MatchTypeKey];
    if (![matchType isKindOfClass:[NSString class]]) {
        return nil;
    }
    return [[self alloc] initWithMatchType:matchType];
}

- (instancetype)initWithMatchType:(NSString *)matchType {
    if ((self = [super init])) {
        _matchType = matchType;
    }
    return self;
}

- (NSDictionary *)toJson {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    if (self.matchType) {
        result[MatchTypeKey] = self.matchType;
    }
    return result;
}

@end

@implementation BSGRemoteConfiguration

+ (instancetype)configFromJson:(NSDictionary *)json {
    NSString *configurationTag = json[ConfigurationTagKey];
    NSDate *expiryDate = [BSG_RFC3339DateTool dateFromString:json[ExpiryDateKey]];
    return [self configFromJson:json
                           eTag:configurationTag
                     expiryDate:expiryDate];
}

+ (instancetype)configFromJson:(NSDictionary *)json
                          eTag:(NSString *)eTag
                    expiryDate:(NSDate *)expiryDate {
    if (![eTag isKindOfClass:[NSString class]] ||
        ![expiryDate isKindOfClass:[NSDate class]]) {
        return nil;
    }
    NSMutableArray *discardRules = [NSMutableArray array];
    NSArray *discardRulesJson = json[DiscardRulesKey];
    for (NSDictionary *ruleJson in discardRulesJson) {
        if (![ruleJson isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        BSGRemoteConfigurationDiscardRule *rule = [BSGRemoteConfigurationDiscardRule ruleFromJson:ruleJson];
        if (rule) {
            [discardRules addObject:rule];
        }
    }
    return [[self alloc] initWithConfigurationTag:eTag
                                       expiryDate:expiryDate
                                     discardRules:discardRules];
}

- (instancetype)initWithConfigurationTag:(NSString *)configurationTag
                              expiryDate:(NSDate *)expiryDate
                            discardRules:(NSArray<BSGRemoteConfigurationDiscardRule *> *)discardRules {
    if ((self = [super init])) {
        _configurationTag = configurationTag;
        _expiryDate = expiryDate;
        _discardRules = discardRules;
    }
    return self;
}

- (NSDictionary *)toJson {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    if (self.configurationTag) {
        result[ConfigurationTagKey] = self.configurationTag;
    }
    NSString *expiryDateJson = [BSG_RFC3339DateTool stringFromDate:self.expiryDate];
    if (expiryDateJson) {
        result[ExpiryDateKey] = expiryDateJson;
    }
    NSMutableArray *discardRulesJson = [NSMutableArray array];
    for (BSGRemoteConfigurationDiscardRule *rule in self.discardRules) {
        NSDictionary *ruleJson = [rule toJson];
        if (rule) {
            [discardRulesJson addObject:ruleJson];
        }
    }
    result[DiscardRulesKey] = discardRulesJson;
    
    return result;
}

@end
