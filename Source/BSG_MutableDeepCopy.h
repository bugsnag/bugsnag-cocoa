//
//  NSObject+BSG_MutableDeepCopy.h
//  Bugsnag
//
//  Created by Robin Macharg on 31/03/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MutableDeepCopying <NSObject>
-(id) mutableDeepCopy;
@end
@interface NSDictionary (MutableDeepCopy) <MutableDeepCopying>
@end
@interface NSArray (MutableDeepCopy) <MutableDeepCopying>
@end

NS_ASSUME_NONNULL_END
