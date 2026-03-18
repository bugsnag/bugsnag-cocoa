//
//  BSGDiagnosticsHandler.m
//  BugsnagMetricKitPlugin
//
//  Created by Robert Bartoszewski on 09/03/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import "BSGDiagnosticsHandler.h"

#if __has_include(<MetricKit/MetricKit.h>)

#import <Bugsnag/Bugsnag.h>
#import <Bugsnag/BugsnagConfiguration.h>
#import <Bugsnag/BugsnagMetricKitTypes.h>
#import <Bugsnag/BugsnagError.h>
#import <Bugsnag/BugsnagStackframe.h>
#import "BSGMetricKitStacktraceConverter.h"
#import <MetricKit/MetricKit.h>

@interface BSGDiagnosticsHandler ()
@property (nonatomic, strong) BugsnagConfiguration *configuration;
@end

@implementation BSGDiagnosticsHandler

- (void)configure:(BugsnagConfiguration *)configuration {
    self.configuration = configuration;
}

- (void)handleDiagnosticsPayload:(MXDiagnosticPayload *)payload API_AVAILABLE(ios(14.0), macosx(12.0)) {
    if (!payload) {
        return;
    }
    
    // Check if we have configuration
    if (!self.configuration) {
        return;
    }
    
#if !TARGET_OS_WATCH && !TARGET_OS_TV
    BugsnagMetricKitTypes *metricKitTypes = self.configuration.enabledMetricKitDiagnostics;
    
    if (!metricKitTypes || !metricKitTypes.enabled) {
        return;
    }
    
    // Process each diagnostic type
    if (metricKitTypes.crashDiagnostics && payload.crashDiagnostics) {
        for (MXCrashDiagnostic *diagnostic in payload.crashDiagnostics) {
            [self handleCrashDiagnostic:diagnostic];
        }
    }
    
    if (metricKitTypes.cpuExceptionDiagnostics && payload.cpuExceptionDiagnostics) {
        for (MXCPUExceptionDiagnostic *diagnostic in payload.cpuExceptionDiagnostics) {
            [self handleCPUExceptionDiagnostic:diagnostic];
        }
    }
    
    if (metricKitTypes.hangDiagnostics && payload.hangDiagnostics) {
        for (MXHangDiagnostic *diagnostic in payload.hangDiagnostics) {
            [self handleHangDiagnostic:diagnostic];
        }
    }
    
    if (metricKitTypes.diskWriteExceptionDiagnostics && payload.diskWriteExceptionDiagnostics) {
        for (MXDiskWriteExceptionDiagnostic *diagnostic in payload.diskWriteExceptionDiagnostics) {
            [self handleDiskWriteExceptionDiagnostic:diagnostic];
        }
    }
    
#if TARGET_OS_IOS
    if (@available(iOS 16.0, *)) {
        if (metricKitTypes.appLaunchDiagnostics && payload.appLaunchDiagnostics) {
            for (MXAppLaunchDiagnostic *diagnostic in payload.appLaunchDiagnostics) {
                [self handleAppLaunchDiagnostic:diagnostic];
            }
        }
    }
#endif
#endif
}

- (void)handleCrashDiagnostic:(MXCrashDiagnostic *)diagnostic API_AVAILABLE(ios(14.0), macosx(12.0)) {
    NSString *errorClass = [self errorClassFromCrashDiagnostic:diagnostic];
    NSString *errorMessage = [self errorMessageFromDiagnostic:diagnostic];
    NSArray<BugsnagStackframe *> *stacktrace = [BSGMetricKitStacktraceConverter stackframesFromCallStackTree:diagnostic.callStackTree];
    
    [self reportErrorWithClass:errorClass
                       message:errorMessage
                    stacktrace:stacktrace
                        source:@"metrickit"
                    diagnostic:diagnostic];
}

- (void)handleCPUExceptionDiagnostic:(MXCPUExceptionDiagnostic *)diagnostic API_AVAILABLE(ios(14.0), macosx(12.0)) {
    NSString *errorClass = @"CPUException";
    NSString *errorMessage = [self errorMessageFromDiagnostic:diagnostic];
    NSArray<BugsnagStackframe *> *stacktrace = [BSGMetricKitStacktraceConverter stackframesFromCallStackTree:diagnostic.callStackTree];
    
    [self reportErrorWithClass:errorClass
                       message:errorMessage
                    stacktrace:stacktrace
                        source:@"metrickit"
                    diagnostic:diagnostic];
}

- (void)handleHangDiagnostic:(MXHangDiagnostic *)diagnostic API_AVAILABLE(ios(14.0), macosx(12.0)) {
    NSString *errorClass = @"App Hang";
    NSString *errorMessage = [self errorMessageFromDiagnostic:diagnostic];
    NSArray<BugsnagStackframe *> *stacktrace = [BSGMetricKitStacktraceConverter stackframesFromCallStackTree:diagnostic.callStackTree];
    
    [self reportErrorWithClass:errorClass
                       message:errorMessage
                    stacktrace:stacktrace
                        source:@"metrickit"
                    diagnostic:diagnostic];
}

- (void)handleDiskWriteExceptionDiagnostic:(MXDiskWriteExceptionDiagnostic *)diagnostic API_AVAILABLE(ios(14.0), macosx(12.0)) {
    NSString *errorClass = @"DiskWriteException";
    NSString *errorMessage = [self errorMessageFromDiagnostic:diagnostic];
    NSArray<BugsnagStackframe *> *stacktrace = [BSGMetricKitStacktraceConverter stackframesFromCallStackTree:diagnostic.callStackTree];
    
    [self reportErrorWithClass:errorClass
                       message:errorMessage
                    stacktrace:stacktrace
                        source:@"metrickit"
                    diagnostic:diagnostic];
}

