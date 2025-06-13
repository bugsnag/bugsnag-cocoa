//
//  BSGEventUploadKSCrashReportOperation.m
//  Bugsnag
//
//  Created by Nick Dowell on 17/02/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "BSGEventUploadKSCrashReportOperation.h"

#import "BSGInternalErrorReporter.h"
#import "BSGJSONSerialization.h"
#import "KSCrashReportFields.h"
#import "KSDate.h"
#import "BSG_RFC3339DateTool.h"
#import "BugsnagAppWithState.h"
#import "BugsnagCollections.h"
#import "BugsnagConfiguration.h"
#import "BugsnagEvent+Private.h"
#import "BugsnagLogger.h"


/// Returns a list of the crash report keys present in the valid portion of the JSON data
static NSArray * CrashReportKeys(NSData *data, NSError *error) {
    NSString *description = error.userInfo[NSDebugDescriptionErrorKey]; 
    for (NSString *separator in @[@" around character ", @"around line 1, column "]) {
        if ([description containsString:separator]) {
            NSUInteger end = (NSUInteger)[description componentsSeparatedByString:separator].lastObject.intValue;
            if (!end) {
                return nil;
            }
            NSData *subdata = [data subdataWithRange:NSMakeRange(0, end)];
            if (!subdata) {
                return nil;
            }
            NSString *string = [[NSString alloc] initWithData:subdata encoding:NSUTF8StringEncoding];
            if (!string) {
                return nil;
            }
            NSMutableArray *keys = [NSMutableArray array];
            NSString *pattern = @"\"(report|process|system|binary_images|crash|threads|error|user|config|metaData|state|breadcrumbs|featureFlags)\":";
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
            for (NSTextCheckingResult *result in [regex matchesInString:string options:0 range:NSMakeRange(0, string.length)]) {
                if ([result numberOfRanges] == 2) {
                    [keys addObject:[string substringWithRange:[result rangeAtIndex:1]]];
                }
            }
            return keys;
        }
    }
    return nil;
}


BSG_OBJC_DIRECT_MEMBERS
@implementation BSGEventUploadKSCrashReportOperation

- (BugsnagEvent *)loadEventAndReturnError:(NSError * __autoreleasing *)errorPtr {
    __block NSError *error = nil;
    
    void (^ reportError)(NSString *, NSData *) = ^(NSString *context, NSData *data) {
        NSMutableDictionary *diagnostics = [NSMutableDictionary dictionary];
        diagnostics[@"fileName"] = self.file.lastPathComponent;
        diagnostics[@"errorInfo"] = error.userInfo;
        
        NSDictionary *fileAttributes = [NSFileManager.defaultManager attributesOfItemAtPath:self.file error:nil];
        diagnostics[@"fileAttributes"] = fileAttributes;
        
        NSDate *creationDate = fileAttributes.fileCreationDate;
        NSDate *modificationDate = fileAttributes.fileModificationDate;
        if (creationDate && modificationDate) {
            // The amount of time spent writing the file could indicate why the process never completed
            diagnostics[@"modificationInterval"] = @([modificationDate timeIntervalSinceDate:creationDate]);
        }
        
        if (data && error.domain == NSCocoaErrorDomain && error.code == NSPropertyListReadCorruptError) {
            diagnostics[@"keys"] = CrashReportKeys(data, error);
        }
        
        [BSGInternalErrorReporter.sharedInstance
         reportErrorWithClass:@"Invalid crash report" context:context message:BSGErrorDescription(error) diagnostics:diagnostics];
    };
    
    NSData *data = [NSData dataWithContentsOfFile:self.file options:0 error:&error];
    if (!data) {
        if (!(error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError)) {
            reportError(@"File could not be read", nil);
        }
        if (errorPtr) {
            *errorPtr = error;
        }
        return nil;
    }
    
    NSDictionary *json = BSGJSONDictionaryFromData(data, 0, &error);
    if (!json) {
        if (errorPtr) {
            *errorPtr = error;
        }
        
        if (!data.length || !data.bytes) {
            reportError(@"File is empty", nil);
            return nil;
        }
        
        if (((const char *)data.bytes)[0] != '{') {
            reportError(@"Does not start with \"{\"", nil);
            return nil;
        }
        
        if (((const char *)data.bytes)[data.length - 1] != '}') {
            reportError(@"Does not end with \"}\"", data);
            return nil;
        }
        
        reportError(@"JSON parsing error", data);
        return nil;
    }
    
    NSDictionary *crashReport = [self fixupCrashReport:json];
    if (!crashReport) {
        return nil;
    }
    
    BugsnagEvent *event = [[BugsnagEvent alloc] initWithKSReport:crashReport];
    if (!event) {
        reportError(@"Invalid JSON payload", nil);
    }
    
    if (!event.app.type) {
        // Use current value for crashes from older notifier versions that didn't persist config.appType
        event.app.type = self.delegate.configuration.appType;
    }
    
    return event;
}

// Methods below were copied from KSCrashReportStore.m

- (NSMutableDictionary *)fixupCrashReport:(NSDictionary *)report {
    NSMutableDictionary *mutableReport = [report mutableCopy];
    NSMutableDictionary *mutableInfo =
            [report[KSCrashField_Report] mutableCopy];
    mutableReport[KSCrashField_Report] = mutableInfo;

    // Timestamp gets stored as a microseconds timestamp. Convert it to rfc3339.
    NSNumber *timestampMicros = mutableInfo[KSCrashField_Timestamp];
    if ([timestampMicros isKindOfClass:[NSNumber class]]) {
        char dateBuffer[29];
        ksdate_utcStringFromMicroseconds(timestampMicros.longLongValue, dateBuffer);
        NSString *dateStr = [NSString stringWithUTF8String:dateBuffer];
        // we are changing format a little
        NSDate *date = [BSG_RFC3339DateTool dateFromString:dateStr];
        mutableInfo[KSCrashField_Timestamp] = [BSG_RFC3339DateTool stringFromDate:date];
    } else {
        [self convertTimestamp:KSCrashField_Timestamp inReport:mutableInfo];
    }

    NSMutableDictionary *crashReport =
            [report[KSCrashField_Crash] mutableCopy];
    mutableReport[KSCrashField_Crash] = crashReport;

    return mutableReport;
}

- (void)mergeDictWithKey:(NSString *)srcKey
         intoDictWithKey:(NSString *)dstKey
                inReport:(NSMutableDictionary *)report {
    NSDictionary *srcDict = report[srcKey];
    if (srcDict == nil) {
        // It's OK if the source dict didn't exist.
        return;
    }

    NSDictionary *dstDict = report[dstKey];
    if (dstDict == nil) {
        dstDict = @{};
    }
    if (![dstDict isKindOfClass:[NSDictionary class]]) {
        bsg_log_err(@"'%@' should be a dictionary, not %@", dstKey,
                [dstDict class]);
        return;
    }

    report[dstKey] = BSGDictMerge(srcDict, dstDict);
    [report removeObjectForKey:srcKey];
}

- (void)convertTimestamp:(NSString *)key
                inReport:(NSMutableDictionary *)report {
    NSNumber *timestamp = report[key];
    if (timestamp == nil) {
        bsg_log_err(@"entry '%@' not found", key);
        return;
    }
    [report
            setValue:[BSG_RFC3339DateTool
                    stringFromUNIXTimestamp:[timestamp doubleValue]]
              forKey:key];
}

@end
