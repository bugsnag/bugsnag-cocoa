//
//  ViewController.m
//  objective-c-osx
//
//  Created by Simon Maynard on 7/24/15.
//  Copyright (c) 2015 Bugsnag. All rights reserved.
//

#import "ViewController.h"
#import <Bugsnag/Bugsnag.h>

@implementation ViewController

- (IBAction)rethrownExceptionClick:(id)sender {
    @try {
        @throw [NSException exceptionWithName:@"rethrownException" reason:@"reason" userInfo:nil];
    }
    @catch (NSException *exception) {
        @throw exception;
    }
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

@end