#if TARGET_OS_IOS
- (void)handleAppLaunchDiagnostic:(MXAppLaunchDiagnostic *)diagnostic API_AVAILABLE(ios(16.0)) {
    NSString *errorClass = @"AppLaunchFailure";
    NSString *errorMessage = [self errorMessageFromDiagnostic:diagnostic];
    NSArray<BugsnagStackframe *> *stacktrace = [BSGMetricKitStacktraceConverter stackframesFromCallStackTree:diagnostic.callStackTree];
    
    [self reportErrorWithClass:errorClass
                       message:errorMessage
                    stacktrace:stacktrace
                        source:@"metrickit"
                    diagnostic:diagnostic];
}
#endif

#pragma mark - Helper Methods

- (NSString *)errorClassFromCrashDiagnostic:(MXCrashDiagnostic *)diagnostic API_AVAILABLE(ios(14.0), macosx(12.0)) {
    // Map MetricKit exception types to Bugsnag error classes
    NSNumber *exceptionType = diagnostic.exceptionType;
    NSString *terminationReason = diagnostic.terminationReason;
    
    if (terminationReason && terminationReason.length > 0) {
        return terminationReason;
    }
    
    if (exceptionType != nil) {
        // Map common Mach exception types
        NSInteger exceptionCode = [exceptionType integerValue];
        switch (exceptionCode) {
            case 1: return @"EXC_BAD_ACCESS";
            case 2: return @"EXC_BAD_INSTRUCTION";
            case 3: return @"EXC_ARITHMETIC";
            case 4: return @"EXC_EMULATION";
            case 5: return @"EXC_SOFTWARE";
            case 6: return @"EXC_BREAKPOINT";
            case 7: return @"EXC_SYSCALL";
            case 8: return @"EXC_MACH_SYSCALL";
            case 9: return @"EXC_RPC_ALERT";
            case 10: return @"EXC_CRASH";
            case 11: return @"EXC_RESOURCE";
            case 12: return @"EXC_GUARD";
            case 13: return @"EXC_CORPSE_NOTIFY";
            default: return [NSString stringWithFormat:@"Exception Type %ld", (long)exceptionCode];
        }
    }
    
    return @"Crash";
}

- (NSString *)errorMessageFromDiagnostic:(MXDiagnostic *)diagnostic API_AVAILABLE(ios(14.0), macosx(12.0)) {
    NSMutableString *message = [NSMutableString string];
    
    // Try to extract meaningful information from the diagnostic
    if ([diagnostic respondsToSelector:@selector(exceptionReason)]) {
        id reasonObj = [(id)diagnostic performSelector:@selector(exceptionReason)];
        if (reasonObj && [reasonObj isKindOfClass:[NSString class]]) {
            NSString *reason = (NSString *)reasonObj;
            if (reason.length > 0) {
                [message appendString:reason];
            }
        }
    }
    
    if ([diagnostic respondsToSelector:@selector(signal)]) {
        id signal = [(id)diagnostic performSelector:@selector(signal)];
        if (signal) {
            if (message.length > 0) {
                [message appendString:@" - "];
            }
            [message appendFormat:@"Signal: %@", signal];
        }
    }
    
    // Add JSON payload information for additional context
    NSData *jsonData = diagnostic.JSONRepresentation;
    if (jsonData && message.length == 0) {
        NSError *error = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        if (json && !error) {
            // Extract any useful diagnostic message from JSON
            id exceptionReason = json[@"diagnosticMetaData"][@"exceptionReason"];
            if (exceptionReason && [exceptionReason isKindOfClass:[NSString class]]) {
                [message appendString:(NSString *)exceptionReason];
            }
        }
    }
    
    if (message.length == 0) {
        [message appendString:@"MetricKit diagnostic report"];
    }
    
    return [message copy];
}

- (void)reportErrorWithClass:(NSString *)errorClass
                     message:(NSString *)errorMessage
                  stacktrace:(NSArray<BugsnagStackframe *> *)stacktrace
                      source:(NSString *)source
                  diagnostic:(MXDiagnostic *)diagnostic API_AVAILABLE(ios(14.0), macosx(12.0)) {
    
    // Create a custom NSError to represent the MetricKit diagnostic
    NSError *error = [NSError errorWithDomain:@"com.bugsnag.metrickit"
                                         code:0
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: errorMessage ?: @"MetricKit diagnostic report",
                                         @"errorClass": errorClass
                                     }];
    
    // Get diagnostic JSON for metadata
    NSData *jsonData = diagnostic.JSONRepresentation;
    NSDictionary *diagnosticJson = nil;
    if (jsonData) {
        NSError *jsonError = nil;
        diagnosticJson = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError];
    }
    
    // Use public API to notify with a callback to customize the event
    [Bugsnag notifyError:error block:^BOOL(BugsnagEvent * _Nonnull event) {
        // Replace the error class with the MetricKit-specific one
        if (event.errors.count > 0) {
            BugsnagError *bugsnagError = event.errors.firstObject;
            bugsnagError.errorClass = errorClass;
            bugsnagError.errorMessage = errorMessage;
            
            // Replace stacktrace if we have one from MetricKit
            if (stacktrace && stacktrace.count > 0) {
                bugsnagError.stacktrace = stacktrace;
            }
        }
        
        // Mark as unhandled since these are system-reported issues
        event.unhandled = YES;
        event.severity = BSGSeverityError;
        
        // Add MetricKit-specific metadata
        [event addMetadata:source withKey:@"source" toSection:@"metrickit"];
        
        if (diagnosticJson) {
            [event addMetadata:diagnosticJson withKey:@"diagnosticPayload" toSection:@"metrickit"];
        }
        
        // Allow the event to be sent
        return YES;
    }];
}

@end

#endif
