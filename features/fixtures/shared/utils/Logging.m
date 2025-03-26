//
//  Logging.m
//  iOSTestApp
//
//  Created by Karl Stenerud on 02.11.23.
//  Copyright © 2023 Bugsnag. All rights reserved.
//

#import "Logging.h"

#if TARGET_OS_IPHONE
extern void i_kslog_logCBasic(const char *fmt, ...) __printflike(1, 2);
#endif

void logInternal(const char* level, NSString *format, va_list args) {
    NSString *formatted = [[NSString alloc] initWithFormat:format arguments:args];
    NSString *fullMessage = [NSString stringWithFormat:@"bugsnagci %s: %@", level, formatted];

    NSLog(@"%@", fullMessage);
    // TODO: Restore logging for macOS
#if TARGET_OS_IPHONE
    i_kslog_logCBasic("%s",
                          [[NSString stringWithFormat:@"%@ %@",
                            [NSDate date], fullMessage]
                           cStringUsingEncoding:NSUTF8StringEncoding]);
#endif
}

void logDebugObjC(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    logInternal("debug", format, args);
    va_end(args);
}

void logInfoObjC(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    logInternal("info", format, args);
    va_end(args);
}

void logWarnObjC(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    logInternal("warn", format, args);
    va_end(args);
}

void logErrorObjC(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    logInternal("error", format, args);
    va_end(args);
}
