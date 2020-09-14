//
//  BSGJSONSerializerTest.m
//  Bugsnag
//
//  Created by Karl Stenerud on 03.09.20.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "BSGJSONSerialization.h"

@interface BSGJSONSerializerTest : XCTestCase

@end

@implementation BSGJSONSerializerTest

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

@end
