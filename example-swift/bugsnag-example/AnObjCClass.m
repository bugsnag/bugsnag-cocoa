//
//  AnObjCClass.m
//  bugsnag-example
//
//  Created by Isaac Waller on 4/2/15.
//  Copyright (c) 2015 Isaac Waller. All rights reserved.
//

#import "AnObjCClass.h"
#import "bugsnag_example-Swift.h"

@implementation AnObjCClass

- (void)makeAStackTrace:(AnotherClass *)other {
    [self bounce:other];
}

- (void)bounce:(AnotherClass *)other {
    [other crash3];
}

@end
