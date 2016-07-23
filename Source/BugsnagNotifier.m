//
//  BugsnagNotifier.m
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

#import <KSCrash/KSCrashAdvanced.h>

#import "Bugsnag.h"
#import "BugsnagBreadcrumb.h"
#import "BugsnagNotifier.h"
#import "BugsnagCollections.h"
#import "BugsnagCrashReport.h"
#import "BugsnagSink.h"

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#include <sys/utsname.h>
#elif TARGET_OS_MAC
#import <AppKit/AppKit.h>
#endif

NSString *const NOTIFIER_VERSION = @"5.3.0";
NSString *const NOTIFIER_URL = @"https://github.com/bugsnag/bugsnag-cocoa";
NSString *const BSTabCrash = @"crash";
NSString *const BSTabConfig = @"config";
NSString *const BSAttributeSeverity = @"severity";
NSString *const BSAttributeDepth = @"depth";
NSString *const BSAttributeBreadcrumbs = @"breadcrumbs";
NSString *const BSEventLowMemoryWarning = @"lowMemoryWarning";

struct bugsnag_data_t {
    // Contains the user-specified metaData, including the user tab from config.
    char *metaDataJSON;
    // Contains the Bugsnag configuration, all under the "config" tab.
    char *configJSON;
    // Contains notifier state, under "deviceState" and crash-specific information under "crash".
    char *stateJSON;
    // Contains properties in the Bugsnag payload overridden by the user before it was sent
    char *userOverridesJSON;
    // User onCrash handler
    void (*onCrash)(const KSCrashReportWriter* writer);
};

static struct bugsnag_data_t g_bugsnag_data;

/**
 *  Handler executed when the application crashes. Writes information about the
 *  current application state using the crash report writer.
 *
 *  @param writer report writer which will receive updated metadata
 */
void BSSerializeDataCrashHandler(const KSCrashReportWriter *writer) {
    if (g_bugsnag_data.configJSON) {
        writer->addJSONElement(writer, "config", g_bugsnag_data.configJSON);
    }
    if (g_bugsnag_data.metaDataJSON) {
        writer->addJSONElement(writer, "metaData", g_bugsnag_data.metaDataJSON);
    }
    if (g_bugsnag_data.stateJSON) {
        writer->addJSONElement(writer, "state", g_bugsnag_data.stateJSON);
    }
    if (g_bugsnag_data.userOverridesJSON) {
        writer->addJSONElement(writer, "overrides", g_bugsnag_data.userOverridesJSON);
    }
    if (g_bugsnag_data.onCrash) {
        g_bugsnag_data.onCrash(writer);
    }
}

/**
 *  Writes a dictionary to a destination using the KSCrash JSON encoding
 *
 *  @param dictionary  data to encode
 *  @param destination target location of the data
 */
void BSSerializeJSONDictionary(NSDictionary *dictionary, char **destination) {
    @try {
        NSError *error;
        NSData *json = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:&error];

        if (!json) {
            NSLog(@"Bugsnag could not serialize metaData: %@", error);
            return;
        }
        *destination = reallocf(*destination, [json length] + 1);
        if (*destination) {
            memcpy(*destination, [json bytes], [json length]);
            (*destination)[[json length]] = '\0';
        }
    } @catch (NSException *exception) {
        NSLog(@"Bugsnag could not serialize metaData: %@", exception);
    }
}

@implementation BugsnagNotifier

@synthesize configuration;

- (id) initWithConfiguration:(BugsnagConfiguration*) initConfiguration {
    if((self = [super init])) {
        self.configuration = initConfiguration;
        self.state = [[BugsnagMetaData alloc] init];
        self.details = [@{
                         @"name": @"Bugsnag Objective-C",
                         @"version": NOTIFIER_VERSION,
                         @"url": NOTIFIER_URL} mutableCopy];

        self.metaDataLock = [[NSLock alloc] init];
        self.configuration.metaData.delegate = self;
        self.configuration.config.delegate = self;
        self.state.delegate = self;

        [self metaDataChanged: self.configuration.metaData];
        [self metaDataChanged: self.configuration.config];
        [self metaDataChanged: self.state];
        g_bugsnag_data.onCrash = (void (*)(const KSCrashReportWriter *))self.configuration.onCrashHandler;
    }

    return self;
}

