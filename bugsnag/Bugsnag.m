//
//  Bugsnag.m
//  Bugsnag
//
//  Created by Simon Maynard on 8/28/13.
//  Copyright (c) 2013 Simon Maynard. All rights reserved.
//

#import <mach/mach.h>

#include "TargetConditionals.h"
#import "Bugsnag.h"
#import "BugsnagLogger.h"

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
    // iOS Simulator or iOS device
    #import "BugsnagIosNotifier.h"
    static NSString *notiferClass = @"BugsnagIosNotifier";
#elif TARGET_OS_MAC
    // Other kinds of Mac OS
#else
    // Unsupported platform
    #import "BugsnagNotifier.h"
    static NSString *notiferClass = @"BugsnagNotifier";
#endif

static BugsnagNotifier *notifier = nil;

/*
 TODO:
 - We should report low memory kills and I dont think we do right now.
 */

int signals_count = 9;
int signals[] = {
	SIGABRT,
	SIGBUS,
	SIGFPE,
	SIGILL,
	SIGSEGV,
    EXC_BAD_ACCESS,
    EXC_ARITHMETIC,
    EXC_BAD_INSTRUCTION,
    SIGTRAP,
};

void remove_handlers(void);
void handle_signal(int);
void handle_exception(NSException *);

void remove_handlers() {
    for (NSUInteger i = 0; i < signals_count; i++) {
        int signalType = signals[i];
        signal(signalType, NULL);
    }
    NSSetUncaughtExceptionHandler(NULL);
}

// Handles a raised signal
void handle_signal(int signalReceived) {
    if (notifier) {
        [notifier notifySignal:signalReceived];
        
        // We dont want to be double notified
        remove_handlers();
    }
    
    //Propagate the signal back up to take the app down
    raise(signalReceived);
}

// Handles an uncaught exception
void handle_exception(NSException *exception) {
    if (notifier) {
        // We dont want to be double notified
        remove_handlers();
        [notifier notifyUncaughtException:exception];
    }
}

@interface Bugsnag ()
+ (BugsnagNotifier*)notifier;
+ (BOOL) bugsnagStarted;
@end

@implementation Bugsnag

+ (void)startBugsnagWithApiKey:(NSString*)apiKey {
    notifier = [[NSClassFromString(notiferClass) alloc] init];
    notifier.configuration.apiKey = apiKey;
    
    [notifier sendSavedEvents];
    
    // Register the notifier to receive exceptions and signals
    NSSetUncaughtExceptionHandler(&handle_exception);
    
    for (NSUInteger i = 0; i < signals_count; i++) {
        int signalType = signals[i];
        if (signal(signalType, handle_signal) != 0) {
            BugsnagLog(@"Unable to register signal handler for %s", strsignal(signalType));
        }
    }
}

+ (BugsnagConfiguration*)configuration {
    if([self bugsnagStarted]) {
        return notifier.configuration;
    }
    return nil;
}

+ (BugsnagNotifier*)notifier {
    return notifier;
}

+ (void) notify:(NSException *)exception {
    [notifier notifyException:exception withData:nil];
}

+ (void) notify:(NSException *)exception withData:(NSDictionary*)metaData {
    [notifier notifyException:exception withData:metaData];
}

+ (void) setUserAttribute:(NSString*)attributeName withValue:(id)value {
    [self addAttribute:attributeName withValue:value toTabWithName:@"user"];
}

+ (void) clearUser {
    [self clearTabWithName:@"user"];
}

+ (void) addAttribute:(NSString*)attributeName withValue:(id)value toTabWithName:(NSString*)tabName {
    if([self bugsnagStarted]) {
        [notifier.configuration.metaData addAttribute:attributeName withValue:value toTabWithName:tabName];
    }
}

+ (void) clearTabWithName:(NSString*)tabName {
    if([self bugsnagStarted]) {
        [notifier.configuration.metaData clearTab:tabName];
    }
}

+ (BOOL) bugsnagStarted {
    if (notifier == nil) {
        BugsnagLog(@"Ensure you have started Bugsnag with startWithApiKey: before calling any other Bugsnag functions.");

        return false;
    }
    return true;
}

@end