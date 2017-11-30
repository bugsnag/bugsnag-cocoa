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

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    if (self = [super init]) {
        _userId = dict[@"id"];
        _emailAddress = dict[@"emailAddress"];
        _name = dict[@"name"];
    }
    return self;
}

- (NSDictionary *)toJson {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    BSGDictInsertIfNotNil(dict, self.userId, @"id");
    BSGDictInsertIfNotNil(dict, self.emailAddress, @"emailAddress");
    BSGDictInsertIfNotNil(dict, self.name, @"name");
    return [NSDictionary dictionaryWithDictionary:dict];
}
@end
