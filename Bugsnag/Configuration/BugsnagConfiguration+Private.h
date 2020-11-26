//
//  BugsnagConfiguration+Private.h
//  Bugsnag
//
//  Created by Nick Dowell on 26/11/2020.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import <Bugsnag/BugsnagConfiguration.h>

NS_ASSUME_NONNULL_BEGIN

@interface BugsnagConfiguration ()

/// Throws an NSInvalidArgumentException if the API key is empty or missing.
/// Logs a warning message if the API key is not in the expected format.
- (void)validate;

@end

NS_ASSUME_NONNULL_END
