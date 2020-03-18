//
//  BugsnagMetadataInternal.h
//  Bugsnag
//
//  Created by Jamie Lynch on 28/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#ifndef BugsnagMetadataInternal_h
#define BugsnagMetadataInternal_h

#import "BugsnagMetadata.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^BugsnagMetadataCallback)(BugsnagMetadata *metadata);

@interface BugsnagMetadata ()
@property(atomic, strong) NSMutableDictionary *dictionary;
@property NSMutableSet *_Nullable observers;

- (NSDictionary *)toDictionary;
- (id)deepCopy;
- (void)addObserver:(BugsnagMetadataCallback)block;
@end

NS_ASSUME_NONNULL_END

#endif /* BugsnagMetadataInternal_h */
