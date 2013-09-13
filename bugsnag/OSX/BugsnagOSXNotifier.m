//
//  BugsnagOSXNotifier.m
//  Bugsnag
//
//  Created by Simon Maynard on 9/12/13.
//  Copyright (c) 2013 Simon Maynard. All rights reserved.
//

#import "BugsnagOSXNotifier.h"

@implementation BugsnagOSXNotifier

- (id) initWithConfiguration:(BugsnagConfiguration*) configuration {
    if((self = [super initWithConfiguration:configuration])) {
        self.notifierName = @"Bugsnag OSX Notifier";
    }
    return self;
}

@end
