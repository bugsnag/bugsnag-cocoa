//
//  BugsnagConfiguration.m
//  bugsnag
//
//  Created by Simon Maynard on 8/28/13.
//  Copyright (c) 2013 Simon Maynard. All rights reserved.
//

#import "BugsnagConfiguration.h"

@implementation BugsnagConfiguration

- (id) init {
    if(self = [super init]) {
#if DEBUG
        self.releaseStage = @"development";
#else
        self.releaseStage = @"production";
#endif
    }
    return self;
}

@end
