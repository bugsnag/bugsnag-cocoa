//
//  BugsnagBreadcrumb+Private.h
//  Bugsnag
//
//  Created by Nick Dowell on 04/12/2020.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import "BugsnagInternals.h"

NS_ASSUME_NONNULL_BEGIN

@interface BugsnagBreadcrumb ()

- (BOOL)isValid;

- (nullable NSDictionary *)objectValue;

/// String representation of `timestamp` used to avoid unnecessary date <--> string conversions
@property (copy, nullable, nonatomic) NSString *timestampString;

@end

NS_ASSUME_NONNULL_END
