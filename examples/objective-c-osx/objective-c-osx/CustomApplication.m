//
//  CustomApplication.m
//  objective-c-osx
//
//  Created by Simon Maynard on 7/27/15.
//  Copyright (c) 2015 Bugsnag. All rights reserved.
//

#import "CustomApplication.h"
#import <Bugsnag/Bugsnag.h>

@implementation CustomApplication

- (void)reportException:(NSException *)theException {
    [Bugsnag notify:theException];
    [super reportException:theException];
}

@end
