//
//  BugsnagHandledState.m
//  Bugsnag
//
//  Created by Jamie Lynch on 21/09/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import "BugsnagHandledState.h"

@implementation BugsnagHandledState

+ (instancetype)handledStateWithSeverityReason:(SeverityReasonType)severityReason {
    return [self handledStateWithSeverityReason:severityReason
                                       severity:BSGSeverityWarning];
}

+ (instancetype)handledStateWithSeverityReason:(SeverityReasonType)severityReason
                                      severity:(BSGSeverity)severity {
    BOOL unhandled = NO;
    
    switch (severityReason) {
        case UnhandledException:
            severity = BSGSeverityError;
            unhandled = YES;
            break;
        case Signal:
            severity = BSGSeverityError;
            unhandled = YES;
            break;
        case HandledError:
            severity = BSGSeverityWarning;
            break;
        case HandledException:
            severity = BSGSeverityWarning;
            break;
        case UserSpecifiedSeverity:
            break;
        default:
            [NSException raise:@"UnknownSeverityReason"
                        format:@"Severity reason not supported"];
    }
    
    return [[BugsnagHandledState alloc] initWithSeverityReason:severityReason
                                                      severity:severity
                                                     unhandled:unhandled];
}

- (instancetype)initWithSeverityReason:(SeverityReasonType)severityReason
                              severity:(BSGSeverity)severity
                             unhandled:(BOOL)unhandled {
    if (self = [super init]) {
        _severityReasonType = severityReason;
        _currentSeverity = severity;
        _originalSeverity = severity;
        _unhandled = unhandled;
    }
    return self;
}

- (SeverityReasonType)calculateSeverityReasonType {
    return _originalSeverity == _currentSeverity ?
    _severityReasonType : UserCallbackSetSeverity;
}

+ (NSString *)stringFromSeverityReason:(SeverityReasonType)severityReason {
    switch (severityReason) {
        case UnhandledException:
            return @"unhandledException";
        case Signal:
            return @"signal";
        case HandledError:
            return @"handledError";
        case HandledException:
            return @"handledException";
        case UserSpecifiedSeverity:
            return @"userSpecifiedSeverity";
        case UserCallbackSetSeverity:
            return @"userCallbackSetSeverity";
        default:
            [NSException raise:@"UnknownSeverityReason"
                        format:@"Severity reason not supported"];
    }
}

@end

