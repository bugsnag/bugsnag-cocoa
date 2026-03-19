//
//  BugsnagSymbolicator.h
//  Bugsnag
//
//  Created by Robert Bartoszewski on 19/03/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BugsnagStackframe;

NS_ASSUME_NONNULL_BEGIN

/**
 * Utilities for symbolication of stack frames.
 */
@interface BugsnagSymbolicator : NSObject

/**
 * Symbolicate an array of stack frames.
 *
 * This method attempts to populate symbolication information (method name, file, line number)
 * for stack frames that have a frameAddress but are missing other details.
 *
 * @param stackframes Array of BugsnagStackframe objects to symbolicate
 */
+ (void)symbolicateStackframes:(NSArray<BugsnagStackframe *> *)stackframes;

@end

NS_ASSUME_NONNULL_END
