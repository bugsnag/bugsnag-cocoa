//
//  FixtureConfig.h
//  macOSTestApp
//
//  Created by Karl Stenerud on 26.09.24.
//  Copyright © 2024 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FixtureConfig : NSObject

@property NSString *apiKey;
@property NSURL *mazeRunnerURL;
@property NSURL *docsURL;
@property NSURL *tracesURL;
@property NSURL *commandURL;
@property NSURL *metricsURL;
@property NSURL *reflectURL;
@property NSURL *notifyURL;
@property NSURL *sessionsURL;

//init(apiKey: String, mazeRunnerBaseAddress: URL) {

- (instancetype) initWithApiKey:(NSString *)apiKey mazeRunnerBaseAddress:(NSURL *)mazeRunnerBaseAddress;

@end

NS_ASSUME_NONNULL_END
