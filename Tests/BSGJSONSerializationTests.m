//
//  BSGJSONSerializationTests.m
//  Bugsnag
//
//  Created by Karl Stenerud on 03.09.20.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "BSGJSONSerialization.h"

@interface BSGJSONSerializationTests : XCTestCase
@end

@implementation BSGJSONSerializationTests

- (void)testBadJSONKey {
    id badDict = @{@123: @"string"};
    NSData* badJSONData = [@"{123=\"test\"}" dataUsingEncoding:NSUTF8StringEncoding];
    id result;
    NSError* error;
    result = [BSGJSONSerialization dataWithJSONObject:badDict options:0 error:&error];
    XCTAssertNotNil(error);
    XCTAssertNil(result);
    error = nil;
    
    result = [BSGJSONSerialization JSONObjectWithData:badJSONData options:0 error:&error];
    XCTAssertNotNil(error);
    XCTAssertNil(result);
    error = nil;

    NSOutputStream* outstream = [NSOutputStream outputStreamToMemory];
    [outstream open];
    [BSGJSONSerialization writeJSONObject:badDict toStream:outstream options:0 error:&error];
    XCTAssertNotNil(error);
    error = nil;
    
    NSInputStream* instream = [NSInputStream inputStreamWithData:badJSONData];
    [instream open];

    result = [BSGJSONSerialization JSONObjectWithStream:instream options:0 error:&error];
    XCTAssertNotNil(error);
    XCTAssertNil(result);
    error = nil;
}

- (void)testJSONFileSerialization {
    id validJSON = @{@"foo": @"bar"};
    id invalidJSON = @{@"foo": [NSDate date]};
    
    NSString *file = [NSTemporaryDirectory() stringByAppendingPathComponent:@(__PRETTY_FUNCTION__)];
    
    XCTAssertTrue([BSGJSONSerialization writeJSONObject:validJSON toFile:file options:0 error:nil]);

    XCTAssertEqualObjects([BSGJSONSerialization JSONObjectWithContentsOfFile:file options:0 error:nil], @{@"foo": @"bar"});
    
    [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
    
    NSError *error = nil;
    XCTAssertFalse([BSGJSONSerialization writeJSONObject:invalidJSON toFile:file options:0 error:&error]);
    XCTAssertNotNil(error);
    
    error = nil;
    XCTAssertNil([BSGJSONSerialization JSONObjectWithContentsOfFile:file options:0 error:&error]);
    XCTAssertNotNil(error);

    NSString *unwritablePath = @"/System/Library/foobar";
    
    error = nil;
    XCTAssertFalse([BSGJSONSerialization writeJSONObject:validJSON toFile:unwritablePath options:0 error:&error]);
    XCTAssertNotNil(error);
    
    error = nil;
    XCTAssertNil([BSGJSONSerialization JSONObjectWithContentsOfFile:unwritablePath options:0 error:&error]);
    XCTAssertNotNil(error);
}

- (void)testExceptionHandling {
    NSError *error = nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertNil([BSGJSONSerialization JSONObjectWithData:nil options:0 error:&error]);
#pragma clang diagnostic pop
    XCTAssertNotNil(error);
    id underlyingError = error.userInfo[NSUnderlyingErrorKey];
    XCTAssert(!underlyingError || [underlyingError isKindOfClass:[NSError class]], @"The value of %@ should be an NSError", NSUnderlyingErrorKey);
}

@end
