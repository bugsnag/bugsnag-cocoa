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
static NSString const *AppVersionKey = @"appVersion";
static NSString const *InternalsKey = @"internals";
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

@implementation BSGRemoteConfigurationInternals

+ (instancetype)internalsFromJson:(NSDictionary *)json {
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
    return [[self alloc] initWithDiscardRules:discardRules];
}

- (instancetype)initWithDiscardRules:(NSArray<BSGRemoteConfigurationDiscardRule *> *)discardRules {
    if ((self = [super init])) {
        _discardRules = discardRules;
    }
    return self;
}

- (NSDictionary *)toJson {
    NSMutableArray *discardRulesJson = [NSMutableArray array];
    for (BSGRemoteConfigurationDiscardRule *rule in self.discardRules) {
        NSDictionary *ruleJson = [rule toJson];
        if (rule) {
            [discardRulesJson addObject:ruleJson];
        }
    }
    return @{
        DiscardRulesKey: discardRulesJson
    };
}

@end

@implementation BSGRemoteConfiguration

+ (instancetype)configFromJson:(NSDictionary *)json {
    NSString *configurationTag = json[ConfigurationTagKey];
    NSString *appVersion = json[AppVersionKey];
    return [self configFromJson:json eTag:configurationTag appVersion:appVersion];
}

+ (instancetype)configFromJson:(NSDictionary *)json
                          eTag:(NSString *)eTag
                    appVersion:(NSString *)appVersion {
    NSDate *expiryDate = [BSG_RFC3339DateTool dateFromString:json[ExpiryDateKey]];
    NSDictionary *internalsJson = json[InternalsKey];
    if (![eTag isKindOfClass:[NSString class]] ||
        ![expiryDate isKindOfClass:[NSDate class]] ||
        ![internalsJson isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    BSGRemoteConfigurationInternals *internals = [BSGRemoteConfigurationInternals internalsFromJson:internalsJson];
    if (internals == nil) {
        return nil;
    }
    return [[self alloc] initWithConfigurationTag:eTag
                                       appVersion:appVersion
                                       expiryDate:expiryDate
                                        internals:internals];
}

- (instancetype)initWithConfigurationTag:(NSString *)configurationTag
                              appVersion:(NSString *)appVersion
                              expiryDate:(NSDate *)expiryDate
                               internals:(BSGRemoteConfigurationInternals *)internals {
    if ((self = [super init])) {
        _configurationTag = configurationTag;
        _appVersion = appVersion;
        _expiryDate = expiryDate;
        _internals = internals;
    }
    return self;
}

- (NSDictionary *)toJson {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    if (self.configurationTag) {
        result[ConfigurationTagKey] = self.configurationTag;
    }
    if (self.appVersion) {
        result[AppVersionKey] = self.appVersion;
    }
    NSString *expiryDateJson = [BSG_RFC3339DateTool stringFromDate:self.expiryDate];
    if (expiryDateJson) {
        result[ExpiryDateKey] = expiryDateJson;
    }
    NSDictionary *internalsJson = [self.internals toJson];
    if (internalsJson) {
        result[InternalsKey] = internalsJson;
    }
    return result;
}

@end
