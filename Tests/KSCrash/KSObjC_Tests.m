//
//  bsg_ksobjc_Tests.m
//
//  Created by Karl Stenerud on 2012-08-30.
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
#import <objc/runtime.h>

#import "BSG_KSObjC.h"


@interface SomeObjCClass: NSObject
{
    int someIvar;
    id anotherIvar;
}

@property(nonatomic,readwrite,assign) int someIvar;

@end

@implementation SomeObjCClass

@synthesize someIvar = someIvar;

@end

@interface SomeSubclass: SomeObjCClass

@end

@implementation SomeSubclass

@end

@interface bsg_ksobjc_Tests : XCTestCase @end

@implementation bsg_ksobjc_Tests

static NSArray* g_test_strings;


+ (void) initialize
{
    g_test_strings = @[
                       @"a",
                       @"ab",
                       @"abc",
                       @"abcd",
                       @"abcde",
                       @"abcdef",
                       @"abcdefg",
                       @"abcdefgh",
                       @"abcdefghi",
                       @"abcdefghij",
                       @"abcdefghijk",
                       @"abcdefghijkl",
                       @"abcdefghijklm",
                       @"abcdefghijklmn",
                       @"abcdefghijklmno",
                       @"abcdefghijklmnop",
                       ];
    bsg_ksobjc_init();
}

- (NSArray*) componentsOfBasicDescription:(NSString*) description
{
    NSError* error = nil;
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"^<(\\w+): [^>]+>" options:0 error:&error];
    NSTextCheckingResult* result = [regex firstMatchInString:description options:0 range:NSMakeRange(0, [description length])];
    NSString* className = [description substringWithRange:[result rangeAtIndex:1]];
    return @[className];
}

- (NSArray*) componentsOfComplexDescription:(NSString*) description
{
    NSError* error = nil;
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"^<(\\w+): [^>]+>: (.*)$" options:0 error:&error];
    NSTextCheckingResult* result = [regex firstMatchInString:description options:0 range:NSMakeRange(0, [description length])];
    NSString* className = [description substringWithRange:[result rangeAtIndex:1]];
    NSString* theRest = [description substringWithRange:[result rangeAtIndex:2]];
    return @[className, theRest];
}

- (void) testObjectTypeInvalidMemory
{
    uintptr_t pointer = (uintptr_t)-1;
    pointer >>= 9;
    pointer <<= 8;
    void* ptr = (void*)pointer;
    BSG_KSObjCType type = bsg_ksobjc_objectType(ptr);
    XCTAssertEqual(type, BSG_KSObjCTypeUnknown, @"Type was %d", type);
}

- (void) testObjectTypeNullPtr
{
    void* ptr = NULL;
    BSG_KSObjCType type = bsg_ksobjc_objectType(ptr);
    XCTAssertEqual(type, BSG_KSObjCTypeUnknown, @"Type was %d", type);
}

- (void) testObjectTypeCorrupt
{
    struct objc_object objcClass;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    objcClass.isa = (__bridge Class)((void*)-1);
#pragma clang diagnostic pop
    BSG_KSObjCType type = bsg_ksobjc_objectType(&objcClass);
    XCTAssertEqual(type, BSG_KSObjCTypeUnknown, @"Type was %d", type);
}

- (void) testObjectTypeClass
{
    Class cls = [bsg_ksobjc_Tests class];
    void* clsPtr = (__bridge void*)cls;
    BSG_KSObjCType type = bsg_ksobjc_objectType(clsPtr);
    XCTAssertTrue(type == BSG_KSObjCTypeClass, @"Type was %d", type);
}

- (void) testObjectTypeObject
{
    id object = [bsg_ksobjc_Tests new];
    BSG_KSObjCType type = bsg_ksobjc_objectType((__bridge void *)(object));
    XCTAssertTrue(type == BSG_KSObjCTypeObject, @"");
}

- (void) testObjectTypeObject2
{
    id object = @"Test";
    BSG_KSObjCType type = bsg_ksobjc_objectType((__bridge void *)(object));
    XCTAssertTrue(type == BSG_KSObjCTypeObject, @"");
}

- (void) testObjectTypeBlock
{
    dispatch_block_t block;
    const void* blockPtr;
    const void* isaPtr;
    BSG_KSObjCType type;
    
    block = ^{};
    blockPtr = (__bridge void*)block;
    isaPtr = bsg_ksobjc_isaPointer(blockPtr);
    type = bsg_ksobjc_objectType(isaPtr);
    XCTAssertTrue(type == BSG_KSObjCTypeBlock, @"");
    
    block = [^{} copy];
    blockPtr = (__bridge void*)block;
    isaPtr = bsg_ksobjc_isaPointer(blockPtr);
    type = bsg_ksobjc_objectType(isaPtr);
    XCTAssertTrue(type == BSG_KSObjCTypeBlock, @"");
    
    block = ^{NSLog(@"%d", type);};
    blockPtr = (__bridge void*)block;
    isaPtr = bsg_ksobjc_isaPointer(blockPtr);
    type = bsg_ksobjc_objectType(isaPtr);
    XCTAssertTrue(type == BSG_KSObjCTypeBlock, @"");
    
    block = [^{NSLog(@"%d", type);} copy];
    blockPtr = (__bridge void*)block;
    isaPtr = bsg_ksobjc_isaPointer(blockPtr);
    type = bsg_ksobjc_objectType(isaPtr);
    XCTAssertTrue(type == BSG_KSObjCTypeBlock, @"");
    
    __block int value = 0;
    
    block = ^{value = 1;};
    blockPtr = (__bridge void*)block;
    isaPtr = bsg_ksobjc_isaPointer(blockPtr);
    type = bsg_ksobjc_objectType(isaPtr);
    XCTAssertTrue(type == BSG_KSObjCTypeBlock, @"");
    
    block = [^{value = 1;} copy];
    blockPtr = (__bridge void*)block;
    isaPtr = bsg_ksobjc_isaPointer(blockPtr);
    type = bsg_ksobjc_objectType(isaPtr);
    XCTAssertTrue(type == BSG_KSObjCTypeBlock, @"");
}

