//
// Created by Jamie Lynch on 07/06/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"
#import <UIKit/UIKit.h>

/**
 * Sends an automatic session payload to Bugsnag.
 */
@interface AutoSessionScenario : Scenario
@end

@implementation AutoSessionScenario

- (void)run {
    if (@available(iOS 10.0, *)) {
        NSURL *url = [NSURL URLWithString: @"http://bs-local.com:9339/docs/test.html"];
        
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
            NSLog(@"Opened %@ with success %d", url, success);
        }];
    }
}

@end
