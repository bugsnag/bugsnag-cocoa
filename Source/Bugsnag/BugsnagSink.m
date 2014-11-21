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
#import "Bugsnag.h"

#import "KSSafeCollections.h"
#import "KSJSONCodecObjC.h"

@implementation BugsnagSink

- (NSDictionary*) getBodyFromReports:(NSArray*) reports
{
    NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
    
    [data safeSetObject: [Bugsnag configuration].apiKey forKey: @"apiKey"];
    [data safeSetObject: @{@"name": @"iOS Bugsnag Notifier",
                           @"version": @"4.0.0",
                           @"url": @"https://bugsnag.com/docs/notifiers/cocoa"} forKey: @"notifier"];
    
    NSMutableArray* formatted = [[NSMutableArray alloc] initWithCapacity:[reports count]];
    
    for (NSDictionary* report in reports) {
        [formatted safeAddObject:[self formatReport:report]];
    }
    
    [data safeSetObject: formatted forKey:@"events"];
    
    return data;
}

- (NSDictionary*) formatReport:(NSDictionary*) report {
    
    NSLog(@"%s", [[KSJSONCodec encode: report options:KSJSONEncodeOptionPretty error:nil] bytes]);

    NSMutableDictionary* formatted = [[NSMutableDictionary alloc] init];
    NSMutableDictionary* exception = [[NSMutableDictionary alloc] init];

    NSArray* binaryImages = [report objectForKey:@"binary_images"];
    NSDictionary* crash = [report objectForKey:@"crash"];
    NSDictionary* system = [report objectForKey:@"system"];
    
    NSMutableDictionary* metaData  = [NSMutableDictionary dictionaryWithDictionary:
                                      [[report objectForKey:@"user"] objectForKey:@"metaData"]];
    NSMutableDictionary* state = [NSMutableDictionary dictionaryWithDictionary:
                                  [[report objectForKey:@"user"] objectForKey:@"state"]];
    NSMutableDictionary* config = [NSMutableDictionary dictionaryWithDictionary:
                                   [[report objectForKey:@"user"] objectForKey:@"config"]];
    
    NSMutableDictionary* user = [NSMutableDictionary dictionaryWithDictionary: [metaData objectForKey:@"user"]];
    [metaData setObject:user forKey:@"user"];

    NSString* severity = [[state objectForKey:@"crash"] objectForKey:@"severity"];
    NSUInteger depth = [[[state objectForKey:@"crash"] objectForKey:@"depth"] unsignedIntegerValue];
    NSString *context = [config objectForKey:@"context"];


    if (![user objectForKey:@"id"]) {
        [user setObject: [system objectForKey:@"device_app_hash"] forKey:@"id"];
    }

    NSDictionary* error = [crash objectForKey:@"error"];
    NSString* errorType = [error objectForKey: @"type"];
    
    NSString* errorClass;
    NSString* message;

    NSString* dsymUUID = [system objectForKey:@"app_uuid"];

    if ([errorType isEqualToString: @"cpp_exception"]) {
        errorClass = [(NSDictionary*)[error objectForKey:@"cpp_exception"] objectForKey:@"name"];
    } else if ([errorType isEqualToString:@"mach"]) {
        errorClass = [(NSDictionary*)[error objectForKey:@"mach"] objectForKey:@"exception_name"];

        NSString* diagnosis = [crash objectForKey:@"diagnosis"];
        if (diagnosis && ![diagnosis hasPrefix:@"No diagnosis"]) {
            message = [[diagnosis componentsSeparatedByString:@"\n"] firstObject];
        }
    } else if ([errorType isEqualToString:@"signal"]) {
        errorClass = [(NSDictionary*)[error objectForKey:@"signal"] objectForKey:@"name"];

    } else if ([errorType isEqualToString:@"nsexception"]) {
        errorClass = [(NSDictionary*)[error objectForKey:@"nsexception"] objectForKey:@"name"];
    }

    if (errorClass != nil) {
        [exception safeSetObject: errorClass forKey: @"errorClass"];
    } else {
        [exception safeSetObject: @"Exception" forKey: @"errorClass"];
    }
    
    if (message == nil) {
        message = [error objectForKey:@"reason"];
    }

    [exception setObjectIfNotNil: message forKey: @"message"];
    [formatted setObjectIfNotNil: dsymUUID forKey: @"dsymUUID"];
    
    NSArray *threads = [crash objectForKey: @"threads"];
    NSMutableArray *bugsnagThreads = [[NSMutableArray alloc] init];

    NSMutableArray* stacktrace = [[NSMutableArray alloc] init];
    for (NSDictionary* thread in threads) {
        NSArray* backtrace = [(NSDictionary*)[thread objectForKey: @"backtrace"] objectForKey: @"contents"];

        if ([(NSNumber*)[thread objectForKey: @"crashed"] boolValue]) {
            
            NSUInteger seen = 0;

            for (NSDictionary* frame in backtrace) {
                if (seen++ >= depth) {
                    [stacktrace addObjectIfNotNil: [self formatFrame: frame withBinaryImages: binaryImages]];
                }
            }

        } else {

            NSMutableArray* threadStack = [[NSMutableArray alloc] init];

            for (NSDictionary* frame in backtrace) {
                NSDictionary* fmt = [self formatFrame: frame withBinaryImages: binaryImages];
                [threadStack addObjectIfNotNil: fmt];
            }

            NSMutableDictionary *threadDict = [[NSMutableDictionary alloc] init];
            [threadDict safeSetObject: [thread objectForKey: @"index"] forKey: @"id"];
            [threadDict safeSetObject: threadStack forKey: @"stacktrace"];
            // only if this is enabled in KSCrash.
            if ([thread objectForKey: @"name"]) {
                [threadDict safeSetObject:[thread objectForKey: @"name"] forKey:@"name"];
            }

            [bugsnagThreads safeAddObject: threadDict];
        }
    }

    [exception safeSetObject: stacktrace forKey: @"stacktrace"];
    [metaData safeSetObject: error forKey:@"error"];

    [formatted safeSetObject: @[exception] forKey: @"exceptions"];
    [formatted safeSetObject: metaData forKey: @"metaData"];
    [formatted safeSetObject: [self deviceStateFromSystem: system andState: state] forKey:@"deviceState"];
    [formatted safeSetObject: [self deviceFromSystem: system] forKey:@"device"];
    [formatted safeSetObject: [self appStateFromSystem: system] forKey:@"appState"];
    [formatted safeSetObject: [self appFromSystem: system] forKey:@"app"];
    [formatted safeSetObject: severity forKey:@"severity"];
    [formatted safeSetObject: @"2" forKey:@"payloadVersion"];

    if ([context isKindOfClass:[NSString class]]) {
        [formatted safeSetObject: context forKey:@"context"];
    }

    [formatted safeSetObject: bugsnagThreads forKey: @"threads"];

    return formatted;
}

