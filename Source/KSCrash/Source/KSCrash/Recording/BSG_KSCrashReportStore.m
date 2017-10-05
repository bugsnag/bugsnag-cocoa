//
//  BSG_KSCrashReportStore.m
//
//  Created by Karl Stenerud on 2012-02-05.
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

#import "BSG_KSCrashReportStore.h"

#import "BSG_KSCrashDoctor.h"
#import "BSG_KSCrashReportFields.h"
#import "BSG_KSCrashReportVersion.h"
#import "BSG_KSJSONCodecObjC.h"
#import "BSG_KSSafeCollections.h"
#import "BSG_RFC3339DateTool.h"
#import "NSDictionary+BSG_Merge.h"
#import "NSError+BSG_SimpleConstructor.h"

//#define BSG_KSLogger_LocalLevel TRACE
#import "BSG_KSLogger.h"

// ============================================================================
#pragma mark - Constants -
// ============================================================================

#define BSG_kCrashReportSuffix @"-CrashReport-"
#define BSG_kRecrashReportSuffix @"-RecrashReport-"

// ============================================================================
#pragma mark - Meta Data -
// ============================================================================

/**
 * Metadata class to hold name and creation date for a file, with
 * default comparison based on the creation date (ascending).
 */
@interface BSG_KSCrashReportInfo : NSObject

@property(nonatomic, readonly, retain) NSString *reportID;
@property(nonatomic, readonly, retain) NSDate *creationDate;

+ (BSG_KSCrashReportInfo *)reportInfoWithID:(NSString *)reportID
                               creationDate:(NSDate *)creationDate;

- (id)initWithID:(NSString *)reportID creationDate:(NSDate *)creationDate;

- (NSComparisonResult)compare:(BSG_KSCrashReportInfo *)other;

@end

@implementation BSG_KSCrashReportInfo

@synthesize reportID = _reportID;
@synthesize creationDate = _creationDate;

+ (BSG_KSCrashReportInfo *)reportInfoWithID:(NSString *)reportID
                               creationDate:(NSDate *)creationDate {
    return [[self alloc] initWithID:reportID creationDate:creationDate];
}

- (id)initWithID:(NSString *)reportID creationDate:(NSDate *)creationDate {
    if ((self = [super init])) {
        _reportID = reportID;
        _creationDate = creationDate;
    }
    return self;
}

- (NSComparisonResult)compare:(BSG_KSCrashReportInfo *)other {
    return [_creationDate compare:other->_creationDate];
}

@end

// ============================================================================
#pragma mark - Main Class -
// ============================================================================

@interface BSG_KSCrashReportStore ()

@property(nonatomic, readwrite, retain) NSString *path;
@property(nonatomic, readwrite, retain) NSString *bundleName;

@end

@implementation BSG_KSCrashReportStore

#pragma mark Properties

@synthesize path = _path;
@synthesize bundleName = _bundleName;
@synthesize demangleSwift = _demangleSwift;
@synthesize demangleCPP = _demangleCPP;

#pragma mark Construction

+ (BSG_KSCrashReportStore *)storeWithPath:(NSString *)path {
    return [[self alloc] initWithPath:path];
}

- (id)initWithPath:(NSString *)path {
    if ((self = [super init])) {
        self.path = path;
        self.bundleName = [[[NSBundle mainBundle] infoDictionary]
            objectForKey:@"CFBundleName"];
        self.demangleCPP = YES;
        self.demangleSwift = YES;
    }
    return self;
}

#pragma mark API

- (NSArray *)reportIDs {
    NSError *error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *filenames = [fm contentsOfDirectoryAtPath:self.path error:&error];
    if (filenames == nil) {
        BSG_KSLOG_ERROR(@"Could not get contents of directory %@: %@",
                        self.path, error);
        return nil;
    }

    NSMutableArray *reports =
        [NSMutableArray arrayWithCapacity:[filenames count]];
    for (NSString *filename in filenames) {
        NSString *reportId = [self reportIDFromFilename:filename];
        if (reportId != nil) {
            NSString *fullPath =
                [self.path stringByAppendingPathComponent:filename];
            NSDictionary *fileAttribs =
                [fm attributesOfItemAtPath:fullPath error:&error];
            if (fileAttribs == nil) {
                BSG_KSLOG_ERROR(@"Could not read file attributes for %@: %@",
                                fullPath, error);
            } else {
                [reports
                    addObject:[BSG_KSCrashReportInfo
                                  reportInfoWithID:reportId
                                      creationDate:
                                          [fileAttribs
                                              valueForKey:NSFileCreationDate]]];
            }
        }
    }
    [reports sortUsingSelector:@selector(compare:)];

    NSMutableArray *sortedIDs =
        [NSMutableArray arrayWithCapacity:[reports count]];
    for (BSG_KSCrashReportInfo *info in reports) {
        [sortedIDs addObject:info.reportID];
    }
    return sortedIDs;
}

