//
//  OOMScenario.m
//  iOSTestApp
//
//  Created by Nick Dowell on 19/01/2021.
//  Copyright © 2021 Bugsnag. All rights reserved.
//

#import "OOMScenario.h"

#import <UIKit/UIKit.h>

#define MEGABYTE 0x100000

@implementation OOMScenario {
    NSUInteger _blockSize;
}

- (void)startBugsnag {
    self.config.autoTrackSessions = YES;
    self.config.enabledErrorTypes.ooms = YES;
    self.config.launchDurationMillis = 0; // Ensure isLaunching will be true for the OOM, no matter how long it takes to occur.
    [self.config addMetadata:@{@"bar": @"foo"} toSection:@"custom"];
    [self.config setUser:@"foobar" withEmail:@"foobar@example.com" andName:@"Foo Bar"];
    __weak typeof(self) weakSelf = self;
    [self.config addOnSendErrorBlock:^BOOL(BugsnagEvent *event) {
        BugsnagLastRunInfo *lastRunInfo = weakSelf.client.lastRunInfo;
        if (lastRunInfo) {
            [event addMetadata:@{@"consecutiveLaunchCrashes": @(lastRunInfo.consecutiveLaunchCrashes),
                                 @"crashed": @(lastRunInfo.crashed),
                                 @"crashedDuringLaunch": @(lastRunInfo.crashedDuringLaunch)}
                     toSection:@"lastRunInfo"];
        }
        return true;
    }];
    [super startBugsnag];
}

- (void)run {
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidReceiveMemoryWarningNotification object:nil
                                                     queue:nil usingBlock:^(NSNotification *note) {
        NSLog(@"*** Received memory warning");
    }];
    // Delay to allow session payload to be sent
    [self performSelector:@selector(consumeAllMemory) withObject:nil afterDelay:2];
}

- (void)consumeAllMemory {
    NSUInteger physicalMemory = (NSUInteger)NSProcessInfo.processInfo.physicalMemory;
    NSUInteger megabytes = physicalMemory / MEGABYTE;
    NSLog(@"*** Physical memory = %lu MB", (unsigned long)megabytes);
    
    // The ActiveHard limit varies between devices
    //
    // Device       iOS     Total   Limit
    // ========================================
    // iPad3,19      9       987     700  (70%)
    // iPhone12,1   14      3859    2098  (54%)
    // iPhone12,8   14      2965    2095  (70%)
    // iPhone13,1   14      3718    2098  (57%)
    //
    NSUInteger limit = MIN(2098, megabytes * 70 / 100);
    
    NSUInteger initial = limit * 95 / 100;
    NSLog(@"*** Dirtying an initial block of %lu MB", (unsigned long)initial);
    [self consumeMegabytes:initial];
    
    _blockSize = limit <= 1024 ? 1 : 2;
    NSLog(@"*** Dirtying remaining memory in %lu MB blocks", (unsigned long)_blockSize);
    // This should take around 2 seconds to trigger an OOM kill
    [NSTimer scheduledTimerWithTimeInterval:0.03 target:self selector:@selector(timerFired) userInfo:nil repeats:YES];
}

- (void)timerFired {
    [self consumeMegabytes:_blockSize];
}

- (void)consumeMegabytes:(NSUInteger)megabytes {
    for (NSUInteger i = 0; i < megabytes; i++) {
        const NSUInteger pagesize = NSPageSize();
        const NSUInteger npages = MEGABYTE / pagesize;
        volatile char *ptr = malloc(MEGABYTE);
        for (NSUInteger page = 0; page < npages; page++) {
            ptr[page * pagesize] = 42; // Dirty each page
        }
    }
}

@end