- (NSDictionary*) deviceStateFromSystem: (NSDictionary*)system andState: (NSDictionary*) state
{
    NSMutableDictionary* deviceState = [NSMutableDictionary dictionaryWithDictionary: [state objectForKey:@"deviceState"]];

    [deviceState safeSetObject:[[system objectForKey:@"memory"] objectForKey:@"free" ] forKey: @"freeMemory"];
    
    //[deviceState safeSetObject: forKey: @"freeDisk"];
    //[deviceState safeSetObject: forKey: @"locationStatus"];
    //[deviceState safeSetObject: forKey: @"networkAccess"];

    return deviceState;
}

- (NSDictionary*) deviceFromSystem: (NSDictionary*)system
{
    NSMutableDictionary* device = [[NSMutableDictionary alloc] init];

    //[device safeSetObject: forKey: @"locale"];
    //[device safeSetObject: forKey: @"diskSize"];
    //[device safeSetObject: forKey: @"screenDensity"];
    //[device safeSetObject: forKey: @"screenResolution"];
    //[device safeSetObject: forKey: @"manufacturer"];

    [device safeSetObject: [system objectForKey:@"device_app_hash"] forKey: @"id"];
    [device safeSetObject: [system objectForKey:@"time_zone"] forKey: @"timezone"];
    [device safeSetObject: [system objectForKey:@"model"] forKey: @"model"];
    [device safeSetObject: [system objectForKey:@"system_name"] forKey: @"osName"];
    [device safeSetObject: [system objectForKey:@"system_version"] forKey: @"osVersion"];
    [device safeSetObject:[[system objectForKey:@"memory"] objectForKey:@"usable" ] forKey: @"totalMemory"];

    return device;
}

