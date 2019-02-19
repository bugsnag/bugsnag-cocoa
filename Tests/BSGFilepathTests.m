//
//  BSGFilepathTests.m
//  Tests
//
//  Created by Delisa on 2/19/19.
//  Copyright © 2019 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>
#include <string.h>


int bsg_create_filepath(char *base, char filepath[512], char severity, char error_class[21]);

@interface BSGFilepathTests : XCTestCase

@end

@implementation BSGFilepathTests

- (void)testEncodeCharacters {
    char *base = "/path/to/it/imagine this is a UUID.json";
    char filepath[512];
    bsg_create_filepath(base, filepath, 'w', "😃 HappyError");
    XCTAssertEqual(0, strcmp(filepath, "/path/to/it/imagine this is a UUID-w-u- HappyError.json"));
}

- (void)testTruncateUnicodeCharacters {
    char *base = "/path/to/it/imagine this is a UUID.json";
    char filepath[512];
    // The char limit is not on a character boundary
    bsg_create_filepath(base, filepath, 'e', "AnExtremelyLongLong😃");
    XCTAssertEqual(0, strcmp(filepath, "/path/to/it/imagine this is a UUID-e-u-AnExtremelyLongLong.json"));
}

- (void)testNullErrorClass {
    char *base = "/path/to/it/imagine this is a UUID.json";
    char filepath[512];
    bsg_create_filepath(base, filepath, 'e', NULL);
    XCTAssertEqual(0, strcmp(filepath, "/path/to/it/imagine this is a UUID-e-u-.json"));
}

- (void)testEmptyErrorClass {
    char *base = "/path/to/it/imagine this is a UUID.json";
    char filepath[512];
    bsg_create_filepath(base, filepath, 'e', "");
    XCTAssertEqual(0, strcmp(filepath, "/path/to/it/imagine this is a UUID-e-u-.json"));
}

- (void)testEmptyErrorClassFromUnicode {
    char *base = "/path/to/it/imagine this is a UUID.json";
    char filepath[512];
    bsg_create_filepath(base, filepath, 'e', "🀦🀨🁺😃");
    XCTAssertEqual(0, strcmp(filepath, "/path/to/it/imagine this is a UUID-e-u-.json"));
}

- (void)testErrorClassLength {
    char *base = "imagine this is a UUID.json";
    char filepath[512];
    bsg_create_filepath(base, filepath, 'i', "AnExtremelyLongLongErrorNameOmg");
    XCTAssertEqual(0, strcmp(filepath, "imagine this is a UUID-i-u-AnExtremelyLongLongEr.json"));
}

@end
