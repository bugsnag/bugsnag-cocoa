//
//  BSGPersistentFeatureFlagStore.h
//  Bugsnag
//
//  Created by Robert B on 25/11/2024.
//  Copyright © 2024 Bugsnag. All rights reserved.
//

#import "BugsnagInternals.h"
#import "BSGDefines.h"
#import "BSGFeatureFlagStore.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

BSG_OBJC_DIRECT_MEMBERS
@interface BSGPersistentFeatureFlagStore ()

- (instancetype)initWithStorageDirectory:(NSString *)directory;

@end

NS_ASSUME_NONNULL_END
