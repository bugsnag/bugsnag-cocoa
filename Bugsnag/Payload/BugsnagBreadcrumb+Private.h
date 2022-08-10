//
//  BugsnagBreadcrumb+Private.h
//  Bugsnag
//
//  Created by Nick Dowell on 04/12/2020.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import <Bugsnag/BugsnagBreadcrumb.h>
#import <Bugsnag/BugsnagDefines.h>

NS_ASSUME_NONNULL_BEGIN

@interface BugsnagBreadcrumb ()

+ (nullable instancetype)breadcrumbFromDict:(NSDictionary *)dict;

- (BOOL)isValid;

- (nullable NSDictionary *)objectValue;

/// String representation of `timestamp` used to avoid unnecessary date <--> string conversions
@property (copy, nullable, nonatomic) NSString *timestampString;

@end

BUGSNAG_EXTERN NSString * BSGBreadcrumbTypeValue(BSGBreadcrumbType type);
BUGSNAG_EXTERN BSGBreadcrumbType BSGBreadcrumbTypeFromString(NSString * _Nullable value);

NS_ASSUME_NONNULL_END
