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
@property (readonly) NSString* context;
@end

@implementation BugsnagIosNotifier

- (id) initWithConfiguration:(BugsnagConfiguration*) configuration {
    if((self = [super initWithConfiguration:configuration])) {
        if (self.configuration.appVersion == nil) self.configuration.appVersion = self.appVersion;
        if (self.configuration.osVersion == nil) self.configuration.osVersion = self.osVersion;

        self.notifierName = @"Bugsnag iOS Notifier";
        
        [self beforeNotify:^(BugsnagEvent *event) {
            [self addIosDiagnosticsToEvent:event];
        }];
    }
    return self;
}

- (void) start {
    //TODO:SM Add hook for application hitting foreground etc
}

- (void) addIosDiagnosticsToEvent:(BugsnagEvent *) event {
    //TODO:SM Add the runtime data to the event
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

@end
