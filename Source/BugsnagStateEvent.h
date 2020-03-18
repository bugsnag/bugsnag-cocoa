//
//  BugsnagStateEvent.h
//  Bugsnag
//
//  Created by Jamie Lynch on 18/03/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *const kStateEventContext = @"ContextUpdate";
static NSString *const kStateEventMetadata = @"MetadataUpdate";
static NSString *const kStateEventUser = @"UserUpdate";

@interface BugsnagStateEvent : NSObject
- (instancetype)initWithName:(NSString *)name data:(id)data;
@property NSString *name;
@property id data;
@end

@protocol BugsnagObservable <NSObject>
@property BugsnagStateEvent *observable;
@end

NS_ASSUME_NONNULL_END