- (void) testGetClassName
{
    Class cls = [NSString class];
    const char* expected = "NSString";
    const char* actual = bsg_ksobjc_className((__bridge void *)(cls));
    XCTAssertTrue(actual != NULL, @"result was NULL");
    if(actual != NULL)
    {
        bool equal = strncmp(expected, actual, strlen(expected)+1) == 0;
        XCTAssertTrue(equal, @"expected %s but got %s", expected, actual);
    }
}

- (void) testGetObjectClassName
{
    NSObject* obj = [NSObject new];
    void* objPtr = (__bridge void*)obj;
    BSG_KSObjCType type = bsg_ksobjc_objectType(objPtr);
    XCTAssertEqual(type, BSG_KSObjCTypeObject, @"");

    const char* expected = "NSObject";
    const void* classPtr = bsg_ksobjc_isaPointer(objPtr);
    const char* actual = bsg_ksobjc_className(classPtr);
    XCTAssertTrue(actual != NULL, @"result was NULL");
    if(actual != NULL)
    {
        bool equal = strncmp(expected, actual, strlen(expected)+1) == 0;
        XCTAssertTrue(equal, @"expected %s but got %s", expected, actual);
    }
}

- (void) testStringIsValid
{
    NSString* string = @"test";
    void* stringPtr = (__bridge void*)string;
    bool valid = bsg_ksobjc_isValidObject(stringPtr);
    XCTAssertTrue(valid, @"");
}

- (void) testStringIsValid2
{
    NSString* string = [NSString stringWithFormat:@"%d", 1];
    void* stringPtr = (__bridge void*)string;
    bool valid = bsg_ksobjc_isValidObject(stringPtr);
    XCTAssertTrue(valid, @"");
}

- (void) testStringIsValid3
{
    NSMutableString* string = [NSMutableString stringWithFormat:@"%d", 1];
    void* stringPtr = (__bridge void*)string;
    bool valid = bsg_ksobjc_isValidObject(stringPtr);
    XCTAssertTrue(valid, @"");
}

- (void) testCFStringIsValid
{
    char* expected = "test";
    size_t expectedLength = strlen(expected);
    CFStringRef stringPtr = CFStringCreateWithBytes(NULL, (uint8_t*)expected, (CFIndex)expectedLength, kCFStringEncodingUTF8, FALSE);
    bool valid = bsg_ksobjc_isValidObject(stringPtr);
    XCTAssertTrue(valid, @"");
    CFRelease(stringPtr);
}

- (void) testStringLength
{
    NSString* string = @"test";
    void* stringPtr = (__bridge void*)string;
    size_t expectedLength = [string length];
    size_t length = bsg_ksobjc_stringLength(stringPtr);
    XCTAssertEqual(length, expectedLength, @"");
}

- (void) testStringLength2
{
    NSString* string = [NSString stringWithFormat:@"%d", 1];
    void* stringPtr = (__bridge void*)string;
    size_t expectedLength = [string length];
    size_t length = bsg_ksobjc_stringLength(stringPtr);
    XCTAssertEqual(length, expectedLength, @"");
}

- (void) testStringLength3
{
    NSMutableString* string = [NSMutableString stringWithFormat:@"%d", 1];
    void* stringPtr = (__bridge void*)string;
    size_t expectedLength = [string length];
    size_t length = bsg_ksobjc_stringLength(stringPtr);
    XCTAssertEqual(length, expectedLength, @"");
}

- (void) testCFStringLength
{
    char* expected = "test";
    size_t expectedLength = strlen(expected);
    CFStringRef stringPtr = CFStringCreateWithBytes(NULL, (uint8_t*)expected, (CFIndex)expectedLength, kCFStringEncodingUTF8, FALSE);
    size_t length = bsg_ksobjc_stringLength(stringPtr);
    XCTAssertEqual(length, expectedLength, @"");
}

- (void) testCopyStringContents
{
    NSString* string = @"test";
    const char* expected = [string UTF8String];
    size_t expectedLength = [string length];
    char actual[100];
    size_t copied = bsg_ksobjc_copyStringContents((__bridge void*)string, actual, sizeof(actual));
    XCTAssertEqual(copied, expectedLength, @"");
    int result = strcmp(actual, expected);
    XCTAssertTrue(result == 0, @"String %s did not equal %s", actual, expected);
}

