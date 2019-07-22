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

- (void) testUntrackedClassIsValid
{
    void* classPtr = (__bridge void*)[SomeObjCClass class];
    bool isValid = bsg_ksobjc_objectType(classPtr) == BSG_KSObjCTypeClass;
    XCTAssertTrue(isValid, @"Not a class");
}

- (void) testBaseClass
{
    const void* classPtr = (__bridge void*)[SomeSubclass class];
    const void* expected = (__bridge void*)[SomeObjCClass class];
    const void* baseClass = bsg_ksobjc_baseClass(classPtr);
    XCTAssertEqual(baseClass, expected, @"");
}

@end
