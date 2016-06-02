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
#import "BugsnagSink.h"

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#include <sys/utsname.h>
#endif

NSString *const NOTIFIER_VERSION = @"5.2.0";
NSString *const NOTIFIER_URL = @"https://github.com/bugsnag/bugsnag-cocoa";
NSString *const BSTabCrash = @"crash";
NSString *const BSTabConfig = @"config";
NSString *const BSAttributeSeverity = @"severity";
NSString *const BSAttributeDepth = @"depth";
NSString *const BSAttributeBreadcrumbs = @"breadcrumbs";

struct bugsnag_data_t {
    // Contains the user-specified metaData, including the user tab from config.
    char *metaDataJSON;
    // Contains the Bugsnag configuration, all under the "config" tab.
    char *configJSON;
    // Contains notifier state, under "deviceState" and crash-specific information under "crash".
    char *stateJSON;
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

@interface NSDictionary (BSGKSMerge)
- (NSDictionary*)BSG_mergedInto:(NSDictionary *)dest;
@end

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

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
  [self.details setValue: @"iOS Bugsnag Notifier" forKey:@"name"];

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryChanged:) name:UIDeviceBatteryStateDidChangeNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryChanged:) name:UIDeviceBatteryLevelDidChangeNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(lowMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];

  [UIDevice currentDevice].batteryMonitoringEnabled = TRUE;
  [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];

  [self batteryChanged:nil];
  [self orientationChanged:nil];
#elif TARGET_OS_MAC
  [self.details setValue: @"OSX Bugsnag Notifier" forKey:@"name"];
#endif
}

- (void)notify:(NSException *)exception withData:(NSDictionary *)metaData atSeverity:(NSString *)severity atDepth:(NSUInteger) depth {

    if (!metaData) {
        metaData = [[NSDictionary alloc] init];
    }
    metaData = [metaData BSG_mergedInto: [self.configuration.metaData toDictionary]];
    if (!severity) {
        severity = BugsnagSeverityWarning;
    }

    [self.metaDataLock lock];
    BSSerializeJSONDictionary(metaData, &g_bugsnag_data.metaDataJSON);
    [self.state addAttribute:BSAttributeSeverity withValue:severity toTabWithName:BSTabCrash];
    [self.state addAttribute:BSAttributeDepth withValue:@(depth + 3) toTabWithName:BSTabCrash];
    NSString *exceptionName = [exception name] ?: NSStringFromClass([NSException class]);
    [[KSCrash sharedInstance] reportUserException:exceptionName reason:[exception reason] language:NULL lineOfCode:@"" stackTrace:@[] terminateProgram:NO];

    // Restore metaData to pre-crash state.
    [self.metaDataLock unlock];
    [self metaDataChanged: self.configuration.metaData];
    [[self state] clearTab:BSTabCrash];

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
                if (filteredReports.count > 0)
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

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
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
  [[self state] addAttribute: @"lowMemoryWarning" withValue: [[Bugsnag payloadDateFormatter] stringFromDate:[NSDate date]] toTabWithName:@"deviceState"];
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}
#endif

@end

//
//  NSDictionary+Merge.m
//
//  Created by Karl Stenerud on 2012-10-01.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
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

@implementation NSDictionary (BSGKSMerge)

- (NSDictionary*)BSG_mergedInto:(NSDictionary *)dest
{
  if([dest count] == 0)
  {
    return self;
  }
  if([self count] == 0)
  {
    return dest;
  }

  NSMutableDictionary* dict = [dest mutableCopy];
  for(id key in [self allKeys])
  {
    id srcEntry = [self objectForKey:key];
    id dstEntry = [dest objectForKey:key];
    if([dstEntry isKindOfClass:[NSDictionary class]] &&
       [srcEntry isKindOfClass:[NSDictionary class]])
    {
      srcEntry = [srcEntry BSG_mergedInto:dstEntry];
    }
    [dict setObject:srcEntry forKey:key];
  }
  return dict;
}

@end
