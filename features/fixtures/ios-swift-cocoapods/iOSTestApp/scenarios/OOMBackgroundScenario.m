//
//  OOMBackgroundScenario.m
//  iOSTestApp
//
//  Created by Simon Maynard on 4/10/20.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OOMBackgroundScenario.h"

@implementation OOMBackgroundScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = NO;
    self.config.releaseStage = @"alpha";
    [self.config addBeforeSendBlock:^bool(NSDictionary * _Nonnull rawEventData, BugsnagCrashReport * _Nonnull report) {
        NSMutableDictionary *metadata = [report.metaData mutableCopy];
        metadata[@"extra"] = @{ @"shape": @"line" };
        report.metaData = metadata;
        return YES;
    }];
    
    self.config.reportOOMs = true;
    
    [super startBugsnag];
}

- (void)run {
}

- (void)didEnterBackgroundNotification {
    [Bugsnag leaveBreadcrumbWithMessage:@"Crumb left before crash"];
    
    // Simulate an out of memory error
    kill(getpid(), SIGKILL);
}

@end
