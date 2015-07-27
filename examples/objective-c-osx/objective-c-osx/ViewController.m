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

- (IBAction)caughtExceptionNoNotifyClick:(id)sender {
    @try {
        @throw [NSException exceptionWithName:@"caughtExceptionNoNotify" reason:@"reason" userInfo:nil];
    }
    @catch (NSException *exception) {
        NSLog(@"Bad times");
    }
}

- (IBAction)uncaughtExceptionClick:(id)sender {
    @throw [NSException exceptionWithName:@"uncaughtException" reason:@"reason" userInfo:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

@end
