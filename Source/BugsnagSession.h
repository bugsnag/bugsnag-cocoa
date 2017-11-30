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

@interface BugsnagSession : NSObject <JsonSerializable>

- (_Nonnull instancetype)initWithId:(NSString *_Nonnull)sessionId
                 startDate:(NSDate *_Nonnull)startDate
                      user:(BugsnagUser *_Nullable)user
              autoCaptured:(BOOL)autoCaptured;

@property(readonly) NSString *_Nonnull sessionId;
@property(readonly) NSDate *_Nonnull startedAt;
@property(readonly) BugsnagUser *_Nullable user;
@property(readonly) BOOL autoCaptured;

@property NSUInteger unhandledCount;
@property NSUInteger handledCount;

@end
