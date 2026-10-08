//
//  BSGEventUploadKSCrashReportOperationTests.m
//  Bugsnag
//
//  Created by Nick Dowell on 18/02/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "BSGTestCase.h"

#import <Bugsnag/Bugsnag.h>

#import "BSGEventUploadKSCrashReportOperation.h"
#import "BSGInternalErrorReporter.h"

@interface BSGEventUploadKSCrashReportOperationTests : BSGTestCase

@property NSString *errorClass;
@property NSString *context;
@property NSString *message;
@property NSDictionary *diagnostics;

@end

@implementation BSGEventUploadKSCrashReportOperationTests

- (void)setUp {
    [super setUp];
    
    BSGInternalErrorReporter.sharedInstance = (id)self;
}

- (BSGEventUploadKSCrashReportOperation *)operationWithFile:(NSString *)file {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    return [[BSGEventUploadKSCrashReportOperation alloc] initWithFile:file delegate:nil];
#pragma clang diagnostic pop
}

- (NSString *)temporaryFileWithContents:(NSString *)contents {
    NSString *file = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    [contents writeToFile:file atomically:NO encoding:NSUTF8StringEncoding error:nil];
    [self addTeardownBlock:^{
        [NSFileManager.defaultManager removeItemAtPath:file error:nil];
    }];
    return file;
}

- (void)reportErrorWithClass:(NSString *)errorClass
                     context:(NSString *)context
                     message:(NSString *)message
                 diagnostics:(NSDictionary<NSString *, id> *)diagnostics {
    self.errorClass = errorClass;
    self.context = context;
    self.message = message;
    self.diagnostics = diagnostics;
}

#pragma mark -

- (void)testKSCrashReport1 {
    NSString *file = [[NSBundle bundleForClass:[self class]] pathForResource:@"KSCrashReport1" ofType:@"json" inDirectory:@"Data"];
    BSGEventUploadKSCrashReportOperation *operation = [self operationWithFile:file];
    BugsnagEvent *event = [operation loadEventAndReturnError:nil];
    XCTAssertEqual(event.threads.count, 20);
    XCTAssertEqualObjects([event.breadcrumbs valueForKeyPath:NSStringFromSelector(@selector(message))], @[@"Bugsnag loaded"]);
    XCTAssertEqualObjects(event.app.bundleVersion, @"5");
    XCTAssertEqualObjects(event.app.id, @"com.bugsnag.macOSTestApp");
    XCTAssertEqualObjects(event.app.releaseStage, @"development");
    XCTAssertEqualObjects(event.app.type, @"macOS");
    XCTAssertEqualObjects(event.app.version, @"1.0.3");
    XCTAssertEqualObjects(event.errors.firstObject.errorClass, @"EXC_BAD_ACCESS");
    XCTAssertEqualObjects(event.errors.firstObject.errorMessage, @"Attempted to dereference null pointer.");
    XCTAssertEqualObjects(event.threads.firstObject.stacktrace.firstObject.method, @"-[OverwriteLinkRegisterScenario run]");
    XCTAssertEqualObjects(event.threads.firstObject.stacktrace.firstObject.machoFile, @"/Users/nick/Library/Developer/Xcode/Derived Data/macOSTestApp-ffunpkxyeczwoccascsrmsggolbp/Build/Products/Debug/macOSTestApp.app/Contents/MacOS/macOSTestApp");
    XCTAssertEqualObjects(event.user.id, @"48decb8cf9f410c4c20e6f597070ee60b131a5c4");
    XCTAssertTrue(event.app.inForeground);
}

