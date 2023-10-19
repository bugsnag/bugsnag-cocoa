//
//  ViewController.m
//  objective-c-osx
//
//  Created by Simon Maynard on 7/24/15.
//  Copyright (c) 2015 Bugsnag. All rights reserved.
//

#import "ViewController.h"
#import <Bugsnag/Bugsnag.h>
#import <stdexcept>

@implementation ViewController

- (IBAction)rethrownExceptionClick:(id)sender {
    [self crash];
//    @try {
//        @throw [NSException exceptionWithName:@"rethrownException" reason:@"reason" userInfo:nil];
//    }
//    @catch (NSException *exception) {
//        @throw exception;
//    }
}

- (IBAction)caughtExceptionNotifyClick:(id)sender {
    @try {
        @throw [NSException exceptionWithName:@"caughtExceptionNotify" reason:@"reason" userInfo:nil];
    }
    @catch (NSException *exception) {
        [Bugsnag notify:exception];
    }
}

- (IBAction)uncaughtExceptionClick:(id)sender {
    @throw [NSException exceptionWithName:@"uncaughtException" reason:@"reason" userInfo:nil];
}

- (IBAction)fatalAppHang:(id)sender {
    [NSThread sleepForTimeInterval:3];
    _exit(1);
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
