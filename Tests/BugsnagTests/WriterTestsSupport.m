//
//  WriterTestsSupport.m
//  Bugsnag
//
//  Created by Robert B on 24/03/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "WriterTestsSupport.h"

// Functions copied from KSCrash - in there they are static and not visible

#define test_getJsonContext(REPORT_WRITER) ((KSJSONEncodeContext *)((REPORT_WRITER)->context))
static const char testg_hexNybbles[] = { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F' };

static void test_addBooleanElement(const KSCrashReportWriter *const writer, const char *const key, const bool value)
{
    ksjson_addBooleanElement(test_getJsonContext(writer), key, value);
}

static void test_addFloatingPointElement(const KSCrashReportWriter *const writer, const char *const key, const double value)
{
    ksjson_addFloatingPointElement(test_getJsonContext(writer), key, value);
}

static void test_addIntegerElement(const KSCrashReportWriter *const writer, const char *const key, const int64_t value)
{
    ksjson_addIntegerElement(test_getJsonContext(writer), key, value);
}

static void test_addUIntegerElement(const KSCrashReportWriter *const writer, const char *const key, const uint64_t value)
{
    ksjson_addUIntegerElement(test_getJsonContext(writer), key, value);
}

static void test_addStringElement(const KSCrashReportWriter *const writer, const char *const key, const char *const value)
{
    ksjson_addStringElement(test_getJsonContext(writer), key, value, KSJSON_SIZE_AUTOMATIC);
}

static void test_addDataElement(const KSCrashReportWriter *const writer, const char *const key, const char *const value,
                           const int length)
{
    ksjson_addDataElement(test_getJsonContext(writer), key, value, length);
}

static void test_beginDataElement(const KSCrashReportWriter *const writer, const char *const key)
{
    ksjson_beginDataElement(test_getJsonContext(writer), key);
}

static void test_appendDataElement(const KSCrashReportWriter *const writer, const char *const value, const int length)
{
    ksjson_appendDataElement(test_getJsonContext(writer), value, length);
}

static void test_endDataElement(const KSCrashReportWriter *const writer) { ksjson_endDataElement(test_getJsonContext(writer)); }

static void test_addUUIDElement(const KSCrashReportWriter *const writer, const char *const key,
                           const unsigned char *const value)
{
    if (value == NULL) {
        ksjson_addNullElement(test_getJsonContext(writer), key);
    } else {
        char uuidBuffer[37];
        const unsigned char *src = value;
        char *dst = uuidBuffer;
        for (int i = 0; i < 4; i++) {
            *dst++ = testg_hexNybbles[(*src >> 4) & 15];
            *dst++ = testg_hexNybbles[(*src++) & 15];
        }
        *dst++ = '-';
        for (int i = 0; i < 2; i++) {
            *dst++ = testg_hexNybbles[(*src >> 4) & 15];
            *dst++ = testg_hexNybbles[(*src++) & 15];
        }
        *dst++ = '-';
        for (int i = 0; i < 2; i++) {
            *dst++ = testg_hexNybbles[(*src >> 4) & 15];
            *dst++ = testg_hexNybbles[(*src++) & 15];
        }
        *dst++ = '-';
        for (int i = 0; i < 2; i++) {
            *dst++ = testg_hexNybbles[(*src >> 4) & 15];
            *dst++ = testg_hexNybbles[(*src++) & 15];
        }
        *dst++ = '-';
        for (int i = 0; i < 6; i++) {
            *dst++ = testg_hexNybbles[(*src >> 4) & 15];
            *dst++ = testg_hexNybbles[(*src++) & 15];
        }

        ksjson_addStringElement(test_getJsonContext(writer), key, uuidBuffer, (int)(dst - uuidBuffer));
    }
}

static void test_addJSONElement(const KSCrashReportWriter *const writer, const char *const key,
                           const char *const jsonElement, bool closeLastContainer)
{
    int jsonResult =
        ksjson_addJSONElement(test_getJsonContext(writer), key, jsonElement, (int)strlen(jsonElement), closeLastContainer);
    if (jsonResult != KSJSON_OK) {
        char errorBuff[100];
        snprintf(errorBuff, sizeof(errorBuff), "Invalid JSON data: %s", ksjson_stringForError(jsonResult));
        ksjson_beginObject(test_getJsonContext(writer), key);
        ksjson_addStringElement(test_getJsonContext(writer), "error", errorBuff, KSJSON_SIZE_AUTOMATIC);
        ksjson_addStringElement(test_getJsonContext(writer), "json_data", jsonElement, KSJSON_SIZE_AUTOMATIC);
        ksjson_endContainer(test_getJsonContext(writer));
    }
}

static void test_beginObject(const KSCrashReportWriter *const writer, const char *const key)
{
    ksjson_beginObject(test_getJsonContext(writer), key);
}

static void test_beginArray(const KSCrashReportWriter *const writer, const char *const key)
{
    ksjson_beginArray(test_getJsonContext(writer), key);
}

static void test_endContainer(const KSCrashReportWriter *const writer) { ksjson_endContainer(test_getJsonContext(writer)); }


static int test_addJSONData(const char *data, size_t length, NSMutableData *userData) {
    [userData appendBytes:data length:length];
    return KSJSON_OK;
}


void prepareReportWriter(KSCrashReportWriter *const writer, KSJSONEncodeContext *const context) {
    writer->addBooleanElement = test_addBooleanElement;
    writer->addFloatingPointElement = test_addFloatingPointElement;
    writer->addIntegerElement = test_addIntegerElement;
    writer->addUIntegerElement = test_addUIntegerElement;
    writer->addStringElement = test_addStringElement;
    writer->addTextFileElement = nil;
    writer->addTextFileLinesElement = nil;
    writer->addJSONFileElement = nil;
    writer->addDataElement = test_addDataElement;
    writer->beginDataElement = test_beginDataElement;
    writer->appendDataElement = test_appendDataElement;
    writer->endDataElement = test_endDataElement;
    writer->addUUIDElement = test_addUUIDElement;
    writer->addJSONElement = test_addJSONElement;
    writer->beginObject = test_beginObject;
    writer->beginArray = test_beginArray;
    writer->endContainer = test_endContainer;
    writer->context = context;
}

id bsg_JSONObject(void (^ block)(KSCrashReportWriter *writer)) {
    NSMutableData *data = [NSMutableData data];
    KSJSONEncodeContext encodeContext;
    KSCrashReportWriter reportWriter;
    prepareReportWriter(&reportWriter, &encodeContext);
    ksjson_beginEncode(&encodeContext, false, (KSJSONAddDataFunc)test_addJSONData, (__bridge void *)data);
    block(&reportWriter);
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
}