- (NSUInteger)reportCount {
    return [[self reportIDs] count];
}

- (NSDictionary *)reportWithID:(NSString *)reportID {
    NSError *error = nil;
    NSMutableDictionary *crashReport =
        [self readReport:[self pathToCrashReportWithID:reportID] error:&error];
    if (error != nil) {
        BSG_KSLOG_ERROR(@"Encountered error loading crash report %@: %@",
                        reportID, error);
    }
    if (crashReport == nil) {
        BSG_KSLOG_ERROR(@"Could not load crash report");
        return nil;
    }
    NSMutableDictionary *recrashReport =
        [self readReport:[self pathToRecrashReportWithID:reportID] error:nil];
    [crashReport bsg_ksc_setObjectIfNotNil:recrashReport
                                    forKey:@BSG_KSCrashField_RecrashReport];

    return crashReport;
}

- (NSArray *)allReports {
    NSArray *reportIDs = [self reportIDs];
    NSMutableArray *reports =
        [NSMutableArray arrayWithCapacity:[reportIDs count]];
    for (NSString *reportID in reportIDs) {
        NSDictionary *report = [self reportWithID:reportID];
        if (report != nil) {
            [reports addObject:report];
        }
    }

    return reports;
}

- (void)deleteReportWithID:(NSString *)reportID {
    NSError *error = nil;
    NSString *filename = [self pathToCrashReportWithID:reportID];

    [[NSFileManager defaultManager] removeItemAtPath:filename error:&error];
    if (error != nil) {
        BSG_KSLOG_ERROR(@"Could not delete file %@: %@", filename, error);
    }

    // Don't care if this succeeds or not since it may not exist.
    [[NSFileManager defaultManager]
        removeItemAtPath:[self pathToRecrashReportWithID:reportID]
                   error:&error];
}

- (void)deleteAllReports {
    for (NSString *reportID in [self reportIDs]) {
        [self deleteReportWithID:reportID];
    }
}

- (void)pruneReportsLeaving:(int)numReports {
    NSArray *reportIDs = [self reportIDs];
    int deleteCount = (int)[reportIDs count] - numReports;
    for (int i = 0; i < deleteCount; i++) {
        [self deleteReportWithID:[reportIDs objectAtIndex:(NSUInteger)i]];
    }
}

#pragma mark Utility

- (void)performOnFields:(NSArray *)fieldPath
               inReport:(NSMutableDictionary *)report
              operation:(void (^)(id parent, id field))operation
           okIfNotFound:(BOOL)isOkIfNotFound {
    if (fieldPath.count == 0) {
        BSG_KSLOG_ERROR(@"Unexpected end of field path");
        return;
    }

    NSString *currentField = fieldPath[0];
    if (fieldPath.count > 1) {
        fieldPath =
            [fieldPath subarrayWithRange:NSMakeRange(1, fieldPath.count - 1)];
    } else {
        fieldPath = @[];
    }

    id field = report[currentField];
    if (field == nil) {
        if (!isOkIfNotFound) {
            BSG_KSLOG_ERROR(@"%@: No such field in report. Candidates are: %@",
                            currentField, report.allKeys);
        }
        return;
    }

    if ([field isKindOfClass:NSMutableDictionary.class]) {
        [self performOnFields:fieldPath
                     inReport:field
                    operation:operation
                 okIfNotFound:isOkIfNotFound];
    } else if ([field isKindOfClass:[NSMutableArray class]]) {
        for (id subfield in field) {
            if ([subfield isKindOfClass:NSMutableDictionary.class]) {
                [self performOnFields:fieldPath
                             inReport:subfield
                            operation:operation
                         okIfNotFound:isOkIfNotFound];
            } else {
                operation(field, subfield);
            }
        }
    } else {
        operation(report, field);
    }
}

