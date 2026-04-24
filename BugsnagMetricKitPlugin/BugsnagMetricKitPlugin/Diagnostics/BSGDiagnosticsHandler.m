//
//  BSGDiagnosticsHandler.m
//  BugsnagMetricKitPlugin
//
//  Created by Robert Bartoszewski on 09/03/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import "BSGDiagnosticsHandler.h"

#if __has_include(<MetricKit/MetricKit.h>)

#import "BSGMetricKitStacktraceConverter.h"
#import "../BugsnagFromBugsnagMetricKitPlugin.h"
#import <MetricKit/MetricKit.h>
#import <mach/exception_types.h>
#import <signal.h>

#pragma mark - Exception Type / Signal Mapping

static NSString *BSGExceptionTypeName(NSNumber * _Nullable exceptionType) {
    if (!exceptionType) return nil;
    switch (exceptionType.integerValue) {
        case EXC_BAD_ACCESS:      return @"EXC_BAD_ACCESS";
        case EXC_BAD_INSTRUCTION: return @"EXC_BAD_INSTRUCTION";
        case EXC_ARITHMETIC:      return @"EXC_ARITHMETIC";
        case EXC_EMULATION:       return @"EXC_EMULATION";
        case EXC_SOFTWARE:        return @"EXC_SOFTWARE";
        case EXC_BREAKPOINT:      return @"EXC_BREAKPOINT";
        case EXC_SYSCALL:         return @"EXC_SYSCALL";
        case EXC_MACH_SYSCALL:    return @"EXC_MACH_SYSCALL";
        case EXC_RPC_ALERT:       return @"EXC_RPC_ALERT";
        case EXC_CRASH:           return @"EXC_CRASH";
        case EXC_RESOURCE:        return @"EXC_RESOURCE";
        case EXC_GUARD:           return @"EXC_GUARD";
        case EXC_CORPSE_NOTIFY:   return @"EXC_CORPSE_NOTIFY";
        default: return [NSString stringWithFormat:@"EXC_%@", exceptionType];
    }
}

static NSString *BSGSignalName(NSNumber * _Nullable signal) {
    if (!signal) return nil;
    switch (signal.integerValue) {
        case SIGHUP:  return @"SIGHUP";
        case SIGINT:  return @"SIGINT";
        case SIGQUIT: return @"SIGQUIT";
        case SIGILL:  return @"SIGILL";
        case SIGTRAP: return @"SIGTRAP";
        case SIGABRT: return @"SIGABRT";
        case SIGEMT:  return @"SIGEMT";
        case SIGFPE:  return @"SIGFPE";
        case SIGKILL: return @"SIGKILL";
        case SIGBUS:  return @"SIGBUS";
        case SIGSEGV: return @"SIGSEGV";
        case SIGSYS:  return @"SIGSYS";
        case SIGPIPE: return @"SIGPIPE";
        case SIGALRM: return @"SIGALRM";
        case SIGTERM: return @"SIGTERM";
        default: return [NSString stringWithFormat:@"SIG_%@", signal];
    }
}

#pragma mark - Metadata helper

/**
 * Calls [event addMetadata:value withKey:key toSection:section] via NSInvocation
 * to avoid compile-time dependency on Bugsnag headers.
 */
static void BSGAddMetadata(id event, NSString *section, NSString *key, id _Nullable value) {
    if (!value) return;
    SEL sel = NSSelectorFromString(@"addMetadata:withKey:toSection:");
    if (![event respondsToSelector:sel]) return;
    NSMethodSignature *sig = [event methodSignatureForSelector:sel];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.selector = sel;
    inv.target = event;
    [inv setArgument:&value atIndex:2];
    [inv setArgument:&key atIndex:3];
    [inv setArgument:&section atIndex:4];
    [inv invoke];
}

/**
 * Extracts the diagnosticMetaData dictionary from a diagnostic's JSON representation.
 */
static NSDictionary * _Nullable BSGDiagnosticMetaData(MXDiagnostic *diagnostic) API_AVAILABLE(ios(14.0), macosx(12.0)) {
    NSData *jsonData = diagnostic.JSONRepresentation;
    if (!jsonData) return nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    if (![json isKindOfClass:[NSDictionary class]]) return nil;
    NSDictionary *meta = json[@"diagnosticMetaData"];
    return [meta isKindOfClass:[NSDictionary class]] ? meta : nil;
}

