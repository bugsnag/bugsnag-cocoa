//
//  FixtureConfig.m
//  macOSTestApp
//
//  Created by Karl Stenerud on 26.09.24.
//  Copyright © 2024 Bugsnag Inc. All rights reserved.
//

#import "FixtureConfig.h"

@implementation FixtureConfig

- (instancetype) initWithApiKey:(NSString *)apiKey mazeRunnerBaseAddress:(NSURL *)mazeRunnerBaseAddress {
    if ((self = [super init])) {
        _apiKey = apiKey;
        _mazeRunnerURL = mazeRunnerBaseAddress;
        _docsURL = [mazeRunnerBaseAddress URLByAppendingPathComponent:@"docs"];
        _tracesURL = [mazeRunnerBaseAddress URLByAppendingPathComponent:@"traces"];
        _commandURL = [mazeRunnerBaseAddress URLByAppendingPathComponent:@"command"];
        _metricsURL = [mazeRunnerBaseAddress URLByAppendingPathComponent:@"metrics"];
        _notifyURL = [mazeRunnerBaseAddress URLByAppendingPathComponent:@"notify"];
        _sessionsURL = [mazeRunnerBaseAddress URLByAppendingPathComponent:@"sessions"];
        _reflectURL = [mazeRunnerBaseAddress URLByAppendingPathComponent:@"reflect"];
    }
    return self;
}

@end
