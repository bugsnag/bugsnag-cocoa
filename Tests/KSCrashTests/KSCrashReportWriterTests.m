//
//  KSCrashReportWriterTests.m
//  Bugsnag
//
//  Created by Nick Dowell on 23/10/2020.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "KSCrashReportWriter.h"
#import "KSFileUtils.h"
#import "KSJSONCodec.h"

// Defined in KSCrashReport.c
void kscrw_i_prepareReportWriter(KSCrashReportWriter *const writer, KSJSONEncodeContext *const context);

static int addJSONData(const char *data, size_t length, NSMutableData *userData) {
    [userData appendBytes:data length:length];
    return KSJSON_OK;
}

static id JSONObject(void (^ block)(KSCrashReportWriter *writer)) {
    NSMutableData *data = [NSMutableData data];
    KSJSONEncodeContext encodeContext;
    KSCrashReportWriter reportWriter;
    kscrw_i_prepareReportWriter(&reportWriter, &encodeContext);
    ksjsonbeginEncode(&encodeContext, false, (KSJSONAddDataFunc)addJSONData, (__bridge void *)data);
    block(&reportWriter);
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
}

#pragma mark -

@interface KSCrashReportWriterTests : XCTestCase
@end

#pragma mark -

@implementation KSCrashReportWriterTests

- (void)testSimpleObject {
    id object = JSONObject(^(KSCrashReportWriter *writer) {
        writer->beginObject(writer, NULL);
        writer->addStringElement(writer, "foo", "bar");
        writer->endContainer(writer);
    });
    XCTAssertEqualObjects(object, @{@"foo": @"bar"});
}

- (void)testArray {
    id object = JSONObject(^(KSCrashReportWriter *writer) {
        writer->beginArray(writer, NULL);
        writer->addStringElement(writer, "foo", "bar");
        writer->endContainer(writer);
    });
    XCTAssertEqualObjects(object, @[@"bar"]);
}

- (void)testArrayInsideObject {
    id object = JSONObject(^(KSCrashReportWriter *writer) {
        writer->beginObject(writer, NULL);
        writer->beginArray(writer, "items");
        writer->addStringElement(writer, NULL, "bar");
        writer->addStringElement(writer, NULL, "foo");
        writer->endContainer(writer);
        writer->endContainer(writer);
    });
    id expected = @{@"items": @[@"bar", @"foo"]};
    XCTAssertEqualObjects(object, expected);
}

- (void)testFileElementsInsideArray {
    NSString *temporaryFile = [NSTemporaryDirectory() stringByAppendingPathComponent:@"testFileElementsInsideArray.json"];
    [@"{\"foo\":\"bar\"}" writeToFile:temporaryFile atomically:NO encoding:NSUTF8StringEncoding error:NULL];
    id object = JSONObject(^(KSCrashReportWriter *writer) {
        writer->beginArray(writer, NULL);
        writer->addJSONFileElement(writer, NULL, temporaryFile.fileSystemRepresentation);
        writer->addJSONFileElement(writer, NULL, "/invalid/files/should/be/ignored");
        writer->addJSONFileElement(writer, NULL, temporaryFile.fileSystemRepresentation);
        writer->endContainer(writer);
    });
    id expected = @[@{@"foo": @"bar"}, @{@"foo": @"bar"}];
    XCTAssertEqualObjects(object, expected);
    [[NSFileManager defaultManager] removeItemAtPath:temporaryFile error:NULL];
}

@end