#pragma mark - Measurement helpers

static double BSGSecondsFromDuration(NSMeasurement<NSUnitDuration *> *measurement) {
    return [measurement measurementByConvertingToUnit:NSUnitDuration.seconds].doubleValue;
}

static double BSGBytesFromStorage(NSMeasurement<NSUnitInformationStorage *> *measurement) {
    return [measurement measurementByConvertingToUnit:NSUnitInformationStorage.bytes].doubleValue;
}

#pragma mark - BSGDiagnosticsHandler

@interface BSGDiagnosticsHandler ()
@property (nonatomic, strong) id configuration;
@end

@implementation BSGDiagnosticsHandler

- (void)configure:(id)configuration {
    self.configuration = configuration;
}

- (void)handleDiagnosticsPayload:(MXDiagnosticPayload *)payload API_AVAILABLE(ios(14.0), macosx(12.0)) {
    if (!payload || !self.configuration) {
        return;
    }

#if !TARGET_OS_WATCH && !TARGET_OS_TV
    id metricKitTypes = [self.configuration valueForKey:@"enabledMetricKitDiagnostics"];
    if (!metricKitTypes || ![[metricKitTypes valueForKey:@"enabled"] boolValue]) {
        return;
    }

    if ([[metricKitTypes valueForKey:@"crashDiagnostics"] boolValue] && payload.crashDiagnostics) {
        for (MXCrashDiagnostic *diagnostic in payload.crashDiagnostics) {
            [self handleCrashDiagnostic:diagnostic timestamp:payload.timeStampEnd];
        }
    }

    if ([[metricKitTypes valueForKey:@"cpuExceptionDiagnostics"] boolValue] && payload.cpuExceptionDiagnostics) {
        for (MXCPUExceptionDiagnostic *diagnostic in payload.cpuExceptionDiagnostics) {
            [self handleCPUExceptionDiagnostic:diagnostic timestamp:payload.timeStampEnd];
        }
    }

    if ([[metricKitTypes valueForKey:@"diskWriteExceptionDiagnostics"] boolValue] && payload.diskWriteExceptionDiagnostics) {
        for (MXDiskWriteExceptionDiagnostic *diagnostic in payload.diskWriteExceptionDiagnostics) {
            [self handleDiskWriteExceptionDiagnostic:diagnostic timestamp:payload.timeStampEnd];
        }
    }

    if ([[metricKitTypes valueForKey:@"hangDiagnostics"] boolValue] && payload.hangDiagnostics) {
        for (MXHangDiagnostic *diagnostic in payload.hangDiagnostics) {
            [self handleHangDiagnostic:diagnostic timestamp:payload.timeStampEnd];
        }
    }

#if TARGET_OS_IOS
    if (@available(iOS 16.0, *)) {
        if ([[metricKitTypes valueForKey:@"appLaunchDiagnostics"] boolValue] && payload.appLaunchDiagnostics) {
            for (MXAppLaunchDiagnostic *diagnostic in payload.appLaunchDiagnostics) {
                [self handleAppLaunchDiagnostic:diagnostic timestamp:payload.timeStampEnd];
            }
        }
    }
#endif
#endif
}

#pragma mark - Crash Diagnostic

