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


- (NSDictionary *)toJson {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    BSGDictInsertIfNotNil(dict, self.sessionId, @"id");
    BSGDictInsertIfNotNil(dict, @(self.unhandledCount), @"unhandledCount");
    BSGDictInsertIfNotNil(dict, @(self.handledCount), @"handledCount");
    BSGDictInsertIfNotNil(dict, [BSG_RFC3339DateTool stringFromDate:self.startedAt], @"startedAt");
    BSGDictInsertIfNotNil(dict, [self.user toJson], @"user");
    return [NSDictionary dictionaryWithDictionary:dict];
}

@end
