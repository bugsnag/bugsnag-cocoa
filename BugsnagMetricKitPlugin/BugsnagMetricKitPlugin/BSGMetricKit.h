//
//  BSGMetricKit.h
//  Bugsnag
//
//  Created by Robert Bartoszewski on 09/03/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<MetricKit/MetricKit.h>)

@class BugsnagConfiguration;

NS_ASSUME_NONNULL_BEGIN

@interface BSGMetricKit: NSObject

+ (instancetype)sharedInstance;

- (void)configure:(BugsnagConfiguration *)configuration;

- (void)installMetricKit;

- (void)uninstallMetricKit;

@end

NS_ASSUME_NONNULL_END

#endif
