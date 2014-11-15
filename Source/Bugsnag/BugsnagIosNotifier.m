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

#import <UIKit/UIKit.h>
#include <sys/utsname.h>


#import "BugsnagIosNotifier.h"
#import "RFC3339DateTool.h"

@implementation BugsnagIosNotifier

- (void) start {
    [super start];

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
    self.batteryLevel = [UIDevice currentDevice].batteryLevel;
    self.charging = [UIDevice currentDevice].batteryState == UIDeviceBatteryStateCharging;
}

- (void)orientationChanged:(NSNotification *)notif {
    switch([UIDevice currentDevice].orientation) {
        case UIDeviceOrientationPortraitUpsideDown:
            self.orientation = @"portraitupsidedown";
            break;
        case UIDeviceOrientationPortrait:
            self.orientation = @"portrait";
            break;
        case UIDeviceOrientationLandscapeRight:
            self.orientation = @"landscaperight";
            break;
        case UIDeviceOrientationLandscapeLeft:
            self.orientation = @"landscapeleft";
            break;
        case UIDeviceOrientationFaceUp:
            self.orientation = @"faceup";
            break;
        case UIDeviceOrientationFaceDown:
            self.orientation = @"facedown";
            break;
        case UIDeviceOrientationUnknown:
        default:
            self.orientation = @"unknown";
    }
}

- (void)lowMemoryWarning:(NSNotification *)notif {
    self.lastMemoryWarning = [NSDate date];
}

- (void)setOrientation: (NSString*) orientation {
    [self.configuration.metaData addAttribute:@"orientation" withValue:orientation toTabWithName:@"app"];
}

- (void)setBatteryLevel: (float) batteryLevel {
    [self.configuration.metaData addAttribute:@"batteryLevel" withValue:[NSNumber numberWithFloat:batteryLevel] toTabWithName:@"app"];
}

- (void)setCharging: (bool) charging {
    [self.configuration.metaData addAttribute:@"charging" withValue:[NSNumber numberWithBool:charging] toTabWithName:@"app"];
}

- (void)setLastMemoryWarning: (NSDate*) date {
    [self.configuration.metaData addAttribute:@"lastEnteredForeground" withValue: [RFC3339DateTool stringFromDate:date] toTabWithName:@"app"];
}

@end
