//
//  BugsnagUtility.h
//  Bugsnag
//
//  Created by Paul Zabelin on 7/1/19.
//  Copyright © 2019 Bugsnag. All rights reserved.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

void BSGDictSafeSet(NSMutableDictionary *dict, id<NSCopying> key, _Nullable id valueOrNil);
NSDictionary *BSGDictMerge(NSDictionary *source, NSDictionary *destination);

NS_ASSUME_NONNULL_END
