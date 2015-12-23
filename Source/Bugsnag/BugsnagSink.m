//
//  BugsnagSink.m
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

#import "BugsnagSink.h"
#import "BugsnagNotifier.h"
#import "Bugsnag.h"
#import "BugsnagCrashReport.h"

#import "KSSafeCollections.h"
#import "KSJSONCodecObjC.h"

// This is private in Bugsnag, but really we want package private so define
// it here.
@interface Bugsnag ()
+ (BugsnagNotifier*)notifier;
@end

@implementation BugsnagSink

// Entry point called by KSCrash when a report needs to be sent. Handles report filtering based on the configuration
// options for `notifyReleaseStages`.
// Removes all reports not meeting at least one of the following conditions:
// - the report-specific config specifies the `notifyReleaseStages` property and it contains the current stage
// - the report-specific and global `notifyReleaseStages` properties are unset
// - the report-specific `notifyReleaseStages` property is unset and the global `notifyReleaseStages` property
//   and it contains the current stage
- (void) filterReports:(NSArray*) reports onCompletion:(KSCrashReportFilterCompletion) onCompletion
{
    NSError *error = nil;
    NSMutableArray *bugsnagReports = [NSMutableArray arrayWithCapacity:[reports count]];
    BugsnagConfiguration *configuration = [Bugsnag configuration];
    BOOL configuredShouldNotify = configuration.notifyReleaseStages.count == 0
        || [configuration.notifyReleaseStages containsObject:configuration.releaseStage];
    for (NSDictionary* report in reports) {
        BugsnagCrashReport *bugsnagReport = [[BugsnagCrashReport alloc] initWithKSReport:report];
        
        // Filter the reports here, we have to do it now as we dont want to hack KSCrash to do it at crash time.
        // We also in the docs imply that the filtering happens when the crash happens - so we use the values
        // saved in the report.
        BOOL shouldNotify = [bugsnagReport.notifyReleaseStages containsObject:bugsnagReport.releaseStage]
            || (bugsnagReport.notifyReleaseStages.count == 0 && configuredShouldNotify);
        if(shouldNotify) {
            [bugsnagReports addObject:bugsnagReport];
        }
    }
    
    if (bugsnagReports.count == 0) {
        if (onCompletion) {
            onCompletion(reports, YES, nil);
        }
        return;
    }
    
    
    NSData* jsonData = [KSJSONCodec encode:[self getBodyFromReports: bugsnagReports]
                                   options:KSJSONEncodeOptionSorted | KSJSONEncodeOptionPretty
                                     error:&error];
    
    if (jsonData == nil) {
        if (onCompletion) {
            onCompletion(reports, NO, error);
        }
        return;
    }
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL: configuration.notifyURL
                                                           cachePolicy: NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval: 15];
    request.HTTPMethod = @"POST";
    request.HTTPBody = jsonData;

#pragma clang diagnostic push
#pragma clang diaginostic ignored "-Wdeprecated-declarations"
    [NSURLConnection sendSynchronousRequest:request
                          returningResponse:NULL
                                      error:&error];
#pragma clang diagnostic pop
    
    if (onCompletion) {
        onCompletion(reports, error == nil, error);
    }
}

// Generates the payload for notifying Bugsnag
- (NSDictionary*) getBodyFromReports:(NSArray*) reports {
    NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
    
    [data safeSetObject: [Bugsnag configuration].apiKey forKey: @"apiKey"];
    [data safeSetObject: [Bugsnag notifier].details forKey: @"notifier"];
    
    NSMutableArray* formatted = [[NSMutableArray alloc] initWithCapacity:[reports count]];
    
    for (BugsnagCrashReport* report in reports) {
        [formatted safeAddObject:[self formatEvent:report forData: data]];
    }
    
    [data safeSetObject: formatted forKey:@"events"];
    
    return data;
}

