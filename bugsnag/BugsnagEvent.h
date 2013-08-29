//
//  BugsnagEvent.h
//  bugsnag
//
//  Created by Simon Maynard on 8/28/13.
//  Copyright (c) 2013 Simon Maynard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BugsnagConfiguration.h"
#import "BugsnagMetaData.h"

@interface BugsnagEvent : NSObject

- (id) initWithConfiguration:(BugsnagConfiguration *)configuration andMetaData:(BugsnagMetaData*)metaData;

- (void) addSignal:(int) signal;
- (void) addException:(NSException*)exception;

- (NSDictionary *) toDictionary;

- (NSDictionary *) loadedImages;
- (NSArray *) getStackTraceWithException:(NSException*) exception;

@end
