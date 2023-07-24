//
//  BSGFilesystem.h
//  Bugsnag
//
//  Created by Karl Stenerud on 27.06.23.
//  Copyright © 2023 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BSGFilesystem : NSObject

/**
 * Builds all necessary intervening directories to make the given directory path exist.
 */
+ (nullable NSError *)ensurePathExists:(NSString *)path;

/**
 * Deletes the given path and recreates it (as a directory).
 */
+ (nullable NSError *)rebuildPath:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