- (void) testCopyStringContents2
{
    NSString* string = [NSString stringWithFormat:@"%d", 1];
    const char* expected = [string UTF8String];
    size_t expectedLength = [string length];
    char actual[100];
    size_t copied = bsg_ksobjc_copyStringContents((__bridge void*)string, actual, sizeof(actual));
    XCTAssertEqual(copied, expectedLength, @"");
    int result = strcmp(actual, expected);
    XCTAssertTrue(result == 0, @"String %s did not equal %s", actual, expected);
}

- (void) testCopyStringContents3
{
    NSMutableString* string = [NSMutableString stringWithFormat:@"%d", 1];
    const char* expected = [string UTF8String];
    size_t expectedLength = [string length];
    char actual[100];
    size_t copied = bsg_ksobjc_copyStringContents((__bridge void*)string, actual, sizeof(actual));
    XCTAssertEqual(copied, expectedLength, @"");
    int result = strcmp(actual, expected);
    XCTAssertTrue(result == 0, @"String %s did not equal %s", actual, expected);
}

- (void) testCopyStringContentsEmpty
{
    NSString* string = @"";
    const char* expected = [string UTF8String];
    size_t expectedLength = [string length];
    char actual[100];
    size_t copied = bsg_ksobjc_copyStringContents((__bridge void*)string, actual, sizeof(actual));
    XCTAssertEqual(copied, expectedLength, @"");
    int result = strcmp(actual, expected);
    XCTAssertTrue(result == 0, @"String %s did not equal %s", actual, expected);
}

- (void) testCopyStringContentsTruncate
{
    NSString* string = @"A longish string";
    const char* expected = "A lo";
    size_t expectedLength = 4;
    char actual[5];
    size_t copied = bsg_ksobjc_copyStringContents((__bridge void*)string, actual, sizeof(actual));
    XCTAssertEqual(copied, expectedLength, @"");
    int result = strcmp(actual, expected);
    XCTAssertTrue(result == 0, @"String %s did not equal %s", actual, expected);
}

- (void) testCopyStringContents0Length
{
    NSString* string = @"A longish string";
    const char expected = 0x7f;
    size_t expectedLength = 0;
    char actual = expected;
    size_t copied = bsg_ksobjc_copyStringContents((__bridge void*)string, &actual, 0);
    XCTAssertEqual(copied, expectedLength, @"");
    XCTAssertEqual(actual, expected, @"");
}

- (void) testCopyStringContentsUTF16
{
    NSString* string = @"123 テスト 123";
    const char* expected = [string UTF8String];
    size_t expectedLength = strlen(expected);
    char actual[100];
    size_t copied = bsg_ksobjc_copyStringContents((__bridge void*)string, actual, sizeof(actual));
    XCTAssertEqual(copied, expectedLength, @"");
    int result = strcmp(actual, expected);
    XCTAssertTrue(result == 0, @"String %s did not equal %s", actual, expected);
}

- (void) testCopyStringContentsUTF16_2Byte
{
    NSString* string = @"Ÿ";
    const char* expected = [string UTF8String];
    size_t expectedLength = strlen(expected);
    char actual[100];
    size_t copied = bsg_ksobjc_copyStringContents((__bridge void*)string, actual, sizeof(actual));
    XCTAssertEqual(copied, expectedLength, @"");
    int result = strcmp(actual, expected);
    XCTAssertTrue(result == 0, @"String %s did not equal %s", actual, expected);
}

- (void) testCopyStringContentsUTF16_3Byte
{
    NSString* string = @"ঠ";
    const char* expected = [string UTF8String];
    size_t expectedLength = strlen(expected);
    char actual[100];
    size_t copied = bsg_ksobjc_copyStringContents((__bridge void*)string, actual, sizeof(actual));
    XCTAssertEqual(copied, expectedLength, @"");
    int result = strcmp(actual, expected);
    XCTAssertTrue(result == 0, @"String %s did not equal %s", actual, expected);
}

- (void) testCopyStringContentsUTF16_4Byte
{
    NSString* string = @"𐅐";
    const char* expected = [string UTF8String];
    size_t expectedLength = strlen(expected);
    char actual[100];
    size_t copied = bsg_ksobjc_copyStringContents((__bridge void*)string, actual, sizeof(actual));
    XCTAssertEqual(copied, expectedLength, @"");
    int result = strcmp(actual, expected);
    XCTAssertTrue(result == 0, @"String %s did not equal %s", actual, expected);
}

- (void) testCopyStringContentsMutable
{
    NSMutableString* string = [NSMutableString stringWithFormat:@"%@", @"test"];
    const char* expected = [string UTF8String];
    size_t expectedLength = [string length];
    char actual[100];
    size_t copied = bsg_ksobjc_copyStringContents((__bridge void*)string, actual, sizeof(actual));
    XCTAssertEqual(copied, expectedLength, @"");
    int result = strcmp(actual, expected);
    XCTAssertTrue(result == 0, @"String %s did not equal %s", actual, expected);
}

- (void) testCopyStringContentsMutableLong
{
    NSMutableString* string = [NSMutableString string];
    for(int i = 0; i < 1000; i++)
    {
        [string appendString:@"1"];
    }
    const char* expected = [string UTF8String];
    size_t expectedLength = [string length];
    char actual[2000];
    size_t copied = bsg_ksobjc_copyStringContents((__bridge void*)string, actual, sizeof(actual));
    XCTAssertEqual(copied, expectedLength, @"");
    int result = strcmp(actual, expected);
    XCTAssertTrue(result == 0, @"String %s did not equal %s", actual, expected);
}

- (void) testCopyStringContentsCFString
{
    for(NSUInteger i = 0; i < g_test_strings.count; i++)
    {
        const char* expected = [g_test_strings[i] UTF8String];
        size_t expectedLength = strlen(expected);
        CFStringRef string = CFStringCreateWithBytes(NULL, (uint8_t*)expected, (CFIndex)expectedLength, kCFStringEncodingUTF8, FALSE);
        char actual[100];
        size_t copied = bsg_ksobjc_copyStringContents(string, actual, sizeof(actual));
        XCTAssertEqual(copied, expectedLength, @"");
        int result = strcmp(actual, expected);
        XCTAssertTrue(result == 0, @"String %s did not equal %s", actual, expected);
        CFRelease(string);
    }
}

- (void) testStringDescription
{
    for(NSUInteger i = 0; i < g_test_strings.count; i++)
    {
        NSString* string = g_test_strings[i];
        void* stringPtr = (__bridge void*)string;
        NSString* expectedClassName = [NSString stringWithCString:class_getName([string class]) encoding:NSUTF8StringEncoding];
        NSString* expectedTheRest = [NSString stringWithFormat:@"\"%@\"", string];
        char buffer[100];
        size_t copied = bsg_ksobjc_getDescription(stringPtr, buffer, sizeof(buffer));
        XCTAssertTrue(copied > 0, @"");
        NSString* description = [NSString stringWithCString:buffer encoding:NSUTF8StringEncoding];
        NSArray* components = [self componentsOfComplexDescription:description];
        NSString* className = components[0];
        NSString* theRest = components[1];
        XCTAssertEqualObjects(className, expectedClassName, @"");
        XCTAssertEqualObjects(theRest, expectedTheRest, @"");
    }
}

- (void) testURLIsValid
{
    NSURL* URL =  [NSURL URLWithString:@"http://www.google.com"];
    void* URLPtr = (__bridge void*)URL;
    bool valid = bsg_ksobjc_isValidObject(URLPtr);
    XCTAssertTrue(valid, @"");
}

- (void) testCopyURLContents
{
    NSURL* URL =  [NSURL URLWithString:@"http://www.google.com"];
    NSString* string = [URL absoluteString];
    const char* expected = [string UTF8String];
    size_t expectedLength = [string length];
    char actual[100];
    size_t copied = bsg_ksobjc_copyURLContents((__bridge void*)URL, actual, sizeof(actual));
    XCTAssertEqual(copied, expectedLength, @"");
    int result = strcmp(actual, expected);
    XCTAssertTrue(result == 0, @"String %s did not equal %s", actual, expected);
}

- (void) testURLDescription
{
    NSURL* URL =  [NSURL URLWithString:@"http://www.google.com"];
    void* URLPtr = (__bridge void*)URL;
    NSString* expectedClassName = [NSString stringWithCString:class_getName([URL class]) encoding:NSUTF8StringEncoding];
    NSString* expectedTheRest = @"\"http://www.google.com\"";
    char buffer[100];
    size_t copied = bsg_ksobjc_getDescription(URLPtr, buffer, sizeof(buffer));
    XCTAssertTrue(copied > 0, @"");
    NSString* description = [NSString stringWithCString:buffer encoding:NSUTF8StringEncoding];
    NSArray* components = [self componentsOfComplexDescription:description];
    NSString* className = components[0];
    NSString* theRest = components[1];
    XCTAssertEqualObjects(className, expectedClassName, @"");
    XCTAssertEqualObjects(theRest, expectedTheRest, @"");
}

- (void) testDateIsValid
{
    NSDate* date = [NSDate dateWithTimeIntervalSinceReferenceDate:10.0];
    void* datePtr = (__bridge void*)date;
    bool valid = bsg_ksobjc_isValidObject(datePtr);
    XCTAssertTrue(valid, @"");
}

- (void) testGetDateContents
{
    NSDate* date = [NSDate dateWithTimeIntervalSinceReferenceDate:10.0];
    void* datePtr = (__bridge void*)date;
    NSTimeInterval expected = [date timeIntervalSinceReferenceDate];
    NSTimeInterval actual = bsg_ksobjc_dateContents(datePtr);
    XCTAssertEqual(actual, expected, @"");
}

