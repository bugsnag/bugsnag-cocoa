//
//  KSCrashReportWriterTests.m
//  Bugsnag
//
//  Created by Nick Dowell on 23/10/2020.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "BSG_KSCrashReportWriter.h"
#import "BSG_KSFileUtils.h"
#import "BSG_KSJSONCodec.h"

// Defined in BSG_KSCrashReport.c
void bsg_kscrw_i_prepareReportWriter(BSG_KSCrashReportWriter *const writer, BSG_KSJSONEncodeContext *const context);

static int addJSONData(const char *data, size_t length, NSMutableData *userData) {
    [userData appendBytes:data length:length];
    return BSG_KSJSON_OK;
}

static id JSONObject(void (^ block)(BSG_KSCrashReportWriter *writer)) {
    NSMutableData *data = [NSMutableData data];
    BSG_KSJSONEncodeContext encodeContext;
    BSG_KSCrashReportWriter reportWriter;
    bsg_kscrw_i_prepareReportWriter(&reportWriter, &encodeContext);
    bsg_ksjsonbeginEncode(&encodeContext, false, (BSG_KSJSONAddDataFunc)addJSONData, (__bridge void *)data);
    block(&reportWriter);
    return [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:NULL];
}

#pragma mark -

@interface KSCrashReportWriterTests : XCTestCase
@end

#pragma mark -

@implementation KSCrashReportWriterTests

- (void)testSimpleObject {
    id object = JSONObject(^(BSG_KSCrashReportWriter *writer) {
        writer->beginObject(writer, "IGNORED");
        writer->addStringElement(writer, "foo", "bar");
        writer->endContainer(writer);
    });
    XCTAssertEqualObjects(object, @{@"foo": @"bar"});
}

- (void)testArray {
    id object = JSONObject(^(BSG_KSCrashReportWriter *writer) {
        writer->beginArray(writer, "IGNORED");
        writer->addStringElement(writer, "foo", "bar");
        writer->endContainer(writer);
    });
    XCTAssertEqualObjects(object, @[@"bar"]);
}

- (void)testArrayInsideObject {
    id object = JSONObject(^(BSG_KSCrashReportWriter *writer) {
        writer->beginObject(writer, "IGNORED");
        writer->beginArray(writer, "items");
        writer->addStringElement(writer, "IGNORED", "bar");
        writer->addStringElement(writer, "IGNORED", "foo");
        writer->endContainer(writer);
        writer->endContainer(writer);
    });
    id expected = @{@"items": @[@"bar", @"foo"]};
    XCTAssertEqualObjects(object, expected);
}

- (void)testFileElementsInsideArray {
    NSString *temporaryFile = [NSTemporaryDirectory() stringByAppendingPathComponent:@"testFileElementsInsideArray.json"];
    [@"{\"foo\":\"bar\"}" writeToFile:temporaryFile atomically:NO encoding:NSUTF8StringEncoding error:NULL];
    id object = JSONObject(^(BSG_KSCrashReportWriter *writer) {
        writer->beginArray(writer, "IGNORED");
        writer->addJSONFileElement(writer, "IGNORED", temporaryFile.fileSystemRepresentation);
        writer->addJSONFileElement(writer, "IGNORED", "/invalid/files/should/be/ignored");
        writer->addJSONFileElement(writer, "IGNORED", temporaryFile.fileSystemRepresentation);
        writer->endContainer(writer);
    });
    id expected = @[@{@"foo": @"bar"}, @{@"foo": @"bar"}];
    XCTAssertEqualObjects(object, expected);
    [[NSFileManager defaultManager] removeItemAtPath:temporaryFile error:NULL];
}

@end
