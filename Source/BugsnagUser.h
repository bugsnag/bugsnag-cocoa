//
//  BugsnagUser.h
//  Bugsnag
//
//  Created by Jamie Lynch on 24/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "JsonSerializable.h"

@interface BugsnagUser : NSObject<JsonSerializable>

- (instancetype)initWithDictionary:(NSDictionary *)dict;

@property NSString *userId;
@property NSString *name;
@property NSString *emailAddress;

@end
