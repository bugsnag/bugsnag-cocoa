//
//  BugsnagSessionTrackingPayload.m
//  Bugsnag
//
//  Created by Jamie Lynch on 27/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import "BugsnagSessionTrackingPayload.h"
#import "BugsnagCollections.h"

@implementation BugsnagSessionTrackingPayload

- (NSDictionary *)toJson {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    
    NSMutableArray *sessionData = [NSMutableArray new];
    
    for (BugsnagSession *session in self.sessions) {
        [sessionData addObject:[session toJson]];
    }
    BSGDictInsertIfNotNil(dict, sessionData, @"session");
    return [NSDictionary dictionaryWithDictionary:dict];
}

@end
