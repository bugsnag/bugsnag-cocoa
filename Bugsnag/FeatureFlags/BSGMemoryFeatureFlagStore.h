//
//  BSGMemoryFeatureFlagStore.h
//  Bugsnag
//
//  Created by Nick Dowell on 11/11/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "BugsnagInternals.h"
#import "BSGDefines.h"

NS_ASSUME_NONNULL_BEGIN

NSArray<NSDictionary *> * BSGFeatureFlagStoreToJSON(id<BSGFeatureFlagStore> store);

BSGMemoryFeatureFlagStore * BSGFeatureFlagStoreFromJSON(id _Nullable json);
BSGMemoryFeatureFlagStore * BSGFeatureFlagStoreWithFlags(NSArray<BugsnagFeatureFlag *> *);

BSG_OBJC_DIRECT_MEMBERS
@interface BSGMemoryFeatureFlagStore ()

+ (nonnull BSGMemoryFeatureFlagStore *) fromJSON:(nonnull id)json;
+ (nonnull BSGMemoryFeatureFlagStore *)withFlags:(NSArray<BugsnagFeatureFlag *> *)flags;

@end

NS_ASSUME_NONNULL_END
