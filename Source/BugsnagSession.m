//
//  BugsnagSession.m
//  Bugsnag
//
//  Created by Jamie Lynch on 24/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import "BugsnagSession.h"
#import "BugsnagCollections.h"
#import "BSG_RFC3339DateTool.h"

static NSString *const kSessionId = @"id";
static NSString *const kUnhandledCount = @"unhandledCount";
static NSString *const kHandledCount = @"handledCount";
static NSString *const kStartedAt = @"startedAt";
static NSString *const kUser = @"user";

@implementation BugsnagSession

- (instancetype)initWithId:(NSString *_Nonnull)sessionId
                 startDate:(NSDate *_Nonnull)startDate
                      user:(BugsnagUser *_Nullable)user
              autoCaptured:(BOOL)autoCaptured {

    if (self = [super init]) {
        _sessionId = sessionId;
        _startedAt = [startDate copy];
        _user = user;
        _autoCaptured = autoCaptured;
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *_Nonnull)dict {
    if (self = [super init]) {
        _sessionId = dict[kSessionId];
        _unhandledCount = [dict[kUnhandledCount] unsignedIntegerValue];
        _handledCount = [dict[kHandledCount] unsignedIntegerValue];
        _startedAt = [BSG_RFC3339DateTool dateFromString:dict[kStartedAt]];

        NSDictionary *userDict = dict[kUser];

        if (userDict) {
            _user = [[BugsnagUser alloc] initWithDictionary:userDict];
        }
    }
    return self;
}

- (NSDictionary *)toJson {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    BSGDictInsertIfNotNil(dict, self.sessionId, kSessionId);
    BSGDictInsertIfNotNil(dict, @(self.unhandledCount), kUnhandledCount);
    BSGDictInsertIfNotNil(dict, @(self.handledCount), kHandledCount);
    BSGDictInsertIfNotNil(dict, [BSG_RFC3339DateTool stringFromDate:self.startedAt], kStartedAt);
    BSGDictInsertIfNotNil(dict, [self.user toJson], kUser);
    return [NSDictionary dictionaryWithDictionary:dict];
}

@end
