//
//  Bugsnag.m
//  Bugsnag
//
//  Created by Simon Maynard on 8/28/13.
//  Copyright (c) 2013 Simon Maynard. All rights reserved.
//

#import <mach/mach.h>

#import "Bugsnag.h"
#import "BugsnagLogger.h"
#import "BugsnagNotifier.h"

static BugsnagNotifier *notifier = nil;

int signals_count = 6;
int signals[] = {
	SIGABRT,
	SIGBUS,
	SIGFPE,
	SIGILL,
	SIGSEGV,
    EXC_BAD_ACCESS,
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

+ (void)startWithApiKey:(NSString*)apiKey {
    notifier = [[BugsnagNotifier alloc] init];
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
    [notifier notifyException:exception withMetaData:nil];
}

+ (void) notify:(NSException *)exception withData:(NSDictionary*)metaData {
    [notifier notifyException:exception withMetaData:metaData];
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