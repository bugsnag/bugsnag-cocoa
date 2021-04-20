//
//  KSJSONCodec_Tests.m
//
//  Created by Karl Stenerud on 2012-01-08.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//


#import <XCTest/XCTest.h>

#import "BSG_KSJSONCodecObjC.h"


@interface KSJSONCodec_Tests : XCTestCase @end


@implementation KSJSONCodec_Tests

static NSData* toData(NSString* string)
{
    if(string == nil)
    {
        return nil;
    }
    return [string dataUsingEncoding:NSUTF8StringEncoding];
}

static NSString* toString(NSData* data)
{
    if(data == nil)
    {
        return nil;
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (void)testSerializeDeserializeArrayEmpty
{
    NSError* error = (NSError*)self;
    NSString* expected = @"[]";
    id original = [NSArray array];
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void) testSerializeDeserializeArrayNull
{
    NSError* error = (NSError*)self;
    NSString* expected = @"[null]";
    id original = @[[NSNull null]];
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void) testSerializeDeserializeArrayBoolTrue
{
    NSError* error = (NSError*)self;
    NSString* expected = @"[true]";
    id original = @[@YES];
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void) testSerializeDeserializeArrayBoolFalse
{
    NSError* error = (NSError*)self;
    NSString* expected = @"[false]";
    id original = @[@NO];
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

//- (void) testSerializeDeserializeArrayInteger
//{
//    NSError* error = (NSError*)self;
//    NSString* expected = @"[1]";
//    id original = @[@1];
//    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
//                                                options:BSG_KSJSONEncodeOptionSorted
//                                                  error:&error]);
//    XCTAssertNotNil(jsonString, @"");
//    XCTAssertNil(error, @"");
//    XCTAssertEqualObjects(jsonString, expected, @"");
//    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
//    XCTAssertNotNil(result, @"");
//    XCTAssertNil(error, @"");
//    XCTAssertEqualObjects(result, original, @"");
//}

- (void) testSerializeDeserializeArrayFloat
{
    NSError* error = (NSError*)self;
    NSString* expected = @"[-2e-1]";
    id original = @[@(-0.2f)];
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqual([[result objectAtIndex:0] floatValue], -0.2f, @"");
    // This always fails on NSNumber filled with float.
    //XCTAssertEqualObjects(result, original, @"");
}

- (void) testSerializeDeserializeArrayFloat2
{
    NSError* error = (NSError*)self;
    NSString* expected = @"[-2e-15]";
    id original = @[@(-2e-15f)];
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqual([[result objectAtIndex:0] floatValue], -2e-15f, @"");
    // This always fails on NSNumber filled with float.
    //XCTAssertEqualObjects(result, original, @"");
}

- (void)testSerializeDeserializeArrayString
{
    NSError* error = (NSError*)self;
    NSString* expected = @"[\"One\"]";
    id original = @[@"One"];
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void)testSerializeDeserializeArrayStringIntl
{
    NSError* error = (NSError*)self;
    NSString* expected = @"[\"テスト\"]";
    id original = @[@"テスト"];
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void)testSerializeDeserializeArrayMultipleEntries
{
    NSError* error = (NSError*)self;
    NSString* expected = @"[\"One\",1000,true]";
    id original = @[@"One",
            @1000,
            @YES];
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void)testSerializeDeserializeArrayMultipleEntriesSorted
{
    NSError* error = (NSError*)self;
    NSString* expected = @"[\"One\",\"Three\",\"Two\"]";
    id original = @[@"One",
            @"Two",
            @"Three"];
    id sorted = @[@"One",
            @"Three",
            @"Two"];
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, sorted, @"");
}

- (void)testSerializeDeserializeArrayWithArray
{
    NSError* error = (NSError*)self;
    NSString* expected = @"[[]]";
    id original = @[[NSArray array]];
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void)testSerializeDeserializeArrayWithArray2
{
    NSError* error = (NSError*)self;
    NSString* expected = @"[[\"Blah\"]]";
    id original = @[@[@"Blah"]];
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void)testSerializeDeserializeArrayWithDictionary
{
    NSError* error = (NSError*)self;
    NSString* expected = @"[{}]";
    id original = @[[NSDictionary dictionary]];
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void)testSerializeDeserializeArrayWithDictionary2
{
    NSError* error = (NSError*)self;
    NSString* expected = @"[{\"Blah\":true}]";
    id original = @[@{@"Blah": @YES}];
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}


- (void)testSerializeDeserializeDictionaryEmpty
{
    NSError* error = (NSError*)self;
    NSString* expected = @"{}";
    id original = [NSDictionary dictionary];
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void) testSerializeDeserializeDictionaryNull
{
    NSError* error = (NSError*)self;
    NSString* expected = @"{\"One\":null}";
    id original = @{@"One": [NSNull null]};
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void) testSerializeDeserializeDictionaryBoolTrue
{
    NSError* error = (NSError*)self;
    NSString* expected = @"{\"One\":true}";
    id original = @{@"One": @YES};
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void) testSerializeDeserializeDictionaryBoolFalse
{
    NSError* error = (NSError*)self;
    NSString* expected = @"{\"One\":false}";
    id original = @{@"One": @NO};
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void) testSerializeDeserializeDictionaryInteger
{
    NSError* error = (NSError*)self;
    NSString* expected = @"{\"One\":1}";
    id original = @{@"One": @1};
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void) testSerializeDeserializeDictionaryFloat
{
    NSError* error = (NSError*)self;
    NSString* expected = @"{\"One\":5.4918e+1}";
    id original = @{@"One": @54.918F};
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqual([((NSDictionary *) result)[@"One"] floatValue], 54.918f, @"");
    // This always fails on NSNumber filled with float.
    //XCTAssertEqualObjects(result, original, @"");
}

- (void) assertInt:(int64_t) value convertsTo:(NSString *)str
{
    NSError* error = (NSError*)self;
    NSString* expected = [NSString stringWithFormat:@"{\"One\":%@}", str];
    id original = @{@"One": @(value)};
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
}

- (void) assertDouble:(double) value convertsTo:(NSString *)str
{
    NSError* error = (NSError*)self;
    NSString* expected = [NSString stringWithFormat:@"{\"One\":%@}", str];
    id original = @{@"One": @(value)};
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
}

- (void) testIntConversions
{
    [self assertInt:0 convertsTo:@"0"];
    [self assertInt:1 convertsTo:@"1"];
    [self assertInt:-1 convertsTo:@"-1"];
    [self assertInt:127 convertsTo:@"127"];
    [self assertInt:-127 convertsTo:@"-127"];
    [self assertInt:128 convertsTo:@"128"];
    [self assertInt:-128 convertsTo:@"-128"];
    [self assertInt:255 convertsTo:@"255"];
    [self assertInt:-255 convertsTo:@"-255"];
    [self assertInt:256 convertsTo:@"256"];
    [self assertInt:-256 convertsTo:@"-256"];
    [self assertInt:65535 convertsTo:@"65535"];
    [self assertInt:-65535 convertsTo:@"-65535"];
    [self assertInt:65536 convertsTo:@"65536"];
    [self assertInt:-65536 convertsTo:@"-65536"];
    [self assertInt:4294967295 convertsTo:@"4294967295"];
    [self assertInt:-4294967295 convertsTo:@"-4294967295"];
    [self assertInt:4294967296 convertsTo:@"4294967296"];
    [self assertInt:-4294967296 convertsTo:@"-4294967296"];
    [self assertInt:9223372036854775807ll convertsTo:@"9223372036854775807"];
    // This gets incorrectly flagged as too large for int64
    [self assertInt:-9223372036854775808ll convertsTo:@"-9223372036854775808"];
}

- (void) testFloatConversions
{
    [self assertDouble:100000000 convertsTo:@"1e+8"];
    [self assertDouble:10000000 convertsTo:@"1e+7"];
    [self assertDouble:1000000 convertsTo:@"1e+6"];
    [self assertDouble:100000 convertsTo:@"1e+5"];
    [self assertDouble:10000 convertsTo:@"1e+4"];
    [self assertDouble:1000 convertsTo:@"1e+3"];
    [self assertDouble:100 convertsTo:@"1e+2"];
    [self assertDouble:10 convertsTo:@"1e+1"];
    [self assertDouble:1 convertsTo:@"1"];
    [self assertDouble:0.1 convertsTo:@"1e-1"];
    [self assertDouble:0.01 convertsTo:@"1e-2"];
    [self assertDouble:0.001 convertsTo:@"1e-3"];
    [self assertDouble:0.0001 convertsTo:@"1e-4"];
    [self assertDouble:0.00001 convertsTo:@"1e-5"];
    [self assertDouble:0.000001 convertsTo:@"1e-6"];
    [self assertDouble:0.0000001 convertsTo:@"1e-7"];
    [self assertDouble:0.00000001 convertsTo:@"1e-8"];

    [self assertDouble:1.2 convertsTo:@"1.2"];
    [self assertDouble:0.12 convertsTo:@"1.2e-1"];
    [self assertDouble:12 convertsTo:@"1.2e+1"];
    [self assertDouble:9.5932455 convertsTo:@"9.593246"];
    [self assertDouble:1.456e+80 convertsTo:@"1.456e+80"];
    [self assertDouble:1.456e-80 convertsTo:@"1.456e-80"];
    [self assertDouble:-1.456e+80 convertsTo:@"-1.456e+80"];
    [self assertDouble:-1.456e-80 convertsTo:@"-1.456e-80"];
    [self assertDouble:1.5e-10 convertsTo:@"1.5e-10"];
    [self assertDouble:123456789123456789 convertsTo:@"1.234568e+17"];

    [self assertDouble:NAN convertsTo:@"nan"];
    [self assertDouble:INFINITY convertsTo:@"inf"];
    [self assertDouble:-INFINITY convertsTo:@"-inf"];

    // Check stepping over the 7 significant digit limit
    [self assertDouble:9999999 convertsTo:@"9.999999e+6"];
    [self assertDouble:99999994 convertsTo:@"9.999999e+7"];
    [self assertDouble:99999995 convertsTo:@"1e+8"];
    [self assertDouble:99999999 convertsTo:@"1e+8"];
}

- (void) testSerializeDeserializeDictionaryFloat2
{
    NSError* error = (NSError*)self;
    NSString* expected = @"{\"One\":5e+20}";
    id original = @{@"One": @5e20F};
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqual([((NSDictionary *) result)[@"One"] floatValue], 5e20f, @"");
    // This always fails on NSNumber filled with float.
    //XCTAssertEqualObjects(result, original, @"");
}

- (void)testSerializeDeserializeDictionaryString
{
    NSError* error = (NSError*)self;
    NSString* expected = @"{\"One\":\"Value\"}";
    id original = @{@"One": @"Value"};
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void)testSerializeDeserializeDictionaryMultipleEntries
{
    NSError* error = (NSError*)self;
    NSString* expected = @"{\"One\":\"Value\",\"Three\":true,\"Two\":1000}";
    id original = @{@"One": @"Value",
            @"Two": @1000,
            @"Three": @YES};
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void)testSerializeDeserializeDictionaryWithDictionary
{
    NSError* error = (NSError*)self;
    NSString* expected = @"{\"One\":{}}";
    id original = @{@"One": [NSDictionary dictionary]};
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void)testSerializeDeserializeDictionaryWithDictionary2
{
    NSError* error = (NSError*)self;
    NSString* expected = @"{\"One\":{\"Blah\":1}}";
    id original = @{@"One": @{@"Blah": @1}};
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void)testSerializeDeserializeDictionaryWithArray
{
    NSError* error = (NSError*)self;
    NSString* expected = @"{\"Key\":[]}";
    id original = @{@"Key": [NSArray array]};
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void)testSerializeDeserializeDictionaryWithArray2
{
    NSError* error = (NSError*)self;
    NSString* expected = @"{\"Blah\":[true]}";
    id original = @{@"Blah": @[@YES]};
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void)testSerializeDeserializeBigDictionary
{
    NSError* error = (NSError*)self;
    id original = @{@"0": @"0",
            @"1": @"1",
            @"2": @"2",
            @"3": @"3",
            @"4": @"4",
            @"5": @"5",
            @"6": @"6",
            @"7": @"7",
            @"8": @"8",
            @"9": @"9",
            @"10": @"10",
            @"11": @"11",
            @"12": @"12",
            @"13": @"13",
            @"14": @"14",
            @"15": @"15",
            @"16": @"16",
            @"17": @"17",
            @"18": @"18",
            @"19": @"19",
            @"20": @"20",
            @"21": @"21",
            @"22": @"22",
            @"23": @"23",
            @"24": @"24",
            @"25": @"25",
            @"26": @"26",
            @"27": @"27",
            @"28": @"28",
            @"29": @"29",
            @"30": @"30",
            @"31": @"31",
            @"32": @"32",
            @"33": @"33",
            @"34": @"34",
            @"35": @"35",
            @"36": @"36",
            @"37": @"37",
            @"38": @"38",
            @"39": @"39",
            @"40": @"40",
            @"41": @"41",
            @"42": @"42",
            @"43": @"43",
            @"44": @"44",
            @"45": @"45",
            @"46": @"46",
            @"47": @"47",
            @"48": @"48",
            @"49": @"49",
            @"50": @"50",
            @"51": @"51",
            @"52": @"52",
            @"53": @"53",
            @"54": @"54",
            @"55": @"55",
            @"56": @"56",
            @"57": @"57",
            @"58": @"58",
            @"59": @"59"};
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void)testSerializeDeserializeDeep
{
    NSError* error = (NSError*)self;
    NSString* expected = @"{\"a0\":\"A0\",\"a1\":{\"b0\":{\"c0\":\"C0\",\"c1\":{\"d0\":[[],[],[]],\"d1\":\"D1\"}},\"b1\":\"B1\"},\"a2\":\"A2\"}";
    id original = @{@"a0": @"A0",
            @"a1": @{@"b0": @{@"c0": @"C0",
                    @"c1": @{@"d0": @[[NSArray array], [NSArray array], [NSArray array]],
                            @"d1": @"D1"}},
                    @"b1": @"B1"},
            @"a2": @"A2"};

    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void) testDeserializeUnicode
{
    NSError* error = (NSError*)self;
    NSString* json = @"[\"\u00dcOne\"]";
    NSString* expected = @"\u00dcOne";
    NSArray* result = [BSG_KSJSONCodec decode:toData(json) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    NSString* value = result[0];
    XCTAssertEqualObjects(value, expected, @"");
}

- (void) testDeserializeUnicode2
{
    NSError* error = (NSError*)self;
    NSString* json = @"[\"\\u827e\\u5c0f\\u8587\"]";
    NSString* expected = @"\u827e\u5c0f\u8587";
    NSArray* result = [BSG_KSJSONCodec decode:toData(json) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    NSString* value = result[0];
    XCTAssertEqualObjects(value, expected, @"");
}

- (void) testDeserializeUnicodeControlChars
{
    NSError* error = nil;
    NSString* json = @"[\"\\n\\u0000\\r\"]";
    NSString* expected = @"\n\x00\r";
    NSArray* result = [BSG_KSJSONCodec decode:toData(json) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqual(1, result.count);
    NSString* value = result[0];
    XCTAssertNotNil(value);
    XCTAssertEqualObjects(value, expected, @"");
}

- (void) testDeserializeUnicodeControlChars2
{
    NSError* error = nil;
    NSString* json = @"[\"\\n\\u0008\\r\"]";
    NSString* expected = @"\n\b\r";
    NSArray* result = [BSG_KSJSONCodec decode:toData(json) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqual(1, result.count);
    NSString* value = result[0];
    XCTAssertNotNil(value);
    XCTAssertEqualObjects(value, expected, @"");
}

- (void) testDeserializeUnicodeExtended
{
    NSError* error = (NSError*)self;
    NSString* json = @"[\"ABC\U00010323DEFGHIJ\"]";
    NSString* expected = @"ABC𐌣DEFGHIJ";
    NSArray* result = [BSG_KSJSONCodec decode:toData(json) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    NSString* value = result[0];
    XCTAssertEqualObjects(value, expected, @"");
}

- (void) testDeserializeUnicodeExtended2
{
    NSError* error = nil;
    NSString* json = @"[\"G\\uD834\\uDD1E\"]";
    NSString* expected = @"G𝄞";
    NSArray* result = [BSG_KSJSONCodec decode:toData(json) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    NSString* value = result[0];
    XCTAssertEqualObjects(value, expected, @"");
}

- (void) testDeserializeUnicodeExtendedLoneTrailSurrogate
{
    NSError* error = (NSError*)self;
    NSString* json = @"[\"ABC\\ud840DEFGHIJ\"]";
    NSArray* result = [BSG_KSJSONCodec decode:toData(json) error:&error];
    XCTAssertNil(result, @"");
    XCTAssertNotNil(error, @"");
}

- (void) testDeserializeUnicodeExtendedMissingTrailSurrogate
{
    NSError* error = (NSError*)self;
    NSString* json = @"[\"ABC\\udf23DEFGHIJ\"]";
    NSArray* result = [BSG_KSJSONCodec decode:toData(json) error:&error];
    XCTAssertNil(result, @"");
    XCTAssertNotNil(error, @"");
}

- (void) testDeserializeUnicodeExtendedMissingTrailSurrogate2
{
    NSError* error = (NSError*)self;
    NSString* json = @"[\"ABC\\udf23\\u1234DEFGHIJ\"]";
    NSArray* result = [BSG_KSJSONCodec decode:toData(json) error:&error];
    XCTAssertNil(result, @"");
    XCTAssertNotNil(error, @"");
}

- (void) testDeserializeUnicodeExtendedCutOff
{
    NSError* error = (NSError*)self;
    NSString* json = @"[\"ABC\\udf23\"]";
    NSArray* result = [BSG_KSJSONCodec decode:toData(json) error:&error];
    XCTAssertNil(result, @"");
    XCTAssertNotNil(error, @"");
}

- (void) testDeserializeControlChars
{
    NSError* error = (NSError*)self;
    NSString* json = @"[\"\\b\\f\\n\\r\\t\"]";
    NSString* expected = @"\b\f\n\r\t";
    NSArray* result = [BSG_KSJSONCodec decode:toData(json) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    NSString* value = result[0];
    XCTAssertEqualObjects(value, expected, @"");
}

- (void) testSerializeDeserializeControlChars2
{
    NSError* error = (NSError*)self;
    NSString* expected = @"[\"\\b\\f\\n\\r\\t\"]";
    id original = @[@"\b\f\n\r\t"];
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void) testSerializeDeserializeControlChars3
{
    NSError* error = (NSError*)self;
    NSString* expected = @"[\"Testing\\b escape \\f chars\\n\"]";
    id original = @[@"Testing\b escape \f chars\n"];
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void) testSerializeDeserializeEscapedChars
{
    NSError* error = (NSError*)self;
    NSString* expected = @"[\"\\\"\\\\\"]";
    id original = @[@"\"\\"];
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void) testSerializeDeserializeFloat
{
    NSError* error = (NSError*)self;
    NSString* expected = @"[1.2]";
    id original = @[@1.2F];
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertTrue([[result objectAtIndex:0] floatValue] ==  [[original objectAtIndex:0] floatValue], @"");
}

- (void) testSerializeDeserializeDouble
{
    NSError* error = (NSError*)self;
    NSString* expected = @"[1e-1]";
    id original = @[@0.1];
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertTrue([[result objectAtIndex:0] floatValue] ==  [[original objectAtIndex:0] floatValue], @"");
}

- (void) testSerializeDeserializeChar
{
    NSError* error = (NSError*)self;
    NSString* expected = @"[20]";
    id original = @[@20];
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void) testSerializeDeserializeShort
{
    NSError* error = (NSError*)self;
    NSString* expected = @"[2000]";
    id original = @[@2000];
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void) testSerializeDeserializeLong
{
    NSError* error = (NSError*)self;
    NSString* expected = @"[2000000000]";
    id original = @[@2000000000];
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void) testSerializeDeserializeLongLong
{
    NSError* error = (NSError*)self;
    NSString* expected = @"[200000000000]";
    id original = @[@200000000000];
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void) testSerializeDeserializeNegative
{
    NSError* error = (NSError*)self;
    NSString* expected = @"[-2000]";
    id original = @[@(-2000)];
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void) testSerializeDeserialize0
{
    NSError* error = (NSError*)self;
    NSString* expected = @"[0]";
    id original = @[@0];
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void) testSerializeDeserializeEmptyString
{
    NSError* error = (NSError*)self;
    NSString* string = @"";
    NSString* expected = @"[\"\"]";
    id original = @[string];
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void) testSerializeDeserializeBigString
{
    NSError* error = (NSError*)self;

    int length = 500;
    NSMutableString* string = [NSMutableString stringWithCapacity:(NSUInteger)length];
    for(int i = 0; i < length; i++)
    {
        [string appendFormat:@"%d", i%10];
    }

    NSString* expected = [NSString stringWithFormat:@"[\"%@\"]", string];
    id original = @[string];
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(jsonString, expected, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void) testSerializeDeserializeHugeString
{
    NSError* error = (NSError*)self;
    char buff[100000];
    memset(buff, '2', sizeof(buff));
    buff[sizeof(buff)-1] = 0;
    NSString* string = [NSString stringWithCString:buff encoding:NSUTF8StringEncoding];

    id original = @[string];
    NSString* jsonString = toString([BSG_KSJSONCodec encode:original
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(jsonString, @"");
    XCTAssertNil(error, @"");
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, original, @"");
}

- (void) testSerializeDeserializeLargeArray
{
    NSError* error = (NSError*)self;
    unsigned int numEntries = 2000;

    NSMutableString* jsonString = [NSMutableString string];
    [jsonString appendString:@"["];
    for(unsigned int i = 0; i < numEntries; i++)
    {
        [jsonString appendFormat:@"%d,", i%10];
    }
    [jsonString deleteCharactersInRange:NSMakeRange([jsonString length]-1, 1)];
    [jsonString appendString:@"]"];

    NSArray* deserialized = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    unsigned int deserializedCount = (unsigned int)[deserialized count];
    XCTAssertNotNil(deserialized, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqual(deserializedCount, numEntries, @"");
    NSString* serialized = toString([BSG_KSJSONCodec encode:deserialized
                                                options:0
                                                  error:&error]);
    XCTAssertNotNil(serialized, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(serialized, jsonString, @"");
    int value = [deserialized[1] intValue];
    XCTAssertEqual(value, 1, @"");
    value = [deserialized[9] intValue];
    XCTAssertEqual(value, 9, @"");
}

- (void) testSerializeDeserializeLargeDictionary
{
    NSError* error = (NSError*)self;
    unsigned int numEntries = 2000;

    NSMutableString* jsonString = [NSMutableString string];
    [jsonString appendString:@"{"];
    for(unsigned int i = 0; i < numEntries; i++)
    {
        [jsonString appendFormat:@"\"%d\":%d,", i, i];
    }
    [jsonString deleteCharactersInRange:NSMakeRange([jsonString length]-1, 1)];
    [jsonString appendString:@"}"];

    NSDictionary* deserialized = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    unsigned int deserializedCount = (unsigned int)[deserialized count];
    XCTAssertNotNil(deserialized, @"");
    XCTAssertNil(error, @"");
    XCTAssertEqual(deserializedCount, numEntries, @"");
    int value = [((NSDictionary *) deserialized)[@"1"] intValue];
    XCTAssertEqual(value, 1, @"");
    NSString* serialized = toString([BSG_KSJSONCodec encode:deserialized
                                                options:BSG_KSJSONEncodeOptionSorted
                                                  error:&error]);
    XCTAssertNotNil(serialized, @"");
    XCTAssertNil(error, @"");
    XCTAssertTrue([serialized length] == [jsonString length], @"");
}

- (void) testDeserializeArrayMissingTerminator
{
    NSError* error = (NSError*)self;
    NSString* json = @"[\"blah\"";
    NSArray* result = [BSG_KSJSONCodec decode:toData(json) error:&error];
    XCTAssertNil(result, @"");
    XCTAssertNotNil(error, @"");
}

//- (void) testSerializeBadTopLevelType
//{
//    NSError* error = (NSError*)self;
//    id source = @"Blah";
//    NSString* result = toString([BSG_KSJSONCodec encode:source error:&error]);
//    XCTAssertNil(result, @"");
//    XCTAssertNotNil(error, @"");
//}

- (void) testSerializeArrayBadType
{
    NSError* error = (NSError*)self;
    id source = @[[NSValue valueWithPointer:NULL]];
    NSString* result = toString([BSG_KSJSONCodec encode:source
                                            options:BSG_KSJSONEncodeOptionSorted
                                              error:&error]);
    XCTAssertNil(result, @"");
    XCTAssertNotNil(error, @"");
}

- (void) testSerializeDictionaryBadType
{
    NSError* error = (NSError*)self;
    id source = @{@"blah": [NSValue valueWithPointer:NULL]};
    NSString* result = toString([BSG_KSJSONCodec encode:source
                                            options:BSG_KSJSONEncodeOptionSorted
                                              error:&error]);
    XCTAssertNil(result, @"");
    XCTAssertNotNil(error, @"");
}

- (void) testSerializeDictionaryBadCharacter
{
    NSError* error = (NSError*)self;
    id source = @{@"blah\x01blah": @"blah"};
    NSString* result = toString([BSG_KSJSONCodec encode:source
                                            options:BSG_KSJSONEncodeOptionSorted
                                              error:&error]);
    XCTAssertEqualObjects(result, @"{\"blah\\u001Blah\":\"blah\"}");
    XCTAssertNil(error, @"");
}

- (void) testSerializeArrayBadCharacter
{
    NSError* error = (NSError*)self;
    id source = @[@"test\x01ing"];
    NSString* result = toString([BSG_KSJSONCodec encode:source
                                            options:BSG_KSJSONEncodeOptionSorted
                                              error:&error]);
    XCTAssertEqualObjects(result, @"[\"test\\u0001ing\"]");
    XCTAssertNil(error, @"");
}

- (void) testSerializeLongString
{
    NSError* error = (NSError*)self;
    // Long string with a leading escaped character to ensure it exceeds the length
    // of the buffer in one iteration
    id source = @"\"12345678901234567890123456789012345678901234567890"
                @"12345678901234567890123456789012345678901234567890"
                @"12345678901234567890123456789012345678901234567890"
                @"12345678901234567890123456789012345678901234567890"
                @"12345678901234567890123456789012345678901234567890"
                @"12345678901234567890123456789012345678901234567890"
                @"12345678901234567890123456789012345678901234567890"
                @"12345678901234567890123456789012345678901234567890"
                @"12345678901234567890123456789012345678901234567890"
                @"12345678901234567890123456789012345678901234567890"
                @"12345678901234567890123456789012345678901234567890"
                @"12345678901234567890123456789012345678901234567890"
                @"12345678901234567890123456789012345678901234567890"
                @"12345678901234567890123456789012345678901234567890"
                @"12345678901234567890123456789012345678901234567890"
                @"12345678901234567890123456789012345678901234567890"
                @"12345678901234567890123456789012345678901234567890"
                @"12345678901234567890123456789012345678901234567890"
                @"12345678901234567890123456789012345678901234567890"
                @"12345678901234567890123456789012345678901234567890";
    NSString* result = toString([BSG_KSJSONCodec encode:source
                                            options:BSG_KSJSONEncodeOptionSorted
                                              error:&error]);
    XCTAssertEqualObjects(result, @"\""
                          @"\\\"12345678901234567890123456789012345678901234567890"
                          @"12345678901234567890123456789012345678901234567890"
                          @"12345678901234567890123456789012345678901234567890"
                          @"12345678901234567890123456789012345678901234567890"
                          @"12345678901234567890123456789012345678901234567890"
                          @"12345678901234567890123456789012345678901234567890"
                          @"12345678901234567890123456789012345678901234567890"
                          @"12345678901234567890123456789012345678901234567890"
                          @"12345678901234567890123456789012345678901234567890"
                          @"12345678901234567890123456789012345678901234567890"
                          @"12345678901234567890123456789012345678901234567890"
                          @"12345678901234567890123456789012345678901234567890"
                          @"12345678901234567890123456789012345678901234567890"
                          @"12345678901234567890123456789012345678901234567890"
                          @"12345678901234567890123456789012345678901234567890"
                          @"12345678901234567890123456789012345678901234567890"
                          @"12345678901234567890123456789012345678901234567890"
                          @"12345678901234567890123456789012345678901234567890"
                          @"12345678901234567890123456789012345678901234567890"
                          @"12345678901234567890123456789012345678901234567890"
                          "\"");
    XCTAssertNil(error, @"");
}

- (void) testSerializeEscapeLongString
{
    NSError* error = (NSError*)self;
    id source = @"\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01"
                @"\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01"
                @"\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01"
                @"\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01"
                @"\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01"
                @"\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01"
                @"\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01"
                @"\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01"
                @"\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01"
                @"\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01";
    NSString* result = toString([BSG_KSJSONCodec encode:source
                                            options:BSG_KSJSONEncodeOptionSorted
                                              error:&error]);
    XCTAssertEqualObjects(result, @"\"\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001"
                                  @"\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001"
                                  @"\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001"
                                  @"\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001"
                                  @"\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001"
                                  @"\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001"
                                  @"\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001"
                                  @"\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001"
                                  @"\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001"
                                  @"\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\\u0001\"");
    XCTAssertNil(error, @"");
}

- (void)testDeserializeArrayInvalidUnicodeSequence
{
    NSError* error = (NSError*)self;
    NSString* jsonString = @"[\"One\\ubarfTwo\"]";
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNil(result, @"");
    XCTAssertNotNil(error, @"");
}

- (void)testDeserializeArrayInvalidUnicodeSequence2
{
    NSError* error = (NSError*)self;
    NSString* jsonString = @"[\"One\\u123gTwo\"]";
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNil(result, @"");
    XCTAssertNotNil(error, @"");
}

- (void)testDeserializeArrayUnterminatedEscape
{
    NSError* error = (NSError*)self;
    NSString* jsonString = @"[\"One\\u123\"]";
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNil(result, @"");
    XCTAssertNotNil(error, @"");
}

- (void)testDeserializeArrayUnterminatedEscape2
{
    NSError* error = (NSError*)self;
    NSString* jsonString = @"[\"One\\\"]";
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNil(result, @"");
    XCTAssertNotNil(error, @"");
}

- (void)testDeserializeArrayUnterminatedEscape3
{
    NSError* error = (NSError*)self;
    NSString* jsonString = @"[\"One\\u\"]";
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNil(result, @"");
    XCTAssertNotNil(error, @"");
}

- (void)testDeserializeArrayInvalidEscape
{
    NSError* error = (NSError*)self;
    NSString* jsonString = @"[\"One\\qTwo\"]";
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNil(result, @"");
    XCTAssertNotNil(error, @"");
}

- (void)testDeserializeArrayUnterminatedString
{
    NSError* error = (NSError*)self;
    NSString* jsonString = @"[\"One]";
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNil(result, @"");
    XCTAssertNotNil(error, @"");
}

- (void)testDeserializeArrayTruncatedFalse
{
    NSError* error = (NSError*)self;
    NSString* jsonString = @"[f]";
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNil(result, @"");
    XCTAssertNotNil(error, @"");
}

- (void)testDeserializeArrayInvalidFalse
{
    NSError* error = (NSError*)self;
    NSString* jsonString = @"[falst]";
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNil(result, @"");
    XCTAssertNotNil(error, @"");
}

- (void)testDeserializeArrayTruncatedTrue
{
    NSError* error = (NSError*)self;
    NSString* jsonString = @"[t]";
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNil(result, @"");
    XCTAssertNotNil(error, @"");
}

- (void)testDeserializeArrayInvalidTrue
{
    NSError* error = (NSError*)self;
    NSString* jsonString = @"[ture]";
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNil(result, @"");
    XCTAssertNotNil(error, @"");
}

- (void)testDeserializeArrayTruncatedNull
{
    NSError* error = (NSError*)self;
    NSString* jsonString = @"[n]";
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNil(result, @"");
    XCTAssertNotNil(error, @"");
}

- (void)testDeserializeArrayInvalidNull
{
    NSError* error = (NSError*)self;
    NSString* jsonString = @"[nlll]";
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNil(result, @"");
    XCTAssertNotNil(error, @"");
}

- (void)testDeserializeArrayInvalidElement
{
    NSError* error = (NSError*)self;
    NSString* jsonString = @"[-blah]";
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNil(result, @"");
    XCTAssertNotNil(error, @"");
}

- (void)testDeserializeArrayUnterminated
{
    NSError* error = (NSError*)self;
    NSString* jsonString = @"[\"blah\"";
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNil(result, @"");
    XCTAssertNotNil(error, @"");
}

- (void)testDeserializeArrayNumberOverflow
{
    NSError* error = (NSError*)self;
    NSString* jsonString = @"[123456789012345678901234567890]";
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
}

- (void)testDeserializeDictionaryInvalidKey
{
    NSError* error = (NSError*)self;
    NSString* jsonString = @"{blah:\"blah\"}";
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNil(result, @"");
    XCTAssertNotNil(error, @"");
}

- (void)testDeserializeDictionaryMissingSeparator
{
    NSError* error = (NSError*)self;
    NSString* jsonString = @"{\"blah\"\"blah\"}";
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNil(result, @"");
    XCTAssertNotNil(error, @"");
}

- (void)testDeserializeDictionaryBadElement
{
    NSError* error = (NSError*)self;
    NSString* jsonString = @"{\"blah\":blah\"}";
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNil(result, @"");
    XCTAssertNotNil(error, @"");
}

- (void)testDeserializeDictionaryUnterminated
{
    NSError* error = (NSError*)self;
    NSString* jsonString = @"{\"blah\":\"blah\"";
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNil(result, @"");
    XCTAssertNotNil(error, @"");
}

- (void)testDeserializeInvalidData
{
    NSError* error = (NSError*)self;
    NSString* jsonString = @"X{\"blah\":\"blah\"}";
    id result = [BSG_KSJSONCodec decode:toData(jsonString) error:&error];
    XCTAssertNil(result, @"");
    XCTAssertNotNil(error, @"");
}

- (void) testDeserializeArrayWithNull
{
    NSError* error = (NSError*)self;
    NSString* json = @"[null]";
    id expected = [NSNull null];
    NSArray* result = [BSG_KSJSONCodec decode:toData(json)
                                    error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    NSString* value = result[0];
    XCTAssertEqualObjects(value, expected, @"");
}

- (void) testDeserializeArrayWithNullIgnoreNullInObject
{
    NSError* error = (NSError*)self;
    NSString* json = @"[null]";
    id expected = [NSNull null];
    NSArray* result = [BSG_KSJSONCodec decode:toData(json)
                                    error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    NSString* value = result[0];
    XCTAssertEqualObjects(value, expected, @"");
}

- (void) testDeserializeObjectWithNull
{
    NSError* error = (NSError*)self;
    NSString* json = @"{\"blah\":null}";
    id expected = [NSNull null];
    NSArray* result = [BSG_KSJSONCodec decode:toData(json)
                                    error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    NSString* value = [result valueForKey:@"blah"];
    XCTAssertEqualObjects(value, expected, @"");
}

- (void) testDeserializeObjectWithNullIgnoreNullInArray
{
    NSError* error = (NSError*)self;
    NSString* json = @"{\"blah\":null}";
    id expected = [NSNull null];
    NSArray* result = [BSG_KSJSONCodec decode:toData(json)
                                    error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    NSString* value = [result valueForKey:@"blah"];
    XCTAssertEqualObjects(value, expected, @"");
}

- (void) testFloatParsingDoesntOverflow
{
    NSError *error = (NSError*)self;

    char * buffer = malloc(0x1000000);
    for (int i = 0; i < 0x1000000; i++) {
        buffer[i] = ' ';
    }

    memcpy(buffer, "{\"test\":1.1}", 12);

    NSData *data = [NSData dataWithBytesNoCopy:buffer length:0x1000000 freeWhenDone:YES];

    NSDictionary *result = [BSG_KSJSONCodec decode: data
                                         error:&error];
    XCTAssertNotNil(result, @"");
    XCTAssertNil(error, @"");
    XCTAssertTrue([result count] == 1, @"");
    XCTAssertEqualObjects(result[@"test"], @(1.1));

}

@end