- (void) testDateDescription
{
    NSDate* date = [NSDate dateWithTimeIntervalSinceReferenceDate:10.0];
    void* datePtr = (__bridge void*)date;
    NSString* expectedClassName = @"NSDate";
    NSString* expectedTheRest = @"10.000000";
    char buffer[100];
    size_t copied = bsg_ksobjc_getDescription(datePtr, buffer, sizeof(buffer));
    XCTAssertTrue(copied > 0, @"");
    NSString* description = [NSString stringWithCString:buffer encoding:NSUTF8StringEncoding];
    NSArray* components = [self componentsOfComplexDescription:description];
    NSString* className = components[0];
    NSString* theRest = components[1];
    XCTAssert([className hasSuffix:expectedClassName]);
    XCTAssertEqualObjects(theRest, expectedTheRest, @"");
}

- (void) testNumberIsValid
{
    NSNumber* number = @10;
    void* numberPtr = (__bridge void*)number;
    bool valid = bsg_ksobjc_isValidObject(numberPtr);
    XCTAssertTrue(valid, @"");
}

- (void) testNumberIsFloat
{
    NSNumber* number = @0.1;
    void* numberPtr = (__bridge void*)number;
    bool isFloat = bsg_ksobjc_numberIsFloat(numberPtr);
    XCTAssertTrue(isFloat, "");
}

- (void) testNumberIsFloat2
{
    NSNumber* number = @1.0;
    void* numberPtr = (__bridge void*)number;
    bool isFloat = bsg_ksobjc_numberIsFloat(numberPtr);
    XCTAssertTrue(isFloat, "");
}

- (void) testNumberIsInt
{
    NSNumber* number = @1;
    void* numberPtr = (__bridge void*)number;
    bool isFloat = bsg_ksobjc_numberIsFloat(numberPtr);
    XCTAssertFalse(isFloat, "");
}

- (void) testFloatNumber
{
    Float64 expected = 0.1;
    NSNumber* number = @(expected);
    void* numberPtr = (__bridge void*)number;
    Float64 actual = bsg_ksobjc_numberAsFloat(numberPtr);
    XCTAssertEqual(expected, actual, "");
}

- (void) testFloatNumberWhole
{
    Float64 expected = 1.0;
    NSNumber* number = @(expected);
    void* numberPtr = (__bridge void*)number;
    Float64 actual = bsg_ksobjc_numberAsFloat(numberPtr);
    XCTAssertEqual(expected, actual, "");
}

- (void) testFloatNumberFromInt
{
    Float64 expected = 1.0;
    NSNumber* number = @((int) expected);
    void* numberPtr = (__bridge void*)number;
    Float64 actual = bsg_ksobjc_numberAsFloat(numberPtr);
    XCTAssertEqual(expected, actual, "");
}

- (void) testIntNumber
{
    int64_t expected = 55;
    NSNumber* number = @(expected);
    void* numberPtr = (__bridge void*)number;
    int64_t actual = bsg_ksobjc_numberAsInteger(numberPtr);
    XCTAssertEqual(expected, actual, "");
}

- (void) testLargeIntNumber
{
    int64_t expected = 0x7fffffffffffffff;
    NSNumber* number = @(expected);
    void* numberPtr = (__bridge void*)number;
    int64_t actual = bsg_ksobjc_numberAsInteger(numberPtr);
    XCTAssertEqual(expected, actual, "");
}

- (void) testIntNumberFromFloat
{
    int64_t expected = 55;
    NSNumber* number = @(expected);
    void* numberPtr = (__bridge void*)number;
    int64_t actual = bsg_ksobjc_numberAsInteger(numberPtr);
    XCTAssertEqual(expected, actual, "");
}

- (void) testIntNumberFromFloatTruncated
{
    int64_t expected = 55;
    NSNumber* number = @55.8;
    void* numberPtr = (__bridge void*)number;
    int64_t actual = bsg_ksobjc_numberAsInteger(numberPtr);
    XCTAssertEqual(expected, actual, "");
}

- (void) testArrayIsValid
{
    NSArray* array = [NSArray array];
    void* arrayPtr = (__bridge void*)array;
    bool valid = bsg_ksobjc_isValidObject(arrayPtr);
    XCTAssertTrue(valid, @"");
}

- (void) testMutableArrayIsValid
{
    NSMutableArray* array = [NSMutableArray array];
    void* arrayPtr = (__bridge void*)array;
    bool valid = bsg_ksobjc_isValidObject(arrayPtr);
    XCTAssertTrue(valid, @"");
}

- (void) testCFArrayIsValid
{
    const void* values[4] =
    {
        @"1",
        @"2",
        @"3",
        @"4",
    };
    CFArrayRef arrayPtr = CFArrayCreate(NULL, values, 4, NULL);
    bool valid = bsg_ksobjc_isValidObject(arrayPtr);
    XCTAssertTrue(valid, @"");
    CFRelease(arrayPtr);
}

- (void) testEmptyCFMutableArrayIsValid
{
    CFMutableArrayRef arrayPtr = CFArrayCreateMutable(NULL, 4, NULL);
    bool valid = bsg_ksobjc_isValidObject(arrayPtr);
    XCTAssertTrue(valid, @"");
    CFRelease(arrayPtr);
}

- (void) testCFMutableArrayIsValid
{
    CFMutableArrayRef arrayPtr = CFArrayCreateMutable(NULL, 4, NULL);
    id value = @"blah";
    CFArrayAppendValue(arrayPtr, (__bridge void*)value);
    bool valid = bsg_ksobjc_isValidObject(arrayPtr);
    XCTAssertTrue(valid, @"");
    CFRelease(arrayPtr);
}

