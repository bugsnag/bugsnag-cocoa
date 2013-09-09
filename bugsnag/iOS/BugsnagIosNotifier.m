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
@property (readonly) NSString* architecture;
@end

@implementation BugsnagIosNotifier

- (id) initWithConfiguration:(BugsnagConfiguration*) configuration {
    if((self = [super initWithConfiguration:configuration])) {
        if (self.configuration.appVersion == nil) self.configuration.appVersion = self.appVersion;
        if (self.configuration.osVersion == nil) self.configuration.osVersion = self.osVersion;
        if (self.configuration.userId == nil) self.configuration.userId = self.userUUID;

        self.notifierName = @"Bugsnag iOS Notifier";
        
        [self beforeNotify:^(BugsnagEvent *event) {
            [self addIosDiagnosticsToEvent:event];
            return YES;
        }];
    }
    return self;
}

- (void) start {
    [super start];
    //TODO:SM Add hook for application hitting foreground etc
}

- (void) addIosDiagnosticsToEvent:(BugsnagEvent *) event {
    [event addAttribute:@"Architecture" withValue:self.architecture toTabWithName:@"Device"];
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

- (NSString *) architecture {
#ifdef _ARM_ARCH_7
    NSString *arch = @"armv7";
#else
#ifdef _ARM_ARCH_6
    NSString *arch = @"armv6";
#else
#ifdef __i386__
    NSString *arch = @"i386";
#endif
#endif
#endif
    return arch;
}

- (NSString *) topMostViewController {
    
}
@end