- (void)handleCrashDiagnostic:(MXCrashDiagnostic *)diagnostic
                     timestamp:(NSDate *)timestamp API_AVAILABLE(ios(14.0), macosx(12.0)) {

    // --- errorClass: map exceptionType to Mach exception name, fall back to generic ---
    NSString *excName = BSGExceptionTypeName(diagnostic.exceptionType);
    NSString *errorClass = excName ?: @"Crash";

    // --- errorMessage: build from signal / exceptionCode / terminationReason ---
    NSMutableString *message = [NSMutableString string];
    if (diagnostic.terminationReason.length > 0) {
        [message appendString:diagnostic.terminationReason];
    }
    if (diagnostic.signal) {
        NSString *sigName = BSGSignalName(diagnostic.signal);
        if (message.length > 0) [message appendString:@", "];
        [message appendFormat:@"Signal %@ (%@)", diagnostic.signal, sigName ?: @"?"];
    }
    if (diagnostic.exceptionCode) {
        if (message.length > 0) [message appendString:@", "];
        [message appendFormat:@"Exception Code %@", diagnostic.exceptionCode];
    }
    if (@available(iOS 17.0, macOS 14.0, *)) {
        if (diagnostic.exceptionReason) {
            if (message.length > 0) [message appendString:@" — "];
            [message appendString:diagnostic.exceptionReason.composedMessage];
        }
    }
    if (message.length == 0) {
        [message appendString:@"MetricKit crash diagnostic"];
    }

    NSArray<id> *stacktrace = [BSGMetricKitStacktraceConverter stackframesFromCallStackTree:diagnostic.callStackTree];

    // --- Collect rich metadata ---
    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    metadata[@"diagnosticType"] = @"crash";
    if (diagnostic.exceptionType)   metadata[@"exceptionType"]   = diagnostic.exceptionType;
    if (diagnostic.exceptionCode)   metadata[@"exceptionCode"]   = diagnostic.exceptionCode;
    if (diagnostic.signal)          metadata[@"signal"]          = diagnostic.signal;
    if (diagnostic.terminationReason) metadata[@"terminationReason"] = diagnostic.terminationReason;
    if (diagnostic.virtualMemoryRegionInfo) metadata[@"virtualMemoryRegionInfo"] = diagnostic.virtualMemoryRegionInfo;

    [self notifyWithErrorClass:errorClass
                  errorMessage:message
                    stacktrace:stacktrace
                     timestamp:timestamp
                       context:@"MetricKit Crash"
                    diagnostic:diagnostic
                      metadata:metadata];
}

#pragma mark - CPU Exception Diagnostic

- (void)handleCPUExceptionDiagnostic:(MXCPUExceptionDiagnostic *)diagnostic
                            timestamp:(NSDate *)timestamp API_AVAILABLE(ios(14.0), macosx(12.0)) {

    double cpuTime = BSGSecondsFromDuration(diagnostic.totalCPUTime);
    double sampledTime = BSGSecondsFromDuration(diagnostic.totalSampledTime);

    NSString *message = [NSString stringWithFormat:@"Excessive CPU usage: %.2fs CPU time over %.2fs sampled", cpuTime, sampledTime];

    NSArray<id> *stacktrace = [BSGMetricKitStacktraceConverter stackframesFromCallStackTree:diagnostic.callStackTree];

    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    metadata[@"diagnosticType"]      = @"cpuException";
    metadata[@"totalCPUTimeSeconds"] = @(cpuTime);
    metadata[@"totalSampledTimeSeconds"] = @(sampledTime);

    [self notifyWithErrorClass:@"CPUException"
                  errorMessage:message
                    stacktrace:stacktrace
                     timestamp:timestamp
                       context:@"MetricKit CPU Exception"
                    diagnostic:diagnostic
                      metadata:metadata];
}

#pragma mark - Disk Write Exception Diagnostic

- (void)handleDiskWriteExceptionDiagnostic:(MXDiskWriteExceptionDiagnostic *)diagnostic
                                  timestamp:(NSDate *)timestamp API_AVAILABLE(ios(14.0), macosx(12.0)) {

    double writesBytes = BSGBytesFromStorage(diagnostic.totalWritesCaused);
    NSString *message = [NSString stringWithFormat:@"Excessive disk writes: %.0f bytes", writesBytes];

    NSArray<id> *stacktrace = [BSGMetricKitStacktraceConverter stackframesFromCallStackTree:diagnostic.callStackTree];

    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    metadata[@"diagnosticType"]        = @"diskWriteException";
    metadata[@"totalWritesCausedBytes"] = @(writesBytes);

    [self notifyWithErrorClass:@"DiskWriteException"
                  errorMessage:message
                    stacktrace:stacktrace
                     timestamp:timestamp
                       context:@"MetricKit Disk Write Exception"
                    diagnostic:diagnostic
                      metadata:metadata];
}

#pragma mark - Hang Diagnostic

