//
//  BSGDiagnosticsHandler.h
//  BugsnagMetricKitPlugin
//
//  Created by Robert Bartoszewski on 09/03/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<MetricKit/MetricKit.h>)

#import <MetricKit/MetricKit.h>

@class BugsnagConfiguration;

NS_ASSUME_NONNULL_BEGIN

@interface BSGDiagnosticsHandler: NSObject

- (void)configure:(BugsnagConfiguration *)configuration;

- (void)handleDiagnosticsPayload:(MXDiagnosticPayload *)payload API_AVAILABLE(ios(14.0), macosx(12.0));

@end

NS_ASSUME_NONNULL_END

#endif
