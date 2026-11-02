//
//  BSGLegacyJSONFeatureFlagStore.h
//  Bugsnag
//
//  Test-only copy of the legacy (one JSON file per flag) BSGPersistentFeatureFlagStore
//  from master, renamed so it can be benchmarked against the memory-mapped store.
//
//  Copyright © 2024 Bugsnag. All rights reserved.
//

#import "BugsnagInternals.h"
#import "BSGDefines.h"
#import "BSGFeatureFlagStore.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BSGLegacyJSONFeatureFlagStore : NSObject <BSGFeatureFlagStore>

- (instancetype)initWithStorageDirectory:(NSString *)directory;

@end

NS_ASSUME_NONNULL_END
