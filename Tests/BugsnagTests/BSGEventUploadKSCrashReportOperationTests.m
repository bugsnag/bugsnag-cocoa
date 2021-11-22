//
//  BSGEventUploadKSCrashReportOperationTests.m
//  Bugsnag
//
//  Created by Nick Dowell on 18/02/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import <Bugsnag/Bugsnag.h>
#import <XCTest/XCTest.h>

#import "BSGEventUploadKSCrashReportOperation.h"

@interface BSGEventUploadKSCrashReportOperationTests : XCTestCase

@end

@implementation BSGEventUploadKSCrashReportOperationTests

- (void)testKSCrashReport1 {
    NSString *file = [[NSBundle bundleForClass:[self class]] pathForResource:@"KSCrashReport1" ofType:@"json" inDirectory:@"Data"];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    BSGEventUploadKSCrashReportOperation *operation = [[BSGEventUploadKSCrashReportOperation alloc] initWithFile:file delegate:nil];
#pragma clang diagnostic pop
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

@end