- (NSDictionary*) appStateFromSystem: (NSDictionary*)system
{
    NSMutableDictionary* appState = [[NSMutableDictionary alloc] init];

    NSDictionary* applicationStats = [system objectForKey:@"application_stats"];
    NSNumber* activeTimeSinceLaunch = [applicationStats objectForKey: @"active_time_since_launch"];
    NSNumber* backgroundTimeSinceLaunch = [applicationStats objectForKey: @"background_time_since_launch"];
    
    if (activeTimeSinceLaunch && backgroundTimeSinceLaunch) {
        [appState safeSetObject:[NSNumber numberWithDouble: [activeTimeSinceLaunch doubleValue] - [backgroundTimeSinceLaunch doubleValue]] forKey:@"durationInForeground"];
    }

    [appState safeSetObject: activeTimeSinceLaunch forKey: @"duration"];
    [appState safeSetObject: [applicationStats objectForKey: @"application_in_foreground"] forKey: @"inForeground"];
    [appState safeSetObject: applicationStats forKey: @"stats"];
    
    //[appState safeSetObject: forKey: @"activeScreen"];
    //[appState safeSetObject: forKey: @"memoryUsage"];

    return appState;
}

- (NSDictionary*) appFromSystem: (NSDictionary*)system
{
    NSMutableDictionary* app = [[NSMutableDictionary alloc] init];

    [app safeSetObject: [system objectForKey:@"CFBundleVersion"] forKey: @"bundleVersion"];
    [app safeSetObject: [system objectForKey:@"CFBundleIdentifier"] forKey: @"id"];
    [app safeSetObject: [system objectForKey:@"CFBundleExecutable"] forKey: @"name"];
    [app safeSetObject: [Bugsnag configuration].releaseStage forKey: @"releaseStage"];
    [app safeSetObject: [system objectForKey:@"CFBundleShortVersionString"] forKey: @"version"];

    return app;
}

- (NSMutableDictionary*) formatFrame: (NSDictionary*) frame withBinaryImages: (NSArray*) binaryImages
{
    NSMutableDictionary* formatted = [[NSMutableDictionary alloc] init];
    
    unsigned long instructionAddress = [(NSNumber*)[frame objectForKey: @"instruction_addr"] unsignedLongValue];
    unsigned long symbolAddress = [(NSNumber*)[frame objectForKey: @"symbol_addr"] unsignedLongValue];
    unsigned long imageAddress = [(NSNumber*)[frame objectForKey: @"object_addr"] unsignedLongValue];
    
    [formatted safeSetObject: [NSString stringWithFormat: @"0x%lx", instructionAddress] forKey: @"frameAddress"];
    [formatted safeSetObject: [NSString stringWithFormat: @"0x%lx", symbolAddress] forKey: @"symbolAddress"];
    [formatted safeSetObject: [NSString stringWithFormat: @"0x%lx", imageAddress] forKey: @"machoLoadAddress"];

    NSString *file = [frame objectForKey:@"object_name"];
    NSString *method = [frame objectForKey:@"symbol_name"];

    [formatted setObjectIfNotNil: file forKey: @"machoFile"];
    [formatted setObjectIfNotNil: method forKey: @"method"];
    
    for (NSDictionary *image in binaryImages) {
        if ([(NSNumber*)[image objectForKey:@"image_addr"] unsignedLongValue] == imageAddress) {
            unsigned long imageSlide = [(NSNumber*)[image objectForKey: @"image_vmaddr"] unsignedLongValue];

            [formatted setObjectIfNotNil: [image objectForKey:@"uuid"] forKey: @"machoUUID"];
            [formatted setObjectIfNotNil: [image objectForKey:@"name"] forKey: @"machoFile"];

            [formatted safeSetObject: [NSString stringWithFormat: @"0x%lx", imageSlide] forKey: @"machoVMAddress"];

            return formatted;
        }
    }
    
    return nil;
}

- (void) filterReports:(NSArray*) reports onCompletion:(KSCrashReportFilterCompletion) onCompletion
{
    NSError *error = nil;
    
    if ([Bugsnag configuration].notifyReleaseStages && ![[Bugsnag configuration].notifyReleaseStages containsObject: [Bugsnag configuration].releaseStage]) {
        if (onCompletion) {
            onCompletion(reports, YES, nil);
        }
        return;
    }


    NSData* jsonData = [KSJSONCodec encode:[self getBodyFromReports: reports]
                                   options:KSJSONEncodeOptionSorted | KSJSONEncodeOptionPretty
                                     error:&error];
    
    if (jsonData == nil) {
        if (onCompletion) {
            onCompletion(reports, NO, error);
            return;
        }
    }
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL: [Bugsnag configuration].notifyURL
                                                           cachePolicy: NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval: 15];
    request.HTTPMethod = @"POST";
    request.HTTPBody = jsonData;
    
    [NSURLConnection sendSynchronousRequest:request
                          returningResponse:NULL
                                      error:&error];
    
    if (onCompletion) {
        onCompletion(reports, error == nil, error);
    }
}
@end
