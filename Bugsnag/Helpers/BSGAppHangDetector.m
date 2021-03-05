//
//  BSGAppHangDetector.m
//  Bugsnag
//
//  Created by Nick Dowell on 01/03/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "BSGAppHangDetector.h"

#import <Bugsnag/BugsnagConfiguration.h>
#import <Bugsnag/BugsnagErrorTypes.h>

#import "BugsnagLogger.h"
#import "BugsnagThread+Recording.h"


@interface BSGAppHangDetector ()

@property (nonatomic) CFRunLoopObserverRef observer;

@end


@implementation BSGAppHangDetector

- (void)dealloc {
    if (_observer) {
        CFRunLoopRemoveObserver(CFRunLoopGetMain(), _observer, kCFRunLoopCommonModes);
    }
}

- (void)startWithConfiguration:(BugsnagConfiguration *)configuration {
    if (self.observer) {
        bsg_log_err(@"Attempted to call %s more than once", __PRETTY_FUNCTION__);
        return;
    }
    
    if (!configuration.enabledErrorTypes.appHangs) {
        return;
    }
    
    if (NSProcessInfo.processInfo.environment[@"XCTestConfigurationFilePath"]) {
        // Disable functionality during unit testing to avoid crashes that can occur due to there
        // being many leaked BugsnagClient instances and BSGAppHangDetectors running while global
        // shared data structures are being reinitialized.
        return;
    }
    
    const BOOL fatalOnly = configuration.appHangThresholdMillis == BugsnagAppHangThresholdFatalOnly;
    const BOOL recordAllThreads = configuration.sendThreads == BSGThreadSendPolicyAlways;
    const NSTimeInterval threshold = fatalOnly ? 2 : configuration.appHangThresholdMillis / 1000.0;
    
    bsg_log_debug(@"Starting App Hang detector with threshold = %g seconds", threshold);
    
    dispatch_queue_t backgroundQueue;
    __block dispatch_semaphore_t semaphore;
    
    backgroundQueue = dispatch_queue_create("com.bugsnag.app-hang-detector", DISPATCH_QUEUE_SERIAL);
    
    void (^ observerBlock)(CFRunLoopObserverRef, CFRunLoopActivity) = ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
        // "Inside the event processing loop after the run loop wakes up, but before processing the event that woke it up"
        if (activity == kCFRunLoopAfterWaiting) {
            if (!semaphore) {
                semaphore = dispatch_semaphore_create(0);
            }
            // Using dispatch_after prevents our queue showing up in Instruments' Time Profiler until there is a hang.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(threshold * NSEC_PER_SEC)), backgroundQueue, ^{
                if (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW) != 0) {
                    bsg_log_info("App hang detected");
                    
                    NSArray<BugsnagThread *> *threads = nil;
                    if (recordAllThreads) {
                        threads = [BugsnagThread allThreads:YES callStackReturnAddresses:NSThread.callStackReturnAddresses];
                    } else {
                        threads = [NSArray arrayWithObjects:[BugsnagThread mainThread], nil]; //!OCLint
                    }
                    
                    NSArray<BugsnagStackframe *> *stacktrace = threads.firstObject.stacktrace;
                    
                    // TODO: Create BugsnagEvent with stacktrace
                    if (!fatalOnly) {
                        NSLog(@"%@", stacktrace);
                    }
                    
                    // TODO: Persist BugsnagEvent to app_hang.json
                    
                    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                    bsg_log_info("App hang has ended");
                    
                    // TODO: Delete app_hang.json
                    
                    // TODO: Send BugsnagEvent if !fatalOnly
                }
            });
        }
        
        // "Inside the event processing loop before the run loop sleeps, waiting for a source or timer to fire"
        if (activity == kCFRunLoopBeforeWaiting) {
            if (semaphore) {
                dispatch_semaphore_signal(semaphore);
            }
        }
    };
    
    self.observer = CFRunLoopObserverCreateWithHandler(NULL, kCFRunLoopAfterWaiting | kCFRunLoopBeforeWaiting, true, 0, observerBlock);
    
    CFRunLoopMode runLoopMode = CFRunLoopCopyCurrentMode(CFRunLoopGetCurrent());
    // The run loop mode will be NULL if called before the run loop has started; e.g. in a +load method.
    if (runLoopMode) {
        // If we are already in the run loop (e.g. in app delegate) start monitoring immediately so that app hangs during app launch are detected.
        observerBlock(self.observer, kCFRunLoopAfterWaiting);
        CFRelease(runLoopMode);
    }
    
    CFRunLoopAddObserver(CFRunLoopGetMain(), self.observer, kCFRunLoopCommonModes);
}

@end
