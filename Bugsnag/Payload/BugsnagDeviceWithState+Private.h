//
//  BugsnagDeviceWithState+Private.h
//  Bugsnag
//
//  Created by Nick Dowell on 04/12/2020.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import <Bugsnag/BugsnagDeviceWithState.h>

#import "BSGDefines.h"

struct BSGRunContext;

NS_ASSUME_NONNULL_BEGIN

@interface BugsnagDeviceWithState ()

#pragma mark Initializers

+ (instancetype)deviceFromJson:(NSDictionary *)json;

+ (instancetype)deviceWithKSCrashReport:(NSDictionary *)event;

#pragma mark Methods

- (void)appendRuntimeInfo:(NSDictionary *)info;

- (NSDictionary *)toDictionary;

@end

NSMutableDictionary *BSGParseDeviceMetadata(NSDictionary *event);

BSG_PRIVATE NSDictionary * BSGDeviceMetadataFromRunContext(const struct BSGRunContext *context);

NS_ASSUME_NONNULL_END
