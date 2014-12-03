//
//  BugsnagIosNotifier.m
//
//  Created by Conrad Irwin on 2014-10-01.
//
//  Copyright (c) 2014 Bugsnag, Inc. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE

#import <UIKit/UIKit.h>
#include <sys/utsname.h>


#import "BugsnagIosNotifier.h"
#import "BugsnagNotifier.h"

#import "RFC3339DateTool.h"

@implementation BugsnagIosNotifier

- (void) start {
    [super start];
    
    [self.details setValue: @"iOS Bugsnag Notifier" forKey:@"name"];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryChanged:) name:UIDeviceBatteryStateDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryChanged:) name:UIDeviceBatteryLevelDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(lowMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];

    [UIDevice currentDevice].batteryMonitoringEnabled = TRUE;
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];

    [self batteryChanged:nil];
    [self orientationChanged:nil];
}

- (void) batteryChanged:(NSNotification *)notif {
    NSNumber *batteryLevel = [NSNumber numberWithFloat:[UIDevice currentDevice].batteryLevel];
    NSNumber *charging = [NSNumber numberWithBool: [UIDevice currentDevice].batteryState == UIDeviceBatteryStateCharging];

    [[self state] addAttribute: @"batteryLevel" withValue: batteryLevel toTabWithName:@"deviceState"];
    [[self state] addAttribute: @"charging" withValue: charging toTabWithName:@"deviceState"];
}

- (void)orientationChanged:(NSNotification *)notif {
    NSString *orientation;
    switch([UIDevice currentDevice].orientation) {
        case UIDeviceOrientationPortraitUpsideDown:
            orientation = @"portraitupsidedown";
            break;
        case UIDeviceOrientationPortrait:
            orientation = @"portrait";
            break;
        case UIDeviceOrientationLandscapeRight:
            orientation = @"landscaperight";
            break;
        case UIDeviceOrientationLandscapeLeft:
            orientation = @"landscapeleft";
            break;
        case UIDeviceOrientationFaceUp:
            orientation = @"faceup";
            break;
        case UIDeviceOrientationFaceDown:
            orientation = @"facedown";
            break;
        case UIDeviceOrientationUnknown:
        default:
            orientation = @"unknown";
    }
    [[self state] addAttribute:@"orientation" withValue:orientation toTabWithName:@"deviceState"];
}

- (void)lowMemoryWarning:(NSNotification *)notif {
    [[self state] addAttribute: @"lowMemoryWarning" withValue: [RFC3339DateTool stringFromDate:[NSDate date]] toTabWithName:@"deviceState"];
}

@end

#endif