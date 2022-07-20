//
//  BugsnagUser.m
//  Bugsnag
//
//  Created by Jamie Lynch on 24/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import "BugsnagUser+Private.h"

#import "BSG_KSSystemInfo.h"

@implementation BugsnagUser

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    if ((self = [super init])) {
        _id = dict[@"id"];
        _email = dict[@"email"];
        _name = dict[@"name"];
    }
    return self;
}

- (instancetype)initWithId:(NSString *)id name:(NSString *)name emailAddress:(NSString *)emailAddress {
    if ((self = [super init])) {
        _id = id;
        _name = name;
        _email = emailAddress;
    }
    return self;
}

- (NSDictionary *)toJson {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[@"id"] = self.id;
    dict[@"email"] = self.email;
    dict[@"name"] = self.name;
    return [NSDictionary dictionaryWithDictionary:dict];
}

- (BugsnagUser *)withId {
    if (self.id) {
        return self;
    } else {
        return [[BugsnagUser alloc] initWithId:[BSG_KSSystemInfo deviceAndAppHash]
                                              name:self.name
                                      emailAddress:self.email];
    }
}

@end
