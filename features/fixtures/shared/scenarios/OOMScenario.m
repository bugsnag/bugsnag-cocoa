//
//  OOMScenario.m
//  iOSTestApp
//
//  Created by Nick Dowell on 19/01/2021.
//  Copyright © 2021 Bugsnag. All rights reserved.
//

#import "OOMScenario.h"

#import <UIKit/UIKit.h>

#include <mach/mach_init.h>
#include <mach/task_info.h>
#include <mach/task.h>
#include <os/proc.h>
#include <sys/utsname.h>

#define MEGABYTE 0x100000

@implementation OOMScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = YES;
    self.config.enabledErrorTypes.ooms = YES;
    self.config.launchDurationMillis = 0; // Ensure isLaunching will be true for the OOM, no matter how long it takes to occur.
    self.config.appType = @"vanilla";
    self.config.appVersion = @"3.2.1";
    self.config.bundleVersion = @"321.123";
    self.config.releaseStage = @"staging";
    [self.config addMetadata:@{@"bar": @"foo"} toSection:@"custom"];
    [self.config setUser:@"foobar" withEmail:@"foobar@example.com" andName:@"Foo Bar"];
    [self.config addOnSendErrorBlock:^BOOL(BugsnagEvent *event) {
        BugsnagLastRunInfo *lastRunInfo = Bugsnag.lastRunInfo;
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
    [Bugsnag setContext:@"OOM Scenario"];
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidReceiveMemoryWarningNotification object:nil
                                                     queue:nil usingBlock:^(NSNotification *note) {
        NSLog(@"*** Received memory warning");
    }];
    // Delay to allow session payload to be sent
    [self performSelector:@selector(consumeAllMemory) withObject:nil afterDelay:2];
}

- (void)consumeAllMemory {
    struct utsname system = {0};
    uname(&system);
    NSLog(@"*** Device = %s", system.machine);
    
    NSUInteger physicalMemory = (NSUInteger)NSProcessInfo.processInfo.physicalMemory;
    NSUInteger megabytes = physicalMemory / MEGABYTE;
    NSLog(@"*** Physical memory = %lu MB", (unsigned long)megabytes);
    
    //
    // The ActiveHard limit and point at which a memory warning is sent varies by device
    // Some data from http://www.chenxiyao.com/article/10/read
    //
    // Device                       Total   Warn    Limit
    // =======================================================
    // iPad3,1      iPad 3rd gen     987     560     700  (70%)
    // iPhone5,1    iPhone 5                         650
    // iPhone6,2    iPhone 5s       1000     600     650  (65%)
    // iPhone7,1    iPhone 6 Plus                    650
    // iPhone7,2    iPhone 6                         650
    // iPhone8,1    iPhone 6s                       1380
    // iPhone8,2    iPhone 6s Plus                  1380
    // iPhone8,4    iPhone SE                       1380
    // iPhone9,1    iPhone 7                        1380
    // iPhone9,2    iPhone 7 Plus                   2050
    // iPhone10,1   iPhone 8                        1380
    // iPhone10,2   iPhone 8 Plus                   2050
    // iPhone10,3   iPhone X                        1400
    // iPhone11,2   iPhone XS                       2050
    // iPhone11,4   iPhone XS Max                   2050
    // iPhone11,8   iPhone XR                       1400
    // iPhone12,1   iPhone 11       3859            2098  (54%)
    // iPhone12,8   iPhone SE (2)   2965    1994    2098  (70%)
    // iPhone13,1   iPhone 12 mini  3718    1546    2098  (57%)
    //
    NSUInteger limit = 0;
    task_vm_info_data_t vm_info = {0};
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    kern_return_t result = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&vm_info, &count);
    if (result == KERN_SUCCESS && count >= TASK_VM_INFO_REV4_COUNT) {
        limit = (NSUInteger)(vm_info.phys_footprint + vm_info.limit_bytes_remaining) / MEGABYTE;
        NSLog(@"*** Memory limit = %lu MB", (unsigned long)limit);
    } else if (!strcmp(system.machine, "iPhone6,2")) {
        limit = 650;
        NSLog(@"*** Memory limit = %lu MB", (unsigned long)limit);
    } else {
        limit = MIN(2098, megabytes * 70 / 100);
        NSLog(@"*** Memory limit = %lu MB (estimated)", (unsigned long)limit);
    }
    
    // The size of the initial block needs to be under the memory warning limit in order for one to be reliably sent.
    NSUInteger initial = limit * 70 / 100;
    NSLog(@"*** Dirtying an initial block of %lu MB", (unsigned long)initial);
    [self consumeMegabytes:initial];
    
    NSLog(@"*** Dirtying remaining memory in ~2 seconds");
    NSTimeInterval timeInterval = 2.0 / (limit - initial);
    [NSTimer scheduledTimerWithTimeInterval:timeInterval target:self selector:@selector(timerFired) userInfo:nil repeats:YES];
}

- (void)timerFired {
    [self consumeMegabytes:1];
}

- (void)consumeMegabytes:(NSUInteger)megabytes {
    for (NSUInteger i = 0; i < megabytes; i++) {
        volatile char *ptr = malloc(MEGABYTE);
        // Originally used NSPageSize() but on iPhone 5s iOS 12 that didn't result in dirtying all the memory allocated.
        const int pagesize = 4096;
        const int npages = MEGABYTE / pagesize;
        for (int page = 0; page < npages; page++) {
            ptr[page * pagesize] = 42; // Dirty each page
        }
    }
}

@end
