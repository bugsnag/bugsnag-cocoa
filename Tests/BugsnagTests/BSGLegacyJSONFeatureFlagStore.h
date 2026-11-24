//
//  BSGLegacyJSONFeatureFlagStore.h
//  Bugsnag
//
//  Test-only, renamed copy of master's legacy (one JSON file per flag) BSGPersistentFeatureFlagStore.
//
//  Copyright © 2024 Bugsnag. All rights reserved.
//

#import "BugsnagInternals.h"
#import "BSGDefines.h"
#import "BSGFeatureFlagStore.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BSGLegacyJSONFeatureFlagStore : NSObject <BSGReplaceableFeatureFlagStore>

- (instancetype)initWithStorageDirectory:(NSString *)directory;

@end

NS_ASSUME_NONNULL_END
