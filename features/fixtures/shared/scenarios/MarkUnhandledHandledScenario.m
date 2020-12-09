//
//  MarkUnhandledHandledScenario.m
//  iOSTestApp
//
//  Created by Karl Stenerud on 03.12.20.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "MarkUnhandledHandledScenario.h"

@implementation MarkUnhandledHandledScenario

- (void)startBugsnag {
    self.config.onCrashHandler = markErrorHandledCallback;
    [super startBugsnag];
}

@end
