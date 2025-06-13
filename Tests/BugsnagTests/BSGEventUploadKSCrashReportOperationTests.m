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
#import "KSCrash.h"

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

- (void)testKSCrashReport2 {
    NSString *file = [[NSBundle bundleForClass:[self class]] pathForResource:@"KSCrashReport2" ofType:@"json" inDirectory:@"Data"];
    BSGEventUploadKSCrashReportOperation *operation = [self operationWithFile:file];
    BugsnagEvent *event = [operation loadEventAndReturnError:nil];
    XCTAssertEqual(event.threads.count, 8);
    XCTAssertEqualObjects([event.breadcrumbs valueForKeyPath:NSStringFromSelector(@selector(message))], @[@"Bugsnag loaded"]);
    XCTAssertEqualObjects(event.app.bundleVersion, @"5");
    XCTAssertEqualObjects(event.app.id, @"com.github.kstenerud.KSCrash.Sample");
    XCTAssertEqualObjects(event.app.releaseStage, @"development");
    XCTAssertEqualObjects(event.app.type, @"macOS");
    XCTAssertEqualObjects(event.app.version, @"1.0.3");
    XCTAssertEqualObjects(event.errors.firstObject.errorClass, @"EXC_BAD_ACCESS");
    XCTAssertEqualObjects(event.errors.firstObject.errorMessage, @"Attempted to dereference garbage pointer 0x42.");
    XCTAssertEqualObjects(event.threads.firstObject.stacktrace.firstObject.method, @"+[KSCrashTriggersList trigger_mach_badAccess]");
    XCTAssertTrue([event.threads.firstObject.stacktrace.firstObject.machoFile hasSuffix:@"Sample.app/Sample.debug.dylib"]);
    XCTAssertTrue(event.app.inForeground);
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
    NSString *file = [self temporaryFileWithContents:@"{\"report\":{},\"system\":{},\"user\":{error:true}}"];
    BSGEventUploadKSCrashReportOperation *operation = [self operationWithFile:file];
    XCTAssertNil([operation loadEventAndReturnError:nil]);
    XCTAssertEqualObjects(self.errorClass, @"Invalid crash report");
    XCTAssertEqualObjects(self.context, @"JSON parsing error");
    XCTAssertEqualObjects(self.diagnostics[@"keys"], (@[@"report", @"system", @"user"]));
}

- (void)testCorruptKSCrashReport {
    NSString *file = [[NSBundle bundleForClass:[self class]] pathForResource:@"KSCrashReport2" ofType:@"json" inDirectory:@"Data"];
    NSMutableString *JSONString = [NSMutableString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];
    [JSONString replaceCharactersInRange:NSMakeRange(24696, 1) withString:@""];
    file = [self temporaryFileWithContents:JSONString];
    BSGEventUploadKSCrashReportOperation *operation = [self operationWithFile:file];
    XCTAssertNil([operation loadEventAndReturnError:nil]);
    XCTAssertEqualObjects(self.errorClass, @"Invalid crash report");
    XCTAssertEqualObjects(self.context, @"JSON parsing error");
    // Multiple "state" keys are coming from thread states
    // 8 threads = 8 additional "state" keys
    // also, nested "user"
    XCTAssertEqualObjects(self.diagnostics[@"keys"], (@[@"report", @"process", @"system", @"crash", @"error",
        @"threads", @"state", @"state", @"state", @"state", @"state", @"state",  @"state", @"state",
        @"binary_images", @"user", @"metaData", @"user", @"state", @"breadcrumbs", @"metaData"]));
}

@end
