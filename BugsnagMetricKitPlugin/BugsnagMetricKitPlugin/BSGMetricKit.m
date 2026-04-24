//
//  BSGMetricKit.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 09/03/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import "BSGMetricKit.h"

#if __has_include(<MetricKit/MetricKit.h>)

#import "Metrics/BSGMetricsHandler.h"
#import "Diagnostics/BSGDiagnosticsHandler.h"
#import <MetricKit/MetricKit.h>

@class BugsnagConfiguration;

@interface BSGMetricKit () <MXMetricManagerSubscriber>
@property (nonatomic, strong) BSGMetricsHandler *metricsHandler;
@property (nonatomic, strong) BSGDiagnosticsHandler *diagnosticsHandler;
@property (nonatomic, assign) BOOL isInstalled;
@end

@implementation BSGMetricKit

+ (instancetype)sharedInstance {
    static BSGMetricKit *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if ((self = [super init])) {
        _metricsHandler = [[BSGMetricsHandler alloc] init];
        _diagnosticsHandler = [[BSGDiagnosticsHandler alloc] init];
        _isInstalled = NO;
    }
    return self;
}

- (void)configure:(id)configuration {
    [self.diagnosticsHandler configure:configuration];
}

- (void)installMetricKit {
    if (self.isInstalled) {
        return;
    }
    
    if (@available(iOS 13.0, macOS 12.0, *)) {
        MXMetricManager *metricManager = [MXMetricManager sharedManager];
        [metricManager addSubscriber:self];
        self.isInstalled = YES;
    }
}

- (void)uninstallMetricKit {
    if (!self.isInstalled) {
        return;
    }
    
    if (@available(iOS 13.0, macOS 12.0, *)) {
        MXMetricManager *metricManager = [MXMetricManager sharedManager];
        [metricManager removeSubscriber:self];
        self.isInstalled = NO;
    }
}

#pragma mark - MXMetricManagerSubscriber

- (void)didReceiveMetricPayloads:(NSArray<MXMetricPayload *> *)payloads API_AVAILABLE(ios(13.0), macosx(12.0)) {
    for (MXMetricPayload *payload in payloads) {
        [self.metricsHandler handleMetricsPayload:payload];
    }
}

- (void)didReceiveDiagnosticPayloads:(NSArray<MXDiagnosticPayload *> *)payloads API_AVAILABLE(ios(14.0), macosx(12.0)) {
    for (MXDiagnosticPayload *payload in payloads) {
        [self.diagnosticsHandler handleDiagnosticsPayload:payload];
    }
}

@end

#endif
