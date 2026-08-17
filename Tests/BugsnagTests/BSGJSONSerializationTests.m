//
//  BSGJSONSerializationTests.m
//  Bugsnag
//
//  Created by Karl Stenerud on 03.09.20.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import "BSGTestCase.h"

#import "BSGFilesystem.h"
#import "BSGJSONSerialization.h"
#import <TargetConditionals.h>

@interface BSGJSONSerializationTests : BSGTestCase
@end

@implementation BSGJSONSerializationTests

- (NSNumber *)excludedFromBackupAtPath:(NSString *)path {
    NSURL *url = [NSURL fileURLWithPath:path];
    NSNumber *excludedFromBackup = nil;
    [url getResourceValue:&excludedFromBackup
                   forKey:NSURLIsExcludedFromBackupKey
                    error:nil];
    return excludedFromBackup;
}

- (NSString *)newTemporaryPath {
    return [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
}

- (void)testBadJSONKey {
    id badDict = @{@123: @"string"};
    NSData* badJSONData = [@"{123=\"test\"}" dataUsingEncoding:NSUTF8StringEncoding];
    id result;
    NSError* error;
    result = BSGJSONDataFromDictionary(badDict, &error);
    XCTAssertNotNil(error);
    XCTAssertNil(result);
    error = nil;
    
    result = BSGJSONDictionaryFromData(badJSONData, 0, &error);
    XCTAssertNotNil(error);
    XCTAssertNil(result);
    error = nil;
}

- (void)testJSONFileSerialization {
    id validJSON = @{@"foo": @"bar"};
    id invalidJSON = @{@"foo": [NSDate date]};
    
    NSString *file = [NSTemporaryDirectory() stringByAppendingPathComponent:@(__PRETTY_FUNCTION__)];
    
    XCTAssertTrue(BSGJSONWriteToFileAtomically(validJSON, file, nil));

    XCTAssertEqualObjects(BSGJSONDictionaryFromFile(file, 0, nil), @{@"foo": @"bar"});
    
    [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
    
    NSError *error = nil;
    XCTAssertFalse(BSGJSONWriteToFileAtomically(invalidJSON, file, &error));
    XCTAssertNotNil(error);
    
    error = nil;
    XCTAssertNil(BSGJSONDictionaryFromFile(file, 0, &error));
    XCTAssertNotNil(error);

    NSString *unwritablePath = @"/System/Library/foobar";
    
    error = nil;
    XCTAssertFalse(BSGJSONWriteToFileAtomically(validJSON, unwritablePath, &error));
    XCTAssertNotNil(error);
    
    error = nil;
    XCTAssertNil(BSGJSONDictionaryFromFile(file, 0, &error));
    XCTAssertNotNil(error);
}

- (void)testExceptionHandling {
    NSError *error = nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertNil(BSGJSONDictionaryFromData(nil, 0, &error));
#pragma clang diagnostic pop
    XCTAssertNotNil(error);
    id underlyingError = error.userInfo[NSUnderlyingErrorKey];
    XCTAssert(!underlyingError || [underlyingError isKindOfClass:[NSError class]], @"The value of %@ should be an NSError", NSUnderlyingErrorKey);
}

- (void)testEnsurePathExistsAppliesBackupExclusionByDefault {
    NSString *directory = [self newTemporaryPath];
    @try {
        [BSGFilesystem setFileBackupSupport:NO];
        XCTAssertNil([BSGFilesystem ensurePathExists:directory]);

#if TARGET_OS_TV
        XCTAssertNil([self excludedFromBackupAtPath:directory]);
#else
        XCTAssertEqualObjects([self excludedFromBackupAtPath:directory], @YES);
#endif
    } @finally {
        [[NSFileManager defaultManager] removeItemAtPath:directory error:nil];
    }
}

- (void)testEnsurePathExistsAppliesBackupInclusionWhenEnabled {
    NSString *directory = [self newTemporaryPath];
    @try {
        [BSGFilesystem setFileBackupSupport:YES];
        XCTAssertNil([BSGFilesystem ensurePathExists:directory]);

#if TARGET_OS_TV
        XCTAssertNil([self excludedFromBackupAtPath:directory]);
#else
        XCTAssertEqualObjects([self excludedFromBackupAtPath:directory], @NO);
#endif
    } @finally {
        [[NSFileManager defaultManager] removeItemAtPath:directory error:nil];
        [BSGFilesystem setFileBackupSupport:NO];
    }
}

- (void)testApplyFileBackupSupportToPathAndContentsUpdatesNestedItems {
    NSString *root = [self newTemporaryPath];
    NSString *nestedDir = [root stringByAppendingPathComponent:@"nested"];
    NSString *nestedFile = [nestedDir stringByAppendingPathComponent:@"child.json"];

    @try {
        [BSGFilesystem setFileBackupSupport:NO];
        XCTAssertNil([BSGFilesystem ensurePathExists:nestedDir]);
        NSData *payload = [@"{}" dataUsingEncoding:NSUTF8StringEncoding];
        NSError *error = nil;
        XCTAssertTrue([payload writeToFile:nestedFile options:0 error:&error]);
        XCTAssertNil(error);

        [BSGFilesystem setFileBackupSupport:YES];
        [BSGFilesystem applyFileBackupSupportToPathAndContents:root];

#if TARGET_OS_TV
        XCTAssertNil([self excludedFromBackupAtPath:root]);
        XCTAssertNil([self excludedFromBackupAtPath:nestedDir]);
        XCTAssertNil([self excludedFromBackupAtPath:nestedFile]);
#else
        XCTAssertEqualObjects([self excludedFromBackupAtPath:root], @NO);
        XCTAssertEqualObjects([self excludedFromBackupAtPath:nestedDir], @NO);
        XCTAssertEqualObjects([self excludedFromBackupAtPath:nestedFile], @NO);
#endif
    } @finally {
        [[NSFileManager defaultManager] removeItemAtPath:root error:nil];
        [BSGFilesystem setFileBackupSupport:NO];
    }
}

- (void)testWriteDataAppliesBackupSupportAfterAtomicReplacement {
    NSString *file = [self newTemporaryPath];

    @try {
        [BSGFilesystem setFileBackupSupport:NO];
        NSData *first = [@"{\"a\":1}" dataUsingEncoding:NSUTF8StringEncoding];
        NSError *error = nil;
        XCTAssertTrue([BSGFilesystem writeData:first toFile:file options:NSDataWritingAtomic error:&error]);
        XCTAssertNil(error);

#if !TARGET_OS_TV
        XCTAssertEqualObjects([self excludedFromBackupAtPath:file], @YES);
#endif

        [BSGFilesystem setFileBackupSupport:YES];
        NSData *second = [@"{\"a\":2}" dataUsingEncoding:NSUTF8StringEncoding];
        XCTAssertTrue([BSGFilesystem writeData:second toFile:file options:NSDataWritingAtomic error:&error]);
        XCTAssertNil(error);

#if TARGET_OS_TV
        XCTAssertNil([self excludedFromBackupAtPath:file]);
#else
        XCTAssertEqualObjects([self excludedFromBackupAtPath:file], @NO);
#endif
    } @finally {
        [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
        [BSGFilesystem setFileBackupSupport:NO];
    }
}

- (void)testJSONWriteToFileAtomicallyAppliesBackupSupport {
    NSString *file = [self newTemporaryPath];

    @try {
        [BSGFilesystem setFileBackupSupport:NO];
        XCTAssertTrue(BSGJSONWriteToFileAtomically(@{@"foo": @"bar"}, file, nil));

#if !TARGET_OS_TV
        XCTAssertEqualObjects([self excludedFromBackupAtPath:file], @YES);
#endif

        [BSGFilesystem setFileBackupSupport:YES];
        XCTAssertTrue(BSGJSONWriteToFileAtomically(@{@"foo": @"baz"}, file, nil));

#if TARGET_OS_TV
        XCTAssertNil([self excludedFromBackupAtPath:file]);
#else
        XCTAssertEqualObjects([self excludedFromBackupAtPath:file], @NO);
#endif
    } @finally {
        [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
        [BSGFilesystem setFileBackupSupport:NO];
    }
}

@end
