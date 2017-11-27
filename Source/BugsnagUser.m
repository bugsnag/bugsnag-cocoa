//
//  BugsnagUser.m
//  Bugsnag
//
//  Created by Jamie Lynch on 24/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import "BugsnagUser.h"
#import "BugsnagCollections.h"

@implementation BugsnagUser

- (NSDictionary *)toJson {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    BSGDictInsertIfNotNil(dict, self.userId, @"id");
    BSGDictInsertIfNotNil(dict, self.emailAddress, @"emailAddress");
    BSGDictInsertIfNotNil(dict, self.name, @"name");
    return [NSDictionary dictionaryWithDictionary:dict];
}

@end