- (void) testCopyArrayContentsEmpty
{
    NSArray* array = [NSArray array];
    void* arrayPtr = (__bridge void*)array;
    size_t expectedCount = [array count];
    size_t count = bsg_ksobjc_arrayCount(arrayPtr);
    XCTAssertEqual(count, expectedCount, @"");
}

- (void) testArrayCountEmpty
{
    NSArray* array = [NSArray array];
    void* arrayPtr = (__bridge void*)array;
    size_t count = bsg_ksobjc_arrayCount(arrayPtr);
    XCTAssertEqual(count, 0ul, @"");
}

- (void) testArrayDescriptionEmpty
{
    NSArray* array = [NSArray array];
    void* arrayPtr = (__bridge void*)array;
    NSString* expectedClassName = [NSString stringWithCString:class_getName([array class]) encoding:NSUTF8StringEncoding];
    NSString* expectedTheRest = @"[]";
    char buffer[100];
    size_t copied = bsg_ksobjc_getDescription(arrayPtr, buffer, sizeof(buffer));
    XCTAssertTrue(copied > 0, @"");
    NSString* description = [NSString stringWithCString:buffer encoding:NSUTF8StringEncoding];
    NSArray* components = [self componentsOfComplexDescription:description];
    NSString* className = components[0];
    NSString* theRest = components[1];
    XCTAssertEqualObjects(className, expectedClassName, @"");
    XCTAssertEqualObjects(theRest, expectedTheRest, @"");
}

- (void) testArrayDescription
{
    NSArray* array = @[@"test"];
    void* arrayPtr = (__bridge void*)array;
    NSString* expectedClassName = [NSString stringWithCString:class_getName([array class]) encoding:NSUTF8StringEncoding];
    char buffer[100];
    size_t copied = bsg_ksobjc_getDescription(arrayPtr, buffer, sizeof(buffer));
    XCTAssertTrue(copied > 0, @"");
    NSString* description = [NSString stringWithCString:buffer encoding:NSUTF8StringEncoding];
    XCTAssertTrue([description containsString:expectedClassName]);
}

- (void) testCopyArrayContentsImmutable
{
    NSArray* array = @[@"1", @"2", @"3", @"4"];
    void* arrayPtr = (__bridge void*)array;
    size_t expectedCount = [array count];
    size_t count = bsg_ksobjc_arrayCount(arrayPtr);
    XCTAssertEqual(count, expectedCount, @"");
    uintptr_t contents[10];
    size_t copied = bsg_ksobjc_arrayContents(arrayPtr, contents, sizeof(contents));
    XCTAssertEqual(copied, count, @"");
    for(size_t i = 0; i < count; i++)
    {
        bool isValid = bsg_ksobjc_objectType((void*)contents[i]) == BSG_KSObjCTypeObject;
        XCTAssertTrue(isValid, @"Object %zu is not an object", i);
        isValid = bsg_ksobjc_isValidObject((void*)contents[i]);
        XCTAssertTrue(isValid, @"Object %zu is invalid", i);
    }
}

- (void) testCopyArrayContentsImmutableEmpty
{
    NSArray* array = [NSArray array];
    void* arrayPtr = (__bridge void*)array;
    size_t expectedCount = [array count];
    size_t count = bsg_ksobjc_arrayCount(arrayPtr);
    XCTAssertEqual(count, expectedCount, @"");
    uintptr_t contents[10];
    size_t copied = bsg_ksobjc_arrayContents(arrayPtr, contents, sizeof(contents));
    XCTAssertEqual(copied, expectedCount, @"");
}

- (void) testCopyArrayContentsMutable
{
    NSMutableArray* array = [@[@"1", @"2", @"3", @"4"] mutableCopy];
    void* arrayPtr = (__bridge void*)array;
    size_t expectedCount = [array count];
    size_t count = bsg_ksobjc_arrayCount(arrayPtr);
    XCTAssertEqual(count, expectedCount, @"");
    uintptr_t contents[10];
    size_t copied = bsg_ksobjc_arrayContents(arrayPtr, contents, sizeof(contents));
    size_t expectedCopied = 0;
    XCTAssertEqual(copied, expectedCopied, @"");
}

- (void) testCopyArrayContentsMutableEmpty
{
    NSMutableArray* array = [NSMutableArray array];
    void* arrayPtr = (__bridge void*)array;
    size_t expectedCount = [array count];
    size_t count = bsg_ksobjc_arrayCount(arrayPtr);
    XCTAssertEqual(count, expectedCount, @"");
    uintptr_t contents[10];
    size_t copied = bsg_ksobjc_arrayContents(arrayPtr, contents, sizeof(contents));
    XCTAssertEqual(copied, expectedCount, @"");
}

