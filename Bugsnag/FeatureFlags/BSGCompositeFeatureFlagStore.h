//
//  BSGCompositeFeatureFlagStore.h
//  Bugsnag
//
//  Created by Robert B on 16/12/2024.
//  Copyright © 2024 Bugsnag Inc. All rights reserved.
//

#import "BugsnagInternals.h"
#import "BSGDefines.h"
#import "BSGFeatureFlagStore.h"

NS_ASSUME_NONNULL_BEGIN


BSG_OBJC_DIRECT_MEMBERS
@interface BSGCompositeFeatureFlagStore ()

@property(nonatomic,nonnull,readonly) NSArray<BugsnagFeatureFlag *> *persistedFlags;

+ (instancetype)storeWithMemoryStore:(id<BSGFeatureFlagStore, NSCopying>)memoryStore
                     persistentStore:(id<BSGFeatureFlagStore>)persistenStore
                         atomicStore:(id<BSGFeatureFlagStore>)atomicStore;

- (void)synchronizeFlagsWithMemoryStore;

@end

NS_ASSUME_NONNULL_END
