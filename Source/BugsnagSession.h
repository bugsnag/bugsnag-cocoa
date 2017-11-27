//
//  BugsnagSession.h
//  Bugsnag
//
//  Created by Jamie Lynch on 24/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "BugsnagUser.h"
#import "JsonSerializable.h"

@interface BugsnagSession : NSObject<JsonSerializable>

@property NSString *sessionId;
@property NSDate *startedAt;
@property BugsnagUser *user;
@property NSInteger unhandledCount;
@property NSInteger handledCount;
@property BOOL autoCaptured;

@end
