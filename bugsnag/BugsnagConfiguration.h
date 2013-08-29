//
//  BugsnagConfiguration.h
//  bugsnag
//
//  Created by Simon Maynard on 8/28/13.
//  Copyright (c) 2013 Simon Maynard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BugsnagMetaData.h"

@interface BugsnagConfiguration : NSObject

@property (atomic, copy) NSString *apiKey;

@property (atomic, copy) NSString *userId;
@property (atomic, copy) NSString *appVersion;
@property (atomic, copy) NSString *osVersion;
@property (atomic, copy) NSString *releaseStage;
@property (atomic, copy) NSString *context;
@property (atomic, strong) BugsnagMetaData *metaData;

@property (atomic) BOOL enableSSL;
@property (atomic) BOOL autoNotify;
@property (atomic, copy) NSArray *notifyReleaseStages;

@end
