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
