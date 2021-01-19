//
//  BugsnagKVStoreTest.m
//  Bugsnag-iOSTests
//
//  Created by Karl Stenerud on 11.09.20.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "BugsnagKVStore.h"
 
#define AssertEqualCString(actual, expected) \
    actual == NULL \
    ? XCTFail("Expected '%s', got NULL", expected) \
    : XCTAssertEqual(strcmp(actual, expected), 0, "Expected '%s', got '%s'", expected, actual)

@interface BugsnagKVStoreTest : XCTestCase

@end

@implementation BugsnagKVStoreTest

- (NSString *)getCachesDir {
    NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    if ([dirs count] == 0) {
        XCTFail(@"Could not locate cache directory path.");
        return nil;
    }

    if ([dirs[0] length] == 0) {
        XCTFail(@"Cache directory path is empty!");
        return nil;
    }
    return dirs[0];
}


- (void)setUp {
    int err = 0;
    NSString* path = [[self getCachesDir] stringByAppendingPathComponent:@"bsgkv"];
    bsgkv_open([path cStringUsingEncoding:NSUTF8StringEncoding], &err);
    XCTAssertEqual(err, 0);
}

- (void)tearDown {
    bsgkv_close();
}

#define DECLARE_SCALAR_TEST(FUNC, TYPE, EXPECTED1, EXPECTED2) \
- (void)test##FUNC { \
    const char* name = "test-" #TYPE; \
    TYPE expected = EXPECTED1; \
    TYPE expected2 = EXPECTED2; \
    TYPE actual = 0; \
    int err = 0; \
\
    bsgkv_delete(name, &err); \
    XCTAssertEqual(err, 0); \
\
    bsgkv_delete(name, &err); \
    XCTAssertEqual(err, 0); \
\
    bsgkv_set##FUNC(name, expected, &err); \
    XCTAssertEqual(err, 0); \
\
    actual = bsgkv_get##FUNC(name, &err); \
    XCTAssertEqual(err, 0); \
    XCTAssertEqual(actual, expected); \
\
    bsgkv_set##FUNC(name, expected2, &err); \
    XCTAssertEqual(err, 0); \
\
    actual = bsgkv_get##FUNC(name, &err); \
    XCTAssertEqual(err, 0); \
    XCTAssertEqual(actual, expected2); \
\
    bsgkv_delete(name, &err); \
    XCTAssertEqual(err, 0); \
\
    actual = bsgkv_get##FUNC(name, &err); \
    XCTAssertEqual(err, ENOENT); \
\
    bsgkv_set##FUNC(name, expected, &err); \
    XCTAssertEqual(err, 0); \
\
    actual = bsgkv_get##FUNC(name, &err); \
    XCTAssertEqual(err, 0); \
    XCTAssertEqual(actual, expected); \
}

DECLARE_SCALAR_TEST(Boolean, bool, true, false)
DECLARE_SCALAR_TEST(Int, int64_t, 1000, 2000)
DECLARE_SCALAR_TEST(Float, double, 123.456, 7.89e50)


- (void)testString {
    const char* name = "test-string";
    const char* expected = "Blah blah blah blah blah";
    const char* expected2 = "Something else";
    char actual[100];
    int err = 0;
    
    bsgkv_delete(name, &err);
    XCTAssertEqual(err, 0);
    
    bsgkv_delete(name, &err);
    XCTAssertEqual(err, 0);

    bsgkv_setString(name, expected, &err);
    XCTAssertEqual(err, 0);

    bsgkv_getString(name, actual, sizeof(actual), &err);
    XCTAssertEqual(err, 0);
    AssertEqualCString(actual, expected);

    bsgkv_setString(name, expected2, &err);
    XCTAssertEqual(err, 0);

    bsgkv_getString(name, actual, sizeof(actual), &err);
    XCTAssertEqual(err, 0);
    AssertEqualCString(actual, expected2);

    bsgkv_delete(name, &err);
    XCTAssertEqual(err, 0);

    bsgkv_getString(name, actual, sizeof(actual), &err);
    XCTAssertEqual(err, ENOENT);

    bsgkv_setString(name, expected, &err);
    XCTAssertEqual(err, 0);

    bsgkv_getString(name, actual, sizeof(actual), &err);
    XCTAssertEqual(err, 0);
    AssertEqualCString(actual, expected);
}

- (void)testBytes {
    const char* name = "test-bytes";
    const uint8_t expected[] = {0x01, 0x02, 0x03, 0x04, 0x05};
    const uint8_t expected2[] = {0xff, 0xfe, 0x0d};
    uint8_t actual[100];
    int err = 0;
    int length = 0;
    
    bsgkv_delete(name, &err);
    XCTAssertEqual(err, 0);
    
    bsgkv_delete(name, &err);
    XCTAssertEqual(err, 0);

    bsgkv_setBytes(name, expected, sizeof(expected), &err);
    XCTAssertEqual(err, 0);

    length = sizeof(actual);
    bsgkv_getBytes(name, actual, &length, &err);
    XCTAssertEqual(err, 0);
    XCTAssertEqual(length, sizeof(expected));
    XCTAssertEqual(memcmp(actual, expected, sizeof(expected)), 0);

    bsgkv_setBytes(name, expected2, sizeof(expected2), &err);
    XCTAssertEqual(err, 0);

    length = sizeof(actual);
    bsgkv_getBytes(name, actual, &length, &err);
    XCTAssertEqual(err, 0);
    XCTAssertEqual(length, sizeof(expected2));
    XCTAssertEqual(memcmp(actual, expected2, sizeof(expected2)), 0);

    bsgkv_delete(name, &err);
    XCTAssertEqual(err, 0);

    length = sizeof(actual);
    bsgkv_getBytes(name, actual, &length, &err);
    XCTAssertEqual(err, ENOENT);

    bsgkv_setBytes(name, expected, sizeof(expected), &err);
    XCTAssertEqual(err, 0);

    length = sizeof(actual);
    bsgkv_getBytes(name, actual, &length, &err);
    XCTAssertEqual(err, 0);
    XCTAssertEqual(length, sizeof(expected));
    XCTAssertEqual(memcmp(actual, expected, sizeof(expected)), 0);
}

@end