- (void) testCopyArrayContentsCFArray
{
    const void* values[4] =
    {
        @"1",
        @"2",
        @"3",
        @"4",
    };
    CFArrayRef arrayPtr = CFArrayCreate(NULL, values, 4, NULL);
    NSArray* array = (__bridge NSArray*)arrayPtr;
    size_t expectedCount = [array count];
    size_t count = bsg_ksobjc_arrayCount(arrayPtr);
    XCTAssertEqual(count, expectedCount, @"");
    uintptr_t contents[10];
    size_t copied = bsg_ksobjc_arrayContents(arrayPtr, contents, sizeof(contents));
    XCTAssertEqual(copied, count, @"");
    for(size_t i = 0; i < count; i++)
    {
        bool isValid = bsg_ksobjc_objectType((void*)contents[i]) == BSG_KSObjCTypeObject;
        XCTAssertTrue(isValid, @"Object %zu is not an object", i);
        isValid = bsg_ksobjc_isValidObject((void*)contents[i]);
        XCTAssertTrue(isValid, @"Object %zu is invalid", i);
    }
    CFRelease(arrayPtr);
}

- (void) testCopyArrayContentsCFArrayEmpty
{
    CFArrayRef arrayPtr = CFArrayCreate(NULL, NULL, 0, NULL);
    NSArray* array = (__bridge NSArray*)arrayPtr;
    size_t expectedCount = [array count];
    size_t count = bsg_ksobjc_arrayCount(arrayPtr);
    XCTAssertEqual(count, expectedCount, @"");
    uintptr_t contents[10];
    size_t copied = bsg_ksobjc_arrayContents(arrayPtr, contents, sizeof(contents));
    XCTAssertEqual(copied, expectedCount, @"");
    CFRelease(arrayPtr);
}

- (void) testUntrackedClassIsValid
{
    void* classPtr = (__bridge void*)[SomeObjCClass class];
    bool isValid = bsg_ksobjc_objectType(classPtr) == BSG_KSObjCTypeClass;
    XCTAssertTrue(isValid, @"Not a class");
}

- (void) testUntrackedClassDescription
{
    SomeObjCClass* instance = [[SomeObjCClass alloc] init];
    void* instancePtr = (__bridge void*)instance;
    NSString* expectedClassName = [NSString stringWithCString:class_getName([instance class]) encoding:NSUTF8StringEncoding];
    char buffer[100];
    size_t copied = bsg_ksobjc_getDescription(instancePtr, buffer, sizeof(buffer));
    XCTAssertTrue(copied > 0, @"");
    NSString* description = [NSString stringWithCString:buffer encoding:NSUTF8StringEncoding];
    NSArray* components = [self componentsOfBasicDescription:description];
    NSString* className = components[0];
    XCTAssertEqualObjects(className, expectedClassName, @"");
}

- (void) testSuperclass
{
    void* classPtr = (__bridge void*)[SomeObjCClass class];
    const void* expected = (__bridge void*)[NSObject class];
    const void* superclass = bsg_ksobjc_superClass(classPtr);
    XCTAssertEqual(superclass, expected, @"");
}

- (void) testNSObjectIsRootClass
{
    void* classPtr = (__bridge void*)[NSObject class];
    bool isRootClass = bsg_ksobjc_isRootClass(classPtr);
    XCTAssertTrue(isRootClass, @"");
}

- (void) testNotRootClass
{
    void* classPtr = (__bridge void*)[SomeObjCClass class];
    bool isRootClass = bsg_ksobjc_isRootClass(classPtr);
    XCTAssertFalse(isRootClass, @"");
}

- (void) testIsClassNamed
{
    void* classPtr = (__bridge void*)[SomeObjCClass class];
    bool isClassNamed = bsg_ksobjc_isClassNamed(classPtr, "SomeObjCClass");
    XCTAssertTrue(isClassNamed, @"");
    isClassNamed = bsg_ksobjc_isClassNamed(classPtr, "NSObject");
    XCTAssertFalse(isClassNamed, @"");
    isClassNamed = bsg_ksobjc_isClassNamed(classPtr, NULL);
    XCTAssertFalse(isClassNamed, @"");
}

- (void) testIsKindOfClass
{
    void* classPtr = (__bridge void*)[SomeObjCClass class];
    bool isKindOfClass = bsg_ksobjc_isKindOfClass(classPtr, "NSObject");
    XCTAssertTrue(isKindOfClass, @"");
    isKindOfClass = bsg_ksobjc_isKindOfClass(classPtr, "NSDate");
    XCTAssertFalse(isKindOfClass, @"");
    isKindOfClass = bsg_ksobjc_isKindOfClass(classPtr, NULL);
    XCTAssertFalse(isKindOfClass, @"");
}

- (void) testBaseClass
{
    const void* classPtr = (__bridge void*)[SomeSubclass class];
    const void* expected = (__bridge void*)[SomeObjCClass class];
    const void* baseClass = bsg_ksobjc_baseClass(classPtr);
    XCTAssertEqual(baseClass, expected, @"");
}

- (void) testIvarCount
{
    void* classPtr = (__bridge void*)[SomeObjCClass class];
    size_t ivarCount = bsg_ksobjc_ivarCount(classPtr);
    XCTAssertEqual(ivarCount, 2ul, @"");
}

