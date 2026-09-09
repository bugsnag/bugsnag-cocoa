/*
 * Copyright (c) 2014 HockeyApp, Bit Stadium GmbH.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#import "Scenario.h"
#import "Logging.h"

#import <stdexcept>
#import <thread>

/**
 * Throw an uncaught C++ exception. This is a difficult case for crash reporters to handle,
 * as it involves the destruction of the data necessary to generate a correct backtrace.
 */
@interface CxxExceptionScenario : Scenario
- (void)crash __attribute__((noreturn));
@end

// Keep an exception active while a different thread throws and catches another
// one. This deterministically exposes a process-global "last exception" trace.
@interface CxxConcurrentExceptionScenario : CxxExceptionScenario
- (void)crashWithConcurrentException;
@end

@implementation CxxConcurrentExceptionScenario

- (void)run {
    [self crashWithConcurrentException];
}

- (void)crashWithConcurrentException {
    try {
        [self crash];
    } catch (const std::exception &) {
        std::thread otherThread([] {
            try {
                throw std::logic_error("Caught exception on another thread");
            } catch (const std::exception &) {
            }
        });
        otherThread.join();
        std::terminate();
    }
}

- (void)crash __attribute__((noreturn)) {
    throw std::runtime_error("Original exception on the crashing thread");
}

@end

// Installation happens on the main thread, but capture must also be enabled on
// threads created afterwards.
@interface CxxConcurrentExceptionBackgroundScenario : CxxConcurrentExceptionScenario
@end

@implementation CxxConcurrentExceptionBackgroundScenario

- (void)run {
    std::thread crashingThread([self] {
        [self crashWithConcurrentException];
    });
    crashingThread.join();
}

@end

@interface CxxPreexistingThreadExceptionScenario : CxxConcurrentExceptionScenario
@end

@implementation CxxPreexistingThreadExceptionScenario {
    dispatch_semaphore_t _proceed;
}

- (void)startBugsnag {
    if (self.launchCount == 1) {
        dispatch_semaphore_t started = dispatch_semaphore_create(0);
        _proceed = dispatch_semaphore_create(0);
        dispatch_semaphore_t proceed = _proceed;
        std::thread([self, started, proceed] {
            dispatch_semaphore_signal(started);
            dispatch_semaphore_wait(proceed, DISPATCH_TIME_FOREVER);
            [self crashWithConcurrentException];
        }).detach();
        dispatch_semaphore_wait(started, DISPATCH_TIME_FOREVER);
    }
    [super startBugsnag];
}

- (void)run {
    dispatch_semaphore_signal(_proceed);
}

@end

@interface CxxRethrowExceptionScenario : CxxConcurrentExceptionScenario
@end

@implementation CxxRethrowExceptionScenario

- (void)run {
    try {
        [self crash];
    } catch (...) {
        throw;
    }
}

@end

class CxxTestException : public std::runtime_error {
public:
    CxxTestException() : std::runtime_error("Original exception message") {}

    const char *what() const noexcept override {
        // Inspecting an exception must not replace its trace with this throw.
        try {
            throw std::logic_error("Caught while inspecting the exception");
        } catch (...) {
        }
        return std::runtime_error::what();
    }
};

@interface CxxInspectingExceptionScenario : CxxExceptionScenario
@end

@implementation CxxInspectingExceptionScenario

- (void)crash __attribute__((noreturn)) {
    throw CxxTestException();
}

@end

@implementation CxxExceptionScenario

- (void)configure {
    [super configure];
    self.config.autoTrackSessions = NO;
}

- (void)run {
    [[NSThread mainThread] setName:@"потік"];
    [self crash];
}

- (void)crash __attribute__((noreturn)) {
    throw new std::runtime_error
    // Long enough to exceed BSG_KSCrashSentry_CPPException's DESCRIPTION_BUFFER_LENGTH
    ("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. "
     "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. "
     "Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. "
     "Excepteur sint occaecat cupidatat non proident, sunt in culpa qui  officia deserunt mollit anim id est laborum. "
     "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. "
     "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. "
     "Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. "
     "Excepteur sint occaecat cupidatat non proident, sunt in culpa qui  officia deserunt mollit anim id est laborum. "
     "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. "
     "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. "
     "Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. "
     "Excepteur sint occaecat cupidatat non proident, sunt in culpa qui  officia deserunt mollit anim id est laborum. ");
}

@end
