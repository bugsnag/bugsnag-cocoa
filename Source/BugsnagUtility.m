//
//  BugsnagUtility.m
//  Bugsnag
//
//  Created by Paul Zabelin on 7/1/19.
//  Copyright © 2019 Bugsnag. All rights reserved.
//

#import "BugsnagUtility.h"
#import "BSG_KSSafeCollections.h"

void BSGDictSafeSet(NSMutableDictionary *dict, id<NSCopying> key, id valueOrNil) {
    [dict setObject:safeValue(valueOrNil) forKey:key];
}