- (void) testIvarList
{
    void* classPtr = (__bridge void*)[SomeObjCClass class];
    BSG_KSObjCIvar ivars[10];
    size_t ivarCount = bsg_ksobjc_ivarList(classPtr, ivars, sizeof(ivars)/sizeof(*ivars));
    const char* expectedIvar1Name = "someIvar";
    const char* expectedIvar1Type = "i";
    const char* expectedIvar2Name = "anotherIvar";
    const char* expectedIvar2Type = "@";
    
    int compare;
    
    XCTAssertEqual(ivarCount, 2ul, @"");
    compare = strcmp(ivars[0].name, expectedIvar1Name);
    XCTAssertEqual(compare, 0, @"");
    compare = strcmp(ivars[0].type, expectedIvar1Type);
    XCTAssertEqual(compare, 0, @"");
    compare = strcmp(ivars[1].name, expectedIvar2Name);
    XCTAssertEqual(compare, 0, @"");
    compare = strcmp(ivars[1].type, expectedIvar2Type);
    XCTAssertEqual(compare, 0, @"");
}

- (void) testIvarListTruncated
{
    void* classPtr = (__bridge void*)[SomeObjCClass class];
    BSG_KSObjCIvar ivars[1];
    size_t ivarCount = bsg_ksobjc_ivarList(classPtr, ivars, sizeof(ivars)/sizeof(*ivars));
    const char* expectedIvar1Name = "someIvar";
    const char* expectedIvar1Type = "i";
    
    int compare;
    
    XCTAssertEqual(ivarCount, 1ul, @"");
    compare = strcmp(ivars[0].name, expectedIvar1Name);
    XCTAssertEqual(compare, 0, @"");
    compare = strcmp(ivars[0].type, expectedIvar1Type);
    XCTAssertEqual(compare, 0, @"");
}

- (void) testIvarListNull
{
    void* classPtr = (__bridge void*)[SomeObjCClass class];
    size_t ivarCount = bsg_ksobjc_ivarList(classPtr, NULL, 10);
    XCTAssertEqual(ivarCount, 0ul, @"");
}

- (void) testIvarNamed
{
    void* classPtr = (__bridge void*)[SomeObjCClass class];
    BSG_KSObjCIvar ivar;
    bool found = bsg_ksobjc_ivarNamed(classPtr, "someIvar", &ivar);
    XCTAssertTrue(found, @"");
    const char* expectedIvarName = "someIvar";
    const char* expectedIvarType = "i";
    int compare = strcmp(ivar.name, expectedIvarName);
    XCTAssertEqual(compare, 0, @"");
    compare = strcmp(ivar.type, expectedIvarType);
    XCTAssertEqual(compare, 0, @"");
}

- (void) testIvarNamedNotFound
{
    void* classPtr = (__bridge void*)[SomeObjCClass class];
    BSG_KSObjCIvar ivar;
    bool found = bsg_ksobjc_ivarNamed(classPtr, "blahblahh", &ivar);
    XCTAssertFalse(found, @"");

    found = bsg_ksobjc_ivarNamed(classPtr, NULL, &ivar);
    XCTAssertFalse(found, @"");
}

- (void) testIvarValue
{
    int expectedValue = 100;
    SomeObjCClass* object = [[SomeObjCClass alloc] init];
    object.someIvar = expectedValue;
    void* objectPtr = (__bridge void*)object;
    int value = 0;
    bool success = bsg_ksobjc_ivarValue(objectPtr, 0, &value);
    XCTAssertTrue(success, @"");
    XCTAssertEqual(value, expectedValue, @"");
}

- (void) testIvarValueOutOfRange
{
    SomeObjCClass* object = [[SomeObjCClass alloc] init];
    void* objectPtr = (__bridge void*)object;
    int value = 0;
    bool success = bsg_ksobjc_ivarValue(objectPtr, 100, &value);
    XCTAssertFalse(success, @"");
}

- (void) testUnknownObjectIsValid
{
    SomeObjCClass* object = [[SomeObjCClass alloc] init];
    void* objectPtr = (__bridge void*)object;
    bool success = bsg_ksobjc_isValidObject(objectPtr);
    XCTAssertTrue(success, @"");
}

//- (void) testCopyDictionaryContents
//{
//    NSDictionary* dict = [NSDictionary dictionaryWithObject:@"value" forKey:@"key"];
//    void* dictPtr = (__bridge void*)dict;
//    size_t expectedCount = [dict count];
//    size_t count = bsg_ksobjc_dictionaryCount(dictPtr);
//    XCTAssertEqual(count, expectedCount, @"");
//    uintptr_t key;
//    uintptr_t value;
//    bool copied = bsg_ksobjc_dictionaryFirstEntry(dictPtr, &key, &value);
//    XCTAssertTrue(copied, @"");
//    bool isValid = bsg_ksobjc_objectType((void*)key) == BSG_KSObjCTypeObject;
//    XCTAssertTrue(isValid, @"");
//    isValid = bsg_ksobjc_isValidObject((void*)key);
//    XCTAssertTrue(isValid, @"");
//    isValid = bsg_ksobjc_objectType((void*)value) == BSG_KSObjCTypeObject;
//    XCTAssertTrue(isValid, @"");
//    isValid = bsg_ksobjc_isValidObject((void*)value);
//    XCTAssertTrue(isValid, @"");
//}

@end
