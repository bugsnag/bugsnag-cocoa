//
//  BugsnagIosNotifier.m
//  Bugsnag
//
//  Created by Simon Maynard on 8/28/13.
//  Copyright (c) 2013 Simon Maynard. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "BugsnagIosNotifier.h"

@interface BugsnagIosNotifier ()
@property (readonly) NSString* appVersion;
@property (readonly) NSString* osVersion;
@property (readonly) NSString* topMostViewController;
@property (atomic) BOOL inForeground;

- (void)applicationDidBecomeActive:(NSNotification *)notif;
- (void)applicationDidEnterBackground:(NSNotification *)notif;

@end

@implementation BugsnagIosNotifier

- (id) initWithConfiguration:(BugsnagConfiguration*) configuration {
    if((self = [super initWithConfiguration:configuration])) {
        if (self.configuration.appVersion == nil) self.configuration.appVersion = self.appVersion;
        if (self.configuration.osVersion == nil) self.configuration.osVersion = self.osVersion;
        if (self.configuration.userId == nil) self.configuration.userId = self.userUUID;
        
        [self.configuration.metaData addAttribute:@"Machine" withValue:self.machine toTabWithName:@"device"];

        self.notifierName = @"Bugsnag iOS Notifier";
        self.inForeground = YES;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        
        [self beforeNotify:^(BugsnagEvent *event) {
            [self addIosDiagnosticsToEvent:event];
            return YES;
        }];
    }
    return self;
}

- (void) addIosDiagnosticsToEvent:(BugsnagEvent *) event {
    NSString *topMostViewController = self.topMostViewController;
    if (event.context == nil && topMostViewController != nil) event.context = topMostViewController;
    
    [event addAttribute:@"Top Most View Controller" withValue:topMostViewController toTabWithName:@"application"];
    [event addAttribute:@"In Foreground" withValue:[NSNumber numberWithBool:self.inForeground] toTabWithName:@"application"];
}

- (NSString *) appVersion {
    NSString *bundleVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    NSString *versionString = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    if (bundleVersion != nil && versionString != nil && ![bundleVersion isEqualToString:versionString]) {
        return [NSString stringWithFormat:@"%@ (%@)", versionString, bundleVersion];
    } else if (bundleVersion != nil) {
        return bundleVersion;
    } else if(versionString != nil) {
        return versionString;
    }
    return @"";
}

- (NSString *) osVersion {
#if TARGET_IPHONE_SIMULATOR
	return [[UIDevice currentDevice] systemVersion];
#else
	return [[NSProcessInfo processInfo] operatingSystemVersionString];
#endif
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

- (void)applicationDidBecomeActive:(NSNotification *)notif {
    self.inForeground = YES;
    [self start];
}

- (void)applicationDidEnterBackground:(NSNotification *)notif {
    self.inForeground = NO;
}
@end
