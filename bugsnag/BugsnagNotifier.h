//
//  BugsnagNotifier.h
//  Bugsnag
//
//  Created by Simon Maynard on 8/28/13.
//  Copyright (c) 2013 Simon Maynard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BugsnagConfiguration.h"
#import "BugsnagEvent.h"

typedef void (^BugsnagNotifyBlock)(BugsnagEvent*);

@interface BugsnagNotifier : NSObject

- (id) init;

- (void) notifySignal:(int)signal;
- (void) notifyUncaughtException:(NSException*)exception;
- (void) notifyException:(NSException*)exception withMetaData:(NSDictionary*)metaData;

- (BOOL) shouldAutoNotify;
- (BOOL) shouldNotify;

- (NSDictionary*) buildNotifyPayload;
- (void) beforeNotify:(BugsnagNotifyBlock)block;

- (void) saveEvent:(BugsnagEvent*)event;
- (NSString*) generateEventFilename;
- (NSArray*) savedEvents;
- (void) sendSavedEvents;

@property (atomic, copy) NSString *notifierName;
@property (atomic, copy) NSString *notifierVersion;
@property (atomic, copy) NSString *notifierURL;
@property (atomic) BugsnagConfiguration *configuration;
@property (atomic, readonly) NSString *errorPath;

@end
