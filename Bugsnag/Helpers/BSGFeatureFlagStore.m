//
//  BSGFeatureFlagStore.m
//  Bugsnag
//
//  Created by Nick Dowell on 11/11/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "BSGFeatureFlagStore.h"

#import "BSGKeys.h"
#import "BugsnagFeatureFlag.h"

static void internalAddFeatureFlag(BSGFeatureFlagStore *store, BugsnagFeatureFlag *flag) {
    [store removeObject:flag];
    [store addObject:flag];
}

void BSGFeatureFlagStoreAddFeatureFlag(BSGFeatureFlagStore *store, NSString *name, NSString *_Nullable variant) {
    internalAddFeatureFlag(store, [BugsnagFeatureFlag flagWithName:name variant:variant]);
}

void BSGFeatureFlagStoreAddFeatureFlags(BSGFeatureFlagStore *store, NSArray<BugsnagFeatureFlag *> *featureFlags) {
    for (BugsnagFeatureFlag *featureFlag in featureFlags) {
        internalAddFeatureFlag(store, featureFlag);
    }
}

void BSGFeatureFlagStoreClear(BSGFeatureFlagStore *store, NSString *_Nullable name) {
    if (name) {
        [store removeObject:[BugsnagFeatureFlag flagWithName:(NSString * _Nonnull)name]];
    } else {
        [store removeAllObjects];
    }
}

NSArray<NSDictionary *> * BSGFeatureFlagStoreToJSON(BSGFeatureFlagStore *store) {
    NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
    for (BugsnagFeatureFlag *flag in store) {
        if (flag.variant) {
            [result addObject:@{BSGKeyFeatureFlag: flag.name, BSGKeyVariant: (NSString * _Nonnull)flag.variant}];
        } else {
            [result addObject:@{BSGKeyFeatureFlag: flag.name}];
        }
    }
    return result;
}

BSGFeatureFlagStore * BSGFeatureFlagStoreFromJSON(id json) {
    BSGFeatureFlagStore *store = [NSMutableArray array];
    if ([json isKindOfClass:[NSArray class]]) {
        for (id item in json) {
            if ([item isKindOfClass:[NSDictionary class]]) {
                NSString *featureFlag = item[BSGKeyFeatureFlag];
                if ([featureFlag isKindOfClass:[NSString class]]) {
                    id variant = item[BSGKeyVariant];
                    if (![variant isKindOfClass:[NSString class]]) {
                        variant = nil;
                    }
                    [store addObject:[BugsnagFeatureFlag flagWithName:featureFlag variant:variant]];
                }
            }
        }
    }
    return store;
}
