//
//  OOMScenario.m
//  iOSTestApp
//
//  Created by Nick Dowell on 19/01/2021.
//  Copyright © 2021 Bugsnag. All rights reserved.
//

#import "OOMScenario.h"

#import <UIKit/UIKit.h>

@implementation OOMScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = YES;
    self.config.enabledErrorTypes.ooms = YES;
    [self.config addMetadata:@{@"bar": @"foo"} toSection:@"custom"];
    [self.config setUser:@"foobar" withEmail:@"foobar@example.com" andName:@"Foo Bar"];
    [super startBugsnag];
}

- (void)run {
    // Delay to allow session payload to be sent
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSLog(@"*** Consuming all available memory...");
        __block BOOL pause = NO;
        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidReceiveMemoryWarningNotification object:nil
                                                         queue:nil usingBlock:^(NSNotification * _Nonnull note) {
            pause = YES;
        }];
        const int blocksize = 1024 * 1024;
        const int pagesize = (int)NSPageSize();
        const int npages = blocksize / pagesize;
        while (1) {
            volatile char *ptr = malloc(blocksize);
            for (int i = 0; i < npages; i++) {
                ptr[i * pagesize] = 42; // Dirty each page
                
                if (pause) {
                    pause = NO;
                    NSLog(@"*** Pausing memory consumption to allow Bugsnag to write breadcrumbs and metadata");
                    [NSThread sleepForTimeInterval:0.5];
                    NSLog(@"*** Resuming memory consumption...");
                }
            }
        }
    });
}

@end
