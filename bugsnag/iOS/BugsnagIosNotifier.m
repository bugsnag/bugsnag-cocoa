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

- (void)applicationDidBecomeActive:(NSNotification *)notif;
- (void)applicationDidEnterBackground:(NSNotification *)notif;

@end

@implementation BugsnagIosNotifier

- (id) initWithConfiguration:(BugsnagConfiguration*) configuration {
    if((self = [super initWithConfiguration:configuration])) {
        self.notifierName = @"iOS Bugsnag Notifier";
        self.inForeground = YES;
        self.appStarted = self.lastEnteredForeground = CFAbsoluteTimeGetCurrent();

        
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
    self.lastEnteredForeground = CFAbsoluteTimeGetCurrent();
    [self start];
}

- (void)applicationDidEnterBackground:(NSNotification *)notif {
    self.inForeground = NO;
}


- (NSDictionary*) collectHostData {
    NSMutableDictionary *hostData = [NSMutableDictionary dictionaryWithDictionary:[super collectHostData]];
    [hostData setValue: [self density] forKey: @"screenDensity"];
    [hostData setValue: [self resolution] forKey: @"screenResolution"];
    [hostData setValue: [[UIDevice currentDevice] systemVersion] forKey: @"OSVersion"];
    [hostData setValue: [[UIDevice currentDevice] systemName] forKey:@"OSName"];
    return hostData;
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

@end
