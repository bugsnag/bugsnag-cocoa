//
//  BSGPersistentDeviceIDTests.m
//  Bugsnag-iOSTests
//
//  Created by Karl Stenerud on 27.06.23.
//  Copyright © 2023 Bugsnag Inc. All rights reserved.
//

#import "FileBasedTest.h"
#import "BSGPersistentDeviceID.h"

@interface BSGPersistentDeviceIDTests : FileBasedTest

@end

@implementation BSGPersistentDeviceIDTests

- (BSGPersistentDeviceID *)newDeviceID {
    NSError *error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm createDirectoryAtPath:self.filePath withIntermediateDirectories:YES attributes:nil error:&error]) {
        XCTAssertNil(error);
        XCTAssertTrue(NO, "Failed to create temp dir");
    }

    NSString *path = [self.filePath stringByAppendingPathComponent:@"device-id.json"];
    return [BSGPersistentDeviceID unitTest_deviceIDWithFilePath:path];
}

- (void)testSavePath {
    // Force file creation if it hasn't happened already.
    [BSGPersistentDeviceID current];

    // Save path must be <caches-dir>/bugsnag-shared-<bundle-id>/device-id.json
    NSString *topLevelDir = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    NSString *dirPath = [topLevelDir stringByAppendingFormat:@"/bugsnag-shared-%@", [[NSBundle mainBundle] bundleIdentifier]];
    NSString *filePath = [dirPath stringByAppendingPathComponent:@"device-id.json"];

    NSFileManager *fm = [NSFileManager defaultManager];
    XCTAssertTrue([fm fileExistsAtPath:filePath]);
}

- (void)testGeneratesID {
    BSGPersistentDeviceID *dev = [self newDeviceID];
    XCTAssertEqual(dev.external.length, (NSUInteger)40);
    XCTAssertEqual(dev.internal.length, (NSUInteger)40);
}

- (void)testExternalAndInternalAreDifferent {
    BSGPersistentDeviceID *dev = [self newDeviceID];
    XCTAssertNotEqualObjects(dev.external, dev.internal);
}

- (void)testGeneratesSameID {
    BSGPersistentDeviceID *expected = [self newDeviceID];

    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    [fm removeItemAtPath:self.filePath error:&error];
    XCTAssertNil(error);

    BSGPersistentDeviceID *actual = [self newDeviceID];
    XCTAssertEqualObjects(expected.external, actual.external);
    XCTAssertEqualObjects(expected.internal, actual.internal);
}

- (void)testIDDoesNotChange {
    BSGPersistentDeviceID *expected = [self newDeviceID];
    BSGPersistentDeviceID *actual = [self newDeviceID];

    XCTAssertEqualObjects(expected.external, actual.external);
    XCTAssertEqualObjects(expected.internal, actual.internal);
}

@end