- (NSMutableDictionary *)fixupCrashReport:(NSDictionary *)report {
    if (![report isKindOfClass:[NSDictionary class]]) {
        BSG_KSLOG_ERROR(@"Report should be a dictionary, not %@",
                        [report class]);
        return nil;
    }

    NSMutableDictionary *mutableReport = [report mutableCopy];
    NSMutableDictionary *mutableInfo =
        [[report objectForKey:@BSG_KSCrashField_Report] mutableCopy];
    [mutableReport bsg_ksc_setObjectIfNotNil:mutableInfo
                                      forKey:@BSG_KSCrashField_Report];

    // Timestamp gets stored as a unix timestamp. Convert it to rfc3339.
    [self convertTimestamp:@BSG_KSCrashField_Timestamp inReport:mutableInfo];

    [self mergeDictWithKey:@BSG_KSCrashField_SystemAtCrash
           intoDictWithKey:@BSG_KSCrashField_System
                  inReport:mutableReport];

    [self mergeDictWithKey:@BSG_KSCrashField_UserAtCrash
           intoDictWithKey:@BSG_KSCrashField_User
                  inReport:mutableReport];

    NSMutableDictionary *crashReport =
        [[report objectForKey:@BSG_KSCrashField_Crash] mutableCopy];
    [mutableReport bsg_ksc_setObjectIfNotNil:crashReport
                                      forKey:@BSG_KSCrashField_Crash];
    BSG_KSCrashDoctor *doctor = [BSG_KSCrashDoctor doctor];
    [crashReport bsg_ksc_setObjectIfNotNil:[doctor diagnoseCrash:report]
                                    forKey:@BSG_KSCrashField_Diagnosis];

    return mutableReport;
}

- (void)mergeDictWithKey:(NSString *)srcKey
         intoDictWithKey:(NSString *)dstKey
                inReport:(NSMutableDictionary *)report {
    NSDictionary *srcDict = [report objectForKey:srcKey];
    if (srcDict == nil) {
        // It's OK if the source dict didn't exist.
        return;
    }
    if (![srcDict isKindOfClass:[NSDictionary class]]) {
        BSG_KSLOG_ERROR(@"'%@' should be a dictionary, not %@", srcKey,
                        [srcDict class]);
        return;
    }

    NSDictionary *dstDict = [report objectForKey:dstKey];
    if (dstDict == nil) {
        dstDict = [NSDictionary dictionary];
    }
    if (![dstDict isKindOfClass:[NSDictionary class]]) {
        BSG_KSLOG_ERROR(@"'%@' should be a dictionary, not %@", dstKey,
                        [dstDict class]);
        return;
    }

    [report bsg_ksc_setObjectIfNotNil:[srcDict mergedInto:dstDict]
                               forKey:dstKey];
    [report removeObjectForKey:srcKey];
}

- (void)convertTimestamp:(NSString *)key
                inReport:(NSMutableDictionary *)report {
    NSNumber *timestamp = [report objectForKey:key];
    if (timestamp == nil) {
        BSG_KSLOG_ERROR(@"entry '%@' not found", key);
        return;
    }
    if (![timestamp isKindOfClass:[NSNumber class]]) {
        BSG_KSLOG_ERROR(@"'%@' should be a number, not %@", key, [key class]);
        return;
    }
    [report
        setValue:[BSG_RFC3339DateTool
                     stringFromUNIXTimestamp:[timestamp unsignedLongLongValue]]
          forKey:key];
}

- (NSString *)crashReportFilenameWithID:(NSString *)reportID {
    return [NSString stringWithFormat:@"%@" BSG_kCrashReportSuffix "%@.json",
                                      self.bundleName, reportID];
}

- (NSString *)recrashReportFilenameWithID:(NSString *)reportID {
    return [NSString stringWithFormat:@"%@" BSG_kRecrashReportSuffix "%@.json",
                                      self.bundleName, reportID];
}

