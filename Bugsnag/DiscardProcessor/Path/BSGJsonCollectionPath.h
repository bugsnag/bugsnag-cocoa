//
//  BSGJsonCollectionPath.h
//  Bugsnag
//
//  Created by Robert Bartoszewski on 20/11/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BSGJsonCollectionPath : NSObject

/**
  * Tokenize the given `path` string and return the resulting structure
  */
+ (instancetype)pathFromString:(NSString *)path;

/**
  * The identity path ("$") is special as it returns all values of its input
  * json.
  */
+ (instancetype)identityPath;

/**
  * Extract the elements that this path requests from the given `json` and return
  * them in an `NSArray`.
  */
- (NSArray<id> *)extractFromJSON:(NSDictionary<NSString *, id> *)json;

@end

NS_ASSUME_NONNULL_END