// Regression coverage for the crash-time jailbreak override written by
// bsg_kscrashreport_writeKSCrashFields (BSG_KSCrashReport.c): "system" can
// be a stale, install-time snapshot, but "system_atcrash" is written fresh
// at the moment of the crash and must win when the two disagree. This tests
// the merge BSGEventUploadKSCrashReportOperation already performs, which is
// what makes that override actually take effect in a parsed BugsnagEvent.
- (void)testCrashTimeJailbreakStatusOverridesStaleStartupSnapshot {
    NSString *path = [[NSBundle bundleForClass:self.class] pathForResource:@"KSCrashReport1" ofType:@"json" inDirectory:@"Data"];
    NSMutableDictionary *report = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:path]
                                                                 options:NSJSONReadingMutableContainers
                                                                   error:nil];
    XCTAssertEqualObjects(report[@"system"][@"jailbroken"], @NO);
    NSMutableDictionary *systemAtCrash = report[@"system_atcrash"];
    XCTAssertNotNil(systemAtCrash, @"fixture is expected to already have a system_atcrash object");
    systemAtCrash[@"jailbroken"] = @YES;

    NSData *data = [NSJSONSerialization dataWithJSONObject:report options:0 error:nil];
    NSString *file = [self temporaryFileWithContents:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
    BugsnagEvent *event = [[self operationWithFile:file] loadEventAndReturnError:nil];
    XCTAssertNotNil(event);
    XCTAssertTrue(event.device.jailbroken);
}

- (void)testEmptyFile {
    NSString *file = [self temporaryFileWithContents:@""];
    BSGEventUploadKSCrashReportOperation *operation = [self operationWithFile:file];
    XCTAssertNil([operation loadEventAndReturnError:nil]);
    XCTAssertEqualObjects(self.errorClass, @"Invalid crash report");
    XCTAssertEqualObjects(self.context, @"File is empty");
    XCTAssert([self.message hasPrefix:@"NSCocoaErrorDomain 3840: "]);
}

- (void)testUnterminatedJSON {
    NSString *file = [self temporaryFileWithContents:@"{"];
    BSGEventUploadKSCrashReportOperation *operation = [self operationWithFile:file];
    XCTAssertNil([operation loadEventAndReturnError:nil]);
    XCTAssertEqualObjects(self.errorClass, @"Invalid crash report");
    XCTAssertEqualObjects(self.context, @"Does not end with \"}\"");
    XCTAssert([self.message hasPrefix:@"NSCocoaErrorDomain 3840: "]);
}

- (void)testInvalidJSON {
    NSString *file = [self temporaryFileWithContents:@"{}"];
    BSGEventUploadKSCrashReportOperation *operation = [self operationWithFile:file];
    XCTAssertNil([operation loadEventAndReturnError:nil]);
    XCTAssertEqualObjects(self.errorClass, @"Invalid crash report");
    XCTAssertEqualObjects(self.context, @"Invalid JSON payload");
    XCTAssertNil(self.message);
}

- (void)testSimpleJSONError {
    NSString *file = [self temporaryFileWithContents:@"{\"report\":{},\"system\":{},\"user_atcrash\":{error:true}}"];
    BSGEventUploadKSCrashReportOperation *operation = [self operationWithFile:file];
    XCTAssertNil([operation loadEventAndReturnError:nil]);
    XCTAssertEqualObjects(self.errorClass, @"Invalid crash report");
    XCTAssertEqualObjects(self.context, @"JSON parsing error");
    XCTAssertEqualObjects(self.diagnostics[@"keys"], (@[@"report", @"system", @"user_atcrash"]));
}

- (void)testCorruptKSCrashReport {
    NSString *file = [[NSBundle bundleForClass:[self class]] pathForResource:@"KSCrashReport1" ofType:@"json" inDirectory:@"Data"];
    NSMutableString *JSONString = [NSMutableString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];
    [JSONString replaceCharactersInRange:NSMakeRange(106094, 1) withString:@""];
    file = [self temporaryFileWithContents:JSONString];
    BSGEventUploadKSCrashReportOperation *operation = [self operationWithFile:file];
    XCTAssertNil([operation loadEventAndReturnError:nil]);
    XCTAssertEqualObjects(self.errorClass, @"Invalid crash report");
    XCTAssertEqualObjects(self.context, @"JSON parsing error");
    XCTAssertEqualObjects(self.diagnostics[@"keys"], (@[
        @"report", @"process", @"system", @"system_atcrash", @"binary_images", @"crash", @"threads",
        @"error", @"user_atcrash", @"config", @"metaData", @"state", @"breadcrumbs", @"metaData"]));
}

@end