- (void) start {
    [KSCrash sharedInstance].sink = [[BugsnagSink alloc] init];
    // We don't use this feature yet, so we turn it off
    [KSCrash sharedInstance].introspectMemory = NO;
    [KSCrash sharedInstance].deleteBehaviorAfterSendAll = KSCDeleteOnSucess;
    [KSCrash sharedInstance].onCrash = &BSSerializeDataCrashHandler;

    if (configuration.autoNotify) {
        [[KSCrash sharedInstance] install];
    }

    [self performSelectorInBackground:@selector(sendPendingReports) withObject:nil];
    [self updateAutomaticBreadcrumbDetectionSettings];
#if TARGET_OS_TV
  [self.details setValue:@"tvOS Bugsnag Notifier" forKey:@"name"];
#elif TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
  [self.details setValue:@"iOS Bugsnag Notifier" forKey:@"name"];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(batteryChanged:)
             name:UIDeviceBatteryStateDidChangeNotification
           object:nil];
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(batteryChanged:)
             name:UIDeviceBatteryLevelDidChangeNotification
           object:nil];
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(orientationChanged:)
             name:UIDeviceOrientationDidChangeNotification
           object:nil];
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(lowMemoryWarning:)
             name:UIApplicationDidReceiveMemoryWarningNotification
           object:nil];

  [UIDevice currentDevice].batteryMonitoringEnabled = YES;
  [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];

  [self batteryChanged:nil];
  [self orientationChanged:nil];
#elif TARGET_OS_MAC
  [self.details setValue:@"OSX Bugsnag Notifier" forKey:@"name"];
#endif
}

- (void)notifyError:(NSError *)error block:(void (^)(BugsnagCrashReport *))block {
    [self notify:NSStringFromClass([error class])
         message:error.localizedDescription
           block:^(BugsnagCrashReport * _Nonnull report) {
               NSMutableDictionary *metadata = [report.metaData mutableCopy];
               metadata[@"nserror"] = @{@"code": @(error.code),
                                        @"domain": error.domain,
                                        @"reason": error.localizedFailureReason?: @"" };
               report.metaData = metadata;
               if (block)
                   block(report);
           }];
}

- (void)notifyException:(NSException *)exception
                  block:(void (^)(BugsnagCrashReport *))block {
    [self notify:exception.name ?: NSStringFromClass([exception class])
         message:exception.reason
           block:block];
}

- (void)notify:(NSString *)exceptionName
       message:(NSString *)message
         block:(void (^)(BugsnagCrashReport *))block {
    BugsnagCrashReport *report = [[BugsnagCrashReport alloc] initWithErrorName:exceptionName
                                                                  errorMessage:message
                                                                 configuration:self.configuration
                                                                      metaData:[self.configuration.metaData toDictionary]
                                                                      severity:BSGSeverityWarning];
    if (block)
        block(report);

    [self.metaDataLock lock];
    BSSerializeJSONDictionary(report.metaData, &g_bugsnag_data.metaDataJSON);
    BSSerializeJSONDictionary(report.overrides, &g_bugsnag_data.userOverridesJSON);
    [self.state addAttribute:BSAttributeSeverity withValue:BSGFormatSeverity(report.severity) toTabWithName:BSTabCrash];
    [self.state addAttribute:BSAttributeDepth withValue:@(report.depth + 3) toTabWithName:BSTabCrash];
    [[KSCrash sharedInstance] reportUserException:report.errorClass ?: NSStringFromClass([NSException class])
                                           reason:report.errorMessage ?: @""
                                         language:NULL lineOfCode:@""
                                       stackTrace:@[]
                                 terminateProgram:NO];
    // Restore metaData to pre-crash state.
    [self.metaDataLock unlock];
    [self metaDataChanged:self.configuration.metaData];
    [[self state] clearTab:BSTabCrash];
    [Bugsnag leaveBreadcrumbWithBlock:^(BugsnagBreadcrumb * _Nonnull crumb) {
      crumb.type = BSGBreadcrumbTypeError;
      crumb.name = exceptionName;
    }];

    [self performSelectorInBackground:@selector(sendPendingReports) withObject:nil];
}

- (void) serializeBreadcrumbs {
    BugsnagBreadcrumbs* crumbs = self.configuration.breadcrumbs;
    NSArray* arrayValue = crumbs.count == 0 ? nil : [crumbs arrayValue];
    [self.state addAttribute:BSAttributeBreadcrumbs withValue:arrayValue toTabWithName:BSTabCrash];
}

- (void) sendPendingReports {
    @autoreleasepool {
        @try {
            [[KSCrash sharedInstance] sendAllReportsWithCompletion:^(NSArray *filteredReports, BOOL completed, NSError *error) {
                if (error)
                    NSLog(@"Failed to send Bugsnag reports: %@", error);
                else if (filteredReports.count > 0)
                    NSLog(@"Bugsnag reports sent.");
            }];
        }
        @catch (NSException* e) {
            NSLog(@"Error sending report to Bugsnag: %@", e);
        }
    }
}

