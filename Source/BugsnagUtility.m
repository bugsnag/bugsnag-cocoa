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

NSDictionary *BSGDictMerge(NSDictionary *source, NSDictionary *destination) {
    if ([destination count] == 0) {
        return source;
    }
    if ([source count] == 0) {
        return destination;
    }

    NSMutableDictionary *dict = [destination mutableCopy];
    for (id key in [source allKeys]) {
        id srcEntry = source[key];
        id dstEntry = destination[key];
        if ([dstEntry isKindOfClass:[NSDictionary class]] &&
            [srcEntry isKindOfClass:[NSDictionary class]]) {
            srcEntry = BSGDictMerge(srcEntry, dstEntry);
        }
        dict[key] = srcEntry;
    }
    return dict;

    return source;
}
