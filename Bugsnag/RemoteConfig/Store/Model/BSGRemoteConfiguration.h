//
//  BSGRemoteConfiguration.h
//  Bugsnag
//
//  Created by Robert Bartoszewski on 11/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BSGRemoteConfigurationDiscardRule : NSObject

@property (nonatomic, strong) NSString *matchType;
@property (nonatomic, strong) NSDictionary<NSString *, id> *json;

+ (instancetype)ruleFromJson:(NSDictionary *)json;

@end

@interface BSGRemoteConfiguration : NSObject

@property (nonatomic, strong) NSString *configurationTag;
@property (nonatomic, strong) NSDate *expiryDate;
@property (nonatomic, strong) NSArray<BSGRemoteConfigurationDiscardRule *> *discardRules;

+ (instancetype)configFromJson:(NSDictionary *)json;
+ (instancetype)configFromJson:(NSDictionary *)json
                          eTag:(NSString *)eTag
                    expiryDate:(NSDate *)expiryDate;
- (NSDictionary *)toJson;

@end