- (void) metaDataChanged:(BugsnagMetaData *)metaData {

    if (metaData == self.configuration.metaData) {
        if ([self.metaDataLock tryLock]) {
            BSSerializeJSONDictionary([metaData toDictionary], &g_bugsnag_data.metaDataJSON);
            [self.metaDataLock unlock];
        }
    } else if (metaData == self.configuration.config) {
        BSSerializeJSONDictionary([metaData getTab:BSTabConfig], &g_bugsnag_data.configJSON);
    } else if (metaData == self.state) {
        BSSerializeJSONDictionary([metaData toDictionary], &g_bugsnag_data.stateJSON);
    } else {
        NSLog(@"Unknown metadata dictionary changed");
    }
}

#if TARGET_OS_TV
#elif TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
- (void)batteryChanged:(NSNotification *)notif {
  NSNumber *batteryLevel =
      [NSNumber numberWithFloat:[UIDevice currentDevice].batteryLevel];
  NSNumber *charging =
      [NSNumber numberWithBool:[UIDevice currentDevice].batteryState ==
                               UIDeviceBatteryStateCharging];

  [[self state] addAttribute:@"batteryLevel"
                   withValue:batteryLevel
               toTabWithName:@"deviceState"];
  [[self state] addAttribute:@"charging"
                   withValue:charging
               toTabWithName:@"deviceState"];
}

- (void)orientationChanged:(NSNotification *)notif {
  NSString *orientation;
  switch ([UIDevice currentDevice].orientation) {
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
  [[self state] addAttribute:@"orientation"
                   withValue:orientation
               toTabWithName:@"deviceState"];
  if ([self.configuration automaticallyCollectBreadcrumbs]) {
    [Bugsnag leaveBreadcrumbWithBlock:^(BugsnagBreadcrumb *_Nonnull breadcrumb) {
      breadcrumb.type = BSGBreadcrumbTypeState;
      breadcrumb.name = [self breadcrumbNameForNotificationName:notif.name];
      breadcrumb.metadata = @{ @"orientation" : orientation };
    }];
  }
}

- (void)lowMemoryWarning:(NSNotification *)notif {
  [[self state] addAttribute:BSEventLowMemoryWarning
                   withValue:[[Bugsnag payloadDateFormatter]
                                 stringFromDate:[NSDate date]]
               toTabWithName:@"deviceState"];
  if ([self.configuration automaticallyCollectBreadcrumbs]) {
    [self sendBreadcrumbForNotification:notif];
  }
}
#endif

- (void)updateAutomaticBreadcrumbDetectionSettings {
    if ([self.configuration automaticallyCollectBreadcrumbs]) {
        for (NSString *name in [self automaticBreadcrumbStateEvents]) {
            [self crumbleNotification:name];
        }
        for (NSString *name in [self automaticBreadcrumbControlEvents]) {
            [[NSNotificationCenter defaultCenter]
             addObserver:self
             selector:@selector(sendBreadcrumbForControlNotification:)
             name:name
             object:nil];
        }
        for (NSString *name in [self automaticBreadcrumbMenuItemEvents]) {
            [[NSNotificationCenter defaultCenter]
             addObserver:self
             selector:@selector(sendBreadcrumbForMenuItemNotification:)
             name:name
             object:nil];
        }
    } else {
        NSArray* eventNames = [[[self automaticBreadcrumbStateEvents]
          arrayByAddingObjectsFromArray:[self automaticBreadcrumbControlEvents]]
          arrayByAddingObjectsFromArray:[self automaticBreadcrumbMenuItemEvents]];
        for (NSString *name in eventNames) {
            [[NSNotificationCenter defaultCenter] removeObserver:self
                                                            name:name
                                                          object:nil];
        }
    }
}

- (NSArray <NSString *>*)automaticBreadcrumbStateEvents {
#if TARGET_OS_TV
    return @[NSUndoManagerDidUndoChangeNotification,
             NSUndoManagerDidRedoChangeNotification,
             UIWindowDidBecomeVisibleNotification,
             UIWindowDidBecomeHiddenNotification,
             UIWindowDidBecomeKeyNotification,
             UIWindowDidResignKeyNotification,
             UIScreenBrightnessDidChangeNotification,
             UITableViewSelectionDidChangeNotification];
#elif TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
    return @[UIWindowDidBecomeHiddenNotification,
             UIWindowDidBecomeVisibleNotification,
             UIApplicationWillTerminateNotification,
             UIApplicationWillEnterForegroundNotification,
             UIApplicationDidEnterBackgroundNotification,
             UIApplicationUserDidTakeScreenshotNotification,
             UIKeyboardDidShowNotification,
             UIKeyboardDidHideNotification,
             UIMenuControllerDidShowMenuNotification,
             UIMenuControllerDidHideMenuNotification,
             NSUndoManagerDidUndoChangeNotification,
             NSUndoManagerDidRedoChangeNotification,
             UITableViewSelectionDidChangeNotification];
#elif TARGET_OS_MAC
    return @[NSApplicationDidBecomeActiveNotification,
             NSApplicationDidResignActiveNotification,
             NSApplicationDidHideNotification,
             NSApplicationDidUnhideNotification,
             NSApplicationWillTerminateNotification,
             NSWorkspaceScreensDidSleepNotification,
             NSWorkspaceScreensDidWakeNotification,
             NSWindowWillCloseNotification,
             NSWindowDidBecomeKeyNotification,
             NSWindowWillMiniaturizeNotification,
             NSWindowDidEnterFullScreenNotification,
             NSWindowDidExitFullScreenNotification,
             NSTableViewSelectionDidChangeNotification];
#else
    return nil;
#endif
}

- (NSArray <NSString *>*)automaticBreadcrumbControlEvents {
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
    return @[UITextFieldTextDidBeginEditingNotification,
             UITextViewTextDidBeginEditingNotification,
             UITextFieldTextDidEndEditingNotification,
             UITextViewTextDidEndEditingNotification];
#elif TARGET_OS_MAC
    return @[NSControlTextDidBeginEditingNotification,
             NSControlTextDidEndEditingNotification];
#else
    return nil;
#endif
}

- (NSArray <NSString *>*)automaticBreadcrumbMenuItemEvents {
#if TARGET_OS_TV
    return @[];
#elif TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
    return nil;
#elif TARGET_OS_MAC
    return @[NSMenuWillSendActionNotification];
#else
    return nil;
#endif
}

- (void)crumbleNotification:(NSString *)notificationName {
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(sendBreadcrumbForNotification:)
             name:notificationName
           object:nil];
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)sendBreadcrumbForNotification:(NSNotification *)note {
  [Bugsnag leaveBreadcrumbWithBlock:^(BugsnagBreadcrumb *_Nonnull breadcrumb) {
    breadcrumb.type = BSGBreadcrumbTypeState;
    breadcrumb.name = [self breadcrumbNameForNotificationName:note.name];
  }];
  [self serializeBreadcrumbs];
}