- (void)handleHangDiagnostic:(MXHangDiagnostic *)diagnostic
                    timestamp:(NSDate *)timestamp API_AVAILABLE(ios(14.0), macosx(12.0)) {

    double hangSec = BSGSecondsFromDuration(diagnostic.hangDuration);
    NSString *message = [NSString stringWithFormat:@"Application hang: %.2fs", hangSec];

    NSArray<id> *stacktrace = [BSGMetricKitStacktraceConverter stackframesFromCallStackTree:diagnostic.callStackTree];

    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    metadata[@"diagnosticType"]      = @"hang";
    metadata[@"hangDurationSeconds"] = @(hangSec);

    [self notifyWithErrorClass:@"App Hang"
                  errorMessage:message
                    stacktrace:stacktrace
                     timestamp:timestamp
                       context:@"MetricKit Hang"
                    diagnostic:diagnostic
                      metadata:metadata];
}

#pragma mark - App Launch Diagnostic (iOS 16+ only)

#if TARGET_OS_IOS
- (void)handleAppLaunchDiagnostic:(MXAppLaunchDiagnostic *)diagnostic
                         timestamp:(NSDate *)timestamp API_AVAILABLE(ios(16.0)) {

    double launchSec = BSGSecondsFromDuration(diagnostic.launchDuration);
    NSString *message = [NSString stringWithFormat:@"Slow app launch: %.2fs", launchSec];

    NSArray<id> *stacktrace = [BSGMetricKitStacktraceConverter stackframesFromCallStackTree:diagnostic.callStackTree];

    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    metadata[@"diagnosticType"]       = @"appLaunch";
    metadata[@"launchDurationSeconds"] = @(launchSec);

    [self notifyWithErrorClass:@"AppLaunchFailure"
                  errorMessage:message
                    stacktrace:stacktrace
                     timestamp:timestamp
                       context:@"MetricKit App Launch"
                    diagnostic:diagnostic
                      metadata:metadata];
}
#endif

#pragma mark - Shared notification path

- (void)notifyWithErrorClass:(NSString *)errorClass
                errorMessage:(NSString *)errorMessage
                  stacktrace:(NSArray<id> *)stacktrace
                   timestamp:(NSDate * _Nullable)timestamp
                     context:(NSString *)context
                  diagnostic:(MXDiagnostic *)diagnostic
                    metadata:(NSMutableDictionary *)metadata API_AVAILABLE(ios(14.0), macosx(12.0)) {

    BugsnagFromBugsnagMetricKitPlugin *bugsnag = [BugsnagFromBugsnagMetricKitPlugin sharedInstance];
    if (!bugsnag) {
        return;
    }

    // Enrich metadata with diagnosticMetaData from the diagnostic JSON
    NSDictionary *diagMeta = BSGDiagnosticMetaData(diagnostic);

    // Copy the timestamp so the block can reference it
    NSDate *eventTimestamp = timestamp;
    NSDate *reportedTime = [NSDate date];

    [bugsnag notifyPlainEvent:errorClass
                 errorMessage:errorMessage
                   stacktrace:stacktrace
                    timestamp:eventTimestamp
                        block:^BOOL(id event) {

        // --- Set context ---
        [event setValue:context forKey:@"context"];

        // --- Metadata: metrickit section ---
        BSGAddMetadata(event, @"metrickit", @"reportingType", @"delayed");
        for (NSString *key in metadata) {
            BSGAddMetadata(event, @"metrickit", key, metadata[key]);
        }

        // Add timestamp metadata
        if (eventTimestamp) {
            NSISO8601DateFormatter *fmt = [[NSISO8601DateFormatter alloc] init];
            BSGAddMetadata(event, @"metrickit", @"eventOccurredAt", [fmt stringFromDate:eventTimestamp]);
            BSGAddMetadata(event, @"metrickit", @"eventReportedAt", [fmt stringFromDate:reportedTime]);
            BSGAddMetadata(event, @"metrickit", @"deliveryDelaySeconds",
                           @([reportedTime timeIntervalSinceDate:eventTimestamp]));
        }

        // Add diagnosticMetaData fields
        if (diagMeta) {
            NSArray *knownKeys = @[@"regionFormat", @"lowPowerModeEnabled", @"platformArchitecture",
                                   @"deviceType", @"osVersion", @"bundleIdentifier",
                                   @"appVersion", @"appBuildVersion", @"pid", @"isTestFlightApp"];
            for (NSString *key in knownKeys) {
                if (diagMeta[key]) {
                    BSGAddMetadata(event, @"metrickit", key, diagMeta[key]);
                }
            }
        }

        return YES;
    }];
}

@end

#endif
