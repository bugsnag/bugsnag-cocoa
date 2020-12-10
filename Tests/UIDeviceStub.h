//
//  UIDeviceStub.h
//  Bugsnag-iOSTests
//
//  Created by Nick Dowell on 10/12/2020.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIDeviceStub : NSObject

@property double batteryLevel;

@property BOOL batteryMonitoringEnabled;

@property UIDeviceBatteryState batteryState;

@property UIDeviceOrientation orientation;

@end

NS_ASSUME_NONNULL_END