// Generates the "event" portion of the Bugsnag payload
- (NSDictionary*) formatEvent:(BugsnagCrashReport*) report forData: (NSMutableDictionary*) data {
    NSMutableDictionary* event = [NSMutableDictionary dictionary];
    NSMutableDictionary* exception = [NSMutableDictionary dictionary];
    NSMutableArray *bugsnagThreads = [NSMutableArray array];
    NSMutableDictionary *metaData = [report.metaData mutableCopy];
    
    // Build Event
    [event safeSetObject: bugsnagThreads forKey: @"threads"];
    [event safeSetObject: @[exception] forKey: @"exceptions"];
    [event setObjectIfNotNil: report.dsymUUID forKey: @"dsymUUID"];
    [event safeSetObject: report.severity forKey:@"severity"];
    [event safeSetObject: report.breadcrumbs forKey:@"breadcrumbs"];
    [event safeSetObject: @"2" forKey:@"payloadVersion"];
    [event safeSetObject: metaData forKey: @"metaData"];
    [event safeSetObject: [self deviceStateFromReport: report] forKey:@"deviceState"];
    [event safeSetObject: [self deviceFromReport: report] forKey:@"device"];
    [event safeSetObject: [self appStateFromReport: report] forKey:@"appState"];
    [event safeSetObject: [self appFromReport: report] forKey:@"app"];

    if ([[metaData objectForKey: @"context"] isKindOfClass: [NSString class]]) {
        [event safeSetObject: [metaData objectForKey: @"context"] forKey: @"context"];
        [metaData removeObjectForKey: @"context"];

    } else {
        [event safeSetObject: report.context forKey:@"context"];
    }
    
    //  Build MetaData
    [metaData safeSetObject: report.error forKey:@"error"];
    
    // Make user mutable and set the id if the user hasn't already
    NSMutableDictionary* user = [[metaData objectForKey:@"user"] mutableCopy];
    if(user == nil) user = [NSMutableDictionary dictionary];
    [metaData safeSetObject:user forKey:@"user"];
    
    if (![user objectForKey:@"id"]) {
        [user safeSetObject: report.deviceAppHash forKey:@"id"];
    }

    // Build Exception
    [exception safeSetObject: report.errorClass forKey: @"errorClass"];
    [exception setObjectIfNotNil: report.errorMessage forKey: @"message"];

    // HACK: For the Unity Notifier. We don't include ObjectiveC exceptions or threads
    // if this is an exception from Unity-land.
    NSDictionary *unityReport = [metaData objectForKey:@"_bugsnag_unity_exception"];
    if (unityReport) {
        [data safeSetObject: [unityReport objectForKey:@"notifier"] forKey: @"notifier"];
        [exception safeSetObject: [unityReport objectForKey: @"stacktrace"] forKey: @"stacktrace"];
        [metaData removeObjectForKey:@"_bugsnag_unity_exception"];
        return event;
    }

    // Build all stacktraces for threads and the error
    for (NSDictionary* thread in report.threads) {
        NSArray* backtrace = [[thread objectForKey: @"backtrace"] objectForKey: @"contents"];
        BOOL stackOverflow = [[[thread objectForKey: @"stack"] objectForKey: @"overflow"] boolValue];

        if ([(NSNumber*)[thread objectForKey: @"crashed"] boolValue]) {
            NSUInteger seen = 0;
            NSMutableArray* stacktrace = [NSMutableArray array];

            for (NSDictionary* frame in backtrace) {
                NSMutableDictionary *mutableFrame = [frame mutableCopy];
                if (seen++ >= report.depth) {
                    // Mark the frame so we know where it came from
                    if(seen == 1 && !stackOverflow) {
                        [mutableFrame safeSetObject:[NSNumber numberWithBool:YES] forKey:@"isPC"];
                    }
                    if(seen == 2 && !stackOverflow && [@[@"signal", @"deadlock", @"mach"] containsObject:report.errorType]) {
                        [mutableFrame safeSetObject:[NSNumber numberWithBool:YES] forKey:@"isLR"];
                    }
                    [stacktrace addObjectIfNotNil: [self formatFrame: mutableFrame withBinaryImages: report.binaryImages]];
                }
            }
            
            [exception safeSetObject: stacktrace forKey: @"stacktrace"];
        } else {

            NSMutableArray* threadStack = [NSMutableArray array];

            for (NSDictionary* frame in backtrace) {
                [threadStack addObjectIfNotNil: [self formatFrame: frame withBinaryImages: report.binaryImages]];
            }

            NSMutableDictionary *threadDict = [NSMutableDictionary dictionary];
            [threadDict safeSetObject: [thread objectForKey: @"index"] forKey: @"id"];
            [threadDict safeSetObject: threadStack forKey: @"stacktrace"];
            // only if this is enabled in KSCrash.
            if ([thread objectForKey: @"name"]) {
                [threadDict safeSetObject:[thread objectForKey: @"name"] forKey:@"name"];
            }

            [bugsnagThreads safeAddObject: threadDict];
        }
    }
    return event;
}

// Generates the deviceState section of the payload
- (NSDictionary*) deviceStateFromReport: (BugsnagCrashReport*)report
{
    NSMutableDictionary* deviceState = [[report.state objectForKey:@"deviceState"] mutableCopy];

    [deviceState safeSetObject:[[report.system objectForKey:@"memory"] objectForKey:@"free" ] forKey: @"freeMemory"];
    
    return deviceState;
}

