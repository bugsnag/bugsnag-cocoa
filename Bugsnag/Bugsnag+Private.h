//
//  Bugsnag+Private.h
//  Bugsnag
//
//  Created by Nick Dowell on 04/12/2020.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import <Bugsnag/Bugsnag.h>

NS_ASSUME_NONNULL_BEGIN

@interface Bugsnag ()

#pragma mark Methods

+ (void)purge;

+ (void)removeOnBreadcrumbBlock:(BugsnagOnBreadcrumbBlock)block;

@end

NS_ASSUME_NONNULL_END
