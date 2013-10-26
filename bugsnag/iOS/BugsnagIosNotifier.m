//
//  BugsnagIosNotifier.m
//  Bugsnag
//
//  Created by Simon Maynard on 8/28/13.
//  Copyright (c) 2013 Simon Maynard. All rights reserved.
//

#import <UIKit/UIKit.h>
#include <sys/utsname.h>


#import "BugsnagIosNotifier.h"

@interface BugsnagIosNotifier ()
@property (readonly) NSString* topMostViewController;
@property (atomic) BOOL inForeground;
@property (atomic) CFAbsoluteTime lastEnteredForeground;
@property (atomic) CFAbsoluteTime appStarted;
@property (atomic) CFAbsoluteTime lastMemoryWarning;
@property (atomic) float batteryLevel;
@property (atomic) BOOL charging;
@property (atomic) NSString *orientation;

- (void)applicationDidBecomeActive:(NSNotification *)notif;
- (void)applicationDidEnterBackground:(NSNotification *)notif;

@end

@implementation BugsnagIosNotifier

- (id) initWithConfiguration:(BugsnagConfiguration*) configuration {
    if((self = [super initWithConfiguration:configuration])) {
        self.notifierName = @"iOS Bugsnag Notifier";
        self.inForeground = YES;
        self.appStarted = self.lastEnteredForeground = CFAbsoluteTimeGetCurrent();
        self.charging = false;
        self.batteryLevel = -1.0;
        self.lastMemoryWarning = 0.0;

        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryChanged:) name:UIDeviceBatteryStateDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryChanged:) name:UIDeviceBatteryLevelDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(lowMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
        
        [UIDevice currentDevice].batteryMonitoringEnabled = TRUE;
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    }
    return self;
}

- (NSString *) userUUID {
    // Return the already determined the UUID
    if ([[UIDevice currentDevice] respondsToSelector:@selector(identifierForVendor)]) {
        return [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    } else {
        return [super userUUID];
    }
}

- (NSString *) topMostViewController {
    UIViewController *viewController = nil;
    UIViewController *visibleViewController = nil;
    
    if ([[[UIApplication sharedApplication] keyWindow].rootViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navigationController = (UINavigationController *) [[UIApplication sharedApplication] keyWindow].rootViewController;
        viewController = navigationController.visibleViewController;
    }
    else {
        viewController = [[UIApplication sharedApplication] keyWindow].rootViewController;
    }
    
    int tries = 0;
    
    while (visibleViewController == nil && tries <= 30 && viewController) {
        tries++;
        
        UIViewController *presentedViewController = nil;
        
        if ([viewController respondsToSelector:@selector(presentedViewController)]) {
            presentedViewController = viewController.presentedViewController;
        } else {
            presentedViewController = [viewController performSelector:@selector(modalViewController)];
        }
        
        if (presentedViewController == nil) {
            visibleViewController = viewController;
        } else {
            if ([presentedViewController isKindOfClass:[UINavigationController class]]) {
                UINavigationController *navigationController = (UINavigationController *)presentedViewController;
                viewController = navigationController.visibleViewController;
            } else {
                viewController = presentedViewController;
            }
        }
    }
    
    return NSStringFromClass([visibleViewController class]);
}

- (NSString *) resolution {
    CGSize screenSize = [[UIScreen mainScreen] bounds].size;
    int scale = [[UIScreen mainScreen] scale];
    return [NSString stringWithFormat:@"%ix%i", (int)screenSize.width * scale, (int)screenSize.height * scale];
}

- (NSString *) density {
    if ([[UIScreen mainScreen] scale] > 1.0) {
        return @"retina";
    } else {
        return @"non-retina";
    }
}

- (BOOL) jailbroken {
    return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"cydia://"]];
}

- (void)applicationDidBecomeActive:(NSNotification *)notif {
    self.inForeground = YES;
    self.lastEnteredForeground = CFAbsoluteTimeGetCurrent();
    [self start];
}

- (void)applicationDidEnterBackground:(NSNotification *)notif {
    self.inForeground = NO;
}

- (void)batteryChanged:(NSNotification *)notif {
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
    self.lastMemoryWarning = CFAbsoluteTimeGetCurrent();
}

- (NSDictionary *) collectHostData {
    NSMutableDictionary *hostData = [NSMutableDictionary dictionaryWithDictionary:[super collectHostData]];
    [hostData setValue: [self density] forKey: @"screenDensity"];
    [hostData setValue: [self resolution] forKey: @"screenResolution"];
    [hostData setValue: [[UIDevice currentDevice] systemVersion] forKey: @"osVersion"];
    [hostData setValue: [[UIDevice currentDevice] systemName] forKey:@"osName"];
    if ([self jailbroken]) {
        [hostData setValue: [NSNumber numberWithBool: [self jailbroken]] forKey: @"jailbroken"];
    }
    return hostData;
}

- (NSDictionary *) collectAppState {
    NSMutableDictionary *appState = [NSMutableDictionary dictionaryWithDictionary:[super collectAppState]];
    
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    [appState setValue: [self topMostViewController] forKey:@"viewController"];
    [appState setValue: [NSNumber numberWithBool: self.inForeground] forKey:@"inForeground"];
    [appState setValue: [NSNumber numberWithInteger: round(1000.0 * (now - self.lastEnteredForeground))] forKey: @"durationInForeground"];
    [appState setValue: [NSNumber numberWithInteger: round(1000.0 * (now - self.appStarted))] forKey: @"duration"];
    if (self.lastMemoryWarning > 0.0) {
        [appState setValue: [NSNumber numberWithInteger: round(1000.0 * (now - self.lastMemoryWarning))] forKey: @"timeSinceMemoryWarning"];
    }
    
    return appState;
}

- (NSDictionary *) collectHostState {
    NSMutableDictionary *hostState = [NSMutableDictionary dictionaryWithDictionary:[super collectHostState]];
    
    [hostState setValue: [NSNumber numberWithInteger: round(100.0 * self.batteryLevel)] forKey: @"batteryLevel"];
    [hostState setValue: [NSNumber numberWithBool: self.charging] forKey: @"charging"];
    if (self.orientation != nil) {
        [hostState setValue: [self orientation] forKey: @"orientation"];
    }

    
    return hostState;
}

@end