// Generates the device section of the payload
- (NSDictionary*) deviceFromReport: (BugsnagCrashReport*)report
{
    NSMutableDictionary* device = [NSMutableDictionary dictionary];

    [device safeSetObject: @"Apple" forKey: @"manufacturer"];
    [device safeSetObject: [[NSLocale currentLocale] localeIdentifier] forKey: @"locale"];
    [device safeSetObject: [report.system objectForKey:@"device_app_hash"] forKey: @"id"];
    [device safeSetObject: [report.system objectForKey:@"time_zone"] forKey: @"timezone"];
    [device safeSetObject: [report.system objectForKey:@"model"] forKey: @"modelNumber"];
    [device safeSetObject: [report.system objectForKey:@"machine"] forKey: @"model"];
    [device safeSetObject: [report.system objectForKey:@"system_name"] forKey: @"osName"];
    [device safeSetObject: [report.system objectForKey:@"system_version"] forKey: @"osVersion"];
    [device safeSetObject:[[report.system objectForKey:@"memory"] objectForKey:@"usable" ] forKey: @"totalMemory"];

    return device;
}

// Generates the appState section of the payload
- (NSDictionary*) appStateFromReport: (BugsnagCrashReport*)report
{
    NSMutableDictionary* appState = [NSMutableDictionary dictionary];

    NSInteger activeTimeSinceLaunch = [[report.appStats objectForKey: @"active_time_since_launch"] doubleValue] * 1000.0f;
    NSInteger backgroundTimeSinceLaunch = [[report.appStats objectForKey: @"background_time_since_launch"] doubleValue] * 1000.0f;

    [appState safeSetObject:[NSNumber numberWithDouble: activeTimeSinceLaunch] forKey:@"durationInForeground"];
    [appState safeSetObject: [NSNumber numberWithDouble:(activeTimeSinceLaunch + backgroundTimeSinceLaunch)] forKey: @"duration"];
    [appState safeSetObject: [report.appStats objectForKey: @"application_in_foreground"] forKey: @"inForeground"];
    [appState safeSetObject: report.appStats forKey: @"stats"];
    
    //[appState safeSetObject: forKey: @"activeScreen"];

    return appState;
}

// Generates the app section of the payload
- (NSDictionary*) appFromReport: (BugsnagCrashReport*)report
{
    NSMutableDictionary* app = [NSMutableDictionary dictionary];

    [app safeSetObject: [report.system objectForKey:@"CFBundleVersion"] forKey: @"bundleVersion"];
    [app safeSetObject: [report.system objectForKey:@"CFBundleIdentifier"] forKey: @"id"];
    [app safeSetObject: [report.system objectForKey:@"CFBundleExecutable"] forKey: @"name"];
    [app safeSetObject: [Bugsnag configuration].releaseStage forKey: @"releaseStage"];
    if (report.appVersion) {
        [app safeSetObject: report.appVersion forKey: @"version"];
    } else {
        [app safeSetObject: [report.system objectForKey:@"CFBundleShortVersionString"] forKey: @"version"];
    }

    return app;
}

// Formats a stackframe into the format that Bugsnag needs
- (NSMutableDictionary*) formatFrame: (NSDictionary*) frame withBinaryImages: (NSArray*) binaryImages
{
    NSMutableDictionary* formatted = [NSMutableDictionary dictionary];
    
    unsigned long instructionAddress = [[frame objectForKey: @"instruction_addr"] unsignedLongValue];
    unsigned long symbolAddress = [[frame objectForKey: @"symbol_addr"] unsignedLongValue];
    unsigned long imageAddress = [[frame objectForKey: @"object_addr"] unsignedLongValue];
    
    [formatted safeSetObject: [NSString stringWithFormat: @"0x%lx", instructionAddress] forKey: @"frameAddress"];
    [formatted safeSetObject: [NSString stringWithFormat: @"0x%lx", symbolAddress] forKey: @"symbolAddress"];
    [formatted safeSetObject: [NSString stringWithFormat: @"0x%lx", imageAddress] forKey: @"machoLoadAddress"];
    if([frame objectForKey:@"isPC"]) [formatted safeSetObject: [frame objectForKey:@"isPC"] forKey:@"isPC"];
    if([frame objectForKey:@"isLR"]) [formatted safeSetObject: [frame objectForKey:@"isLR"] forKey:@"isLR"];

    NSString *file = [frame objectForKey:@"object_name"];
    NSString *method = [frame objectForKey:@"symbol_name"];

    [formatted setObjectIfNotNil: file forKey: @"machoFile"];
    [formatted setObjectIfNotNil: method forKey: @"method"];
    
    for (NSDictionary *image in binaryImages) {
        if ([(NSNumber*)[image objectForKey:@"image_addr"] unsignedLongValue] == imageAddress) {
            unsigned long imageSlide = [[image objectForKey: @"image_vmaddr"] unsignedLongValue];

            [formatted setObjectIfNotNil: [image objectForKey:@"uuid"] forKey: @"machoUUID"];
            [formatted setObjectIfNotNil: [image objectForKey:@"name"] forKey: @"machoFile"];

            [formatted safeSetObject: [NSString stringWithFormat: @"0x%lx", imageSlide] forKey: @"machoVMAddress"];

            return formatted;
        }
    }
    
    return nil;
}
@end