- (void)sendBreadcrumbForMenuItemNotification:(NSNotification *)notif {
#if TARGET_OS_TV
#elif TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
#elif TARGET_OS_MAC
    NSMenuItem *menuItem = [[notif userInfo] valueForKey:@"MenuItem"];
    if ([menuItem isKindOfClass:[NSMenuItem class]]) {
        [Bugsnag
         leaveBreadcrumbWithBlock:^(BugsnagBreadcrumb *_Nonnull breadcrumb) {
             breadcrumb.type = BSGBreadcrumbTypeState;
             breadcrumb.name = [self breadcrumbNameForNotificationName:notif.name];
             if (menuItem.title.length > 0)
                 breadcrumb.metadata = @{ @"action" : menuItem.title };
         }];
    }
#endif
}

- (void)sendBreadcrumbForControlNotification:(NSNotification *)note {
#if TARGET_OS_TV
#elif TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
    UIControl* control = note.object;
    [Bugsnag leaveBreadcrumbWithBlock:^(BugsnagBreadcrumb *_Nonnull breadcrumb) {
        breadcrumb.type = BSGBreadcrumbTypeUser;
        breadcrumb.name = [self breadcrumbNameForNotificationName:note.name];
        NSString *label = control.accessibilityLabel;
        if (label.length > 0) {
            breadcrumb.metadata = @{ @"label": label };
        }
    }];
#elif TARGET_OS_MAC
    NSControl *control = note.object;
    [Bugsnag leaveBreadcrumbWithBlock:^(BugsnagBreadcrumb *_Nonnull breadcrumb) {
        breadcrumb.type = BSGBreadcrumbTypeUser;
        breadcrumb.name = [self breadcrumbNameForNotificationName:note.name];
        NSString *label = control.accessibilityLabel;
        if (label.length > 0) {
            breadcrumb.metadata = @{ @"label": label };
        }
    }];
#endif
}

- (NSString *)breadcrumbNameForNotificationName:(NSString *)name {
  return [name stringByReplacingOccurrencesOfString:@"Notification"
                                         withString:@""];
}

@end

