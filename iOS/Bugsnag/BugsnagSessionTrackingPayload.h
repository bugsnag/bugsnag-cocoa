//
//  BugsnagSessionTrackingPayload.h
//  Bugsnag
//
//  Created by Jamie Lynch on 27/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "BugsnagSession.h"
#import "JsonSerializable.h"

@interface BugsnagSessionTrackingPayload : NSObject<JsonSerializable>

@property NSArray<BugsnagSession *> *sessions;

// TODO serialise notifier, device, app

@end