- (NSString *)reportIDFromFilename:(NSString *)filename {
    if ([filename length] == 0 ||
        [[filename pathExtension] isEqualToString:@"json"] == NO) {
        return nil;
    }

    NSString *prefix = [NSString
        stringWithFormat:@"%@" BSG_kCrashReportSuffix, self.bundleName];
    NSString *suffix = @".json";

    NSRange prefixRange = [filename rangeOfString:prefix];
    NSRange suffixRange =
        [filename rangeOfString:suffix options:NSBackwardsSearch];
    if (prefixRange.location == 0 && suffixRange.location != NSNotFound) {
        NSUInteger prefixEnd = NSMaxRange(prefixRange);
        NSRange range =
            NSMakeRange(prefixEnd, suffixRange.location - prefixEnd);
        return [filename substringWithRange:range];
    }
    return nil;
}

- (NSString *)pathToCrashReportWithID:(NSString *)reportID {
    NSString *filename = [self crashReportFilenameWithID:reportID];
    return [self.path stringByAppendingPathComponent:filename];
}

- (NSString *)pathToRecrashReportWithID:(NSString *)reportID {
    NSString *filename = [self recrashReportFilenameWithID:reportID];
    return [self.path stringByAppendingPathComponent:filename];
}

- (NSString *)getReportType:(NSDictionary *)report {
    NSDictionary *reportSection = report[@BSG_KSCrashField_Report];
    if (reportSection) {
        return reportSection[@BSG_KSCrashField_Type];
    }
    BSG_KSLOG_ERROR(@"Expected a report section in the report.");
    return nil;
}

- (NSMutableDictionary *)readReport:(NSString *)path
                              error:(NSError *__autoreleasing *)error {
    if (path == nil) {
        [NSError fillError:error
                withDomain:[[self class] description]
                      code:0
               description:@"Path is nil"];
        return nil;
    }

    NSData *jsonData =
        [NSData dataWithContentsOfFile:path options:0 error:error];
    if (jsonData == nil) {
        return nil;
    }

    NSMutableDictionary *report =
        [BSG_KSJSONCodec decode:jsonData
                        options:BSG_KSJSONDecodeOptionIgnoreNullInArray |
                                BSG_KSJSONDecodeOptionIgnoreNullInObject |
                                BSG_KSJSONDecodeOptionKeepPartialObject
                          error:error];
    if (error != nil && *error != nil) {

        BSG_KSLOG_ERROR(@"Error decoding JSON data from %@: %@", path, *error);
        [report setObject:[NSNumber numberWithBool:YES]
                   forKey:@BSG_KSCrashField_Incomplete];
    }

    NSString *reportType = [self getReportType:report];
    if ([reportType isEqualToString:@BSG_KSCrashReportType_Standard] ||
        [reportType isEqualToString:@BSG_KSCrashReportType_Minimal]) {
        report = [self fixupCrashReport:report];
    }

    return report;
}

- (void)addReportSectionForCustomReport:(NSMutableDictionary *)report {
    NSMutableDictionary *reportSection = [NSMutableDictionary new];
    reportSection[@BSG_KSCrashField_Version] = @BSG_KSCRASH_REPORT_VERSION;
    reportSection[@BSG_KSCrashField_ID] = [NSUUID UUID].UUIDString;
    reportSection[@BSG_KSCrashField_ProcessName] =
        [NSProcessInfo processInfo].processName;
    reportSection[@BSG_KSCrashField_Timestamp] =
        [NSNumber numberWithLong:time(NULL)];
    reportSection[@BSG_KSCrashField_Type] = @BSG_KSCrashReportType_Custom;

    report[@BSG_KSCrashField_Report] = reportSection;
}

- (NSString *)addCustomReport:(NSDictionary *)report {
    NSMutableDictionary *mutableReport = [report mutableCopy];
    [self addReportSectionForCustomReport:mutableReport];
    NSError *error = nil;
    NSData *data =
        [BSG_KSJSONCodec encode:mutableReport options:0 error:&error];
    if (error) {
        BSG_KSLOG_ERROR(@"Error encoding custom report: %@", error);
        return nil;
    }

    NSString *identifier =
        mutableReport[@BSG_KSCrashField_Report][@BSG_KSCrashField_ID];
    NSString *path = [self pathToCrashReportWithID:identifier];
    error = nil;
    BOOL didWriteFile = [data writeToFile:path options:0 error:&error];
    if (!didWriteFile || error) {
        BSG_KSLOG_ERROR(@"Could not write custom report to %@: %@", path,
                        error);
        return nil;
    }

    return identifier;
}

@end
