//
//  BugsnagStacktraceTest.m
//  Tests
//
//  Created by Jamie Lynch on 06/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "BugsnagStacktrace.h"

@interface BugsnagStacktraceTest : XCTestCase
@property NSDictionary *frameDict;
@property NSArray *binaryImages;
@end

@interface BugsnagStacktrace ()
@property NSMutableArray<BugsnagStackframe *> *trace;
@end

@implementation BugsnagStacktraceTest

- (void)setUp {
    self.frameDict = @{
            @"symbol_addr": @0x10b574fa0,
            @"instruction_addr": @0x10b5756bf,
            @"object_addr": @0x10b54b000,
            @"object_name": @"/Users/foo/Bugsnag.h",
            @"symbol_name": @"-[BugsnagClient notify:handledState:block:]",
    };
    self.binaryImages = @[@{
            @"image_addr": @0x10b54b000,
            @"image_vmaddr": @0x102340922,
            @"uuid": @"B6D80CB5-A772-3D2F-B5A1-A3A137B8B58F",
            @"name": @"/Users/foo/Bugsnag.h",
    }];
}

- (void)testBasicFrame {
    NSArray *trace = @[self.frameDict];

    BugsnagStacktrace *stacktrace = [[BugsnagStacktrace alloc] initWithTrace:trace binaryImages:self.binaryImages];
    XCTAssertEqual(1, [stacktrace.trace count]);
}

- (void)testLongTraceTrimmed {
    NSMutableArray *trace = [NSMutableArray new];

    for (int k = 0; k < 300; k++) {
        [trace addObject:self.frameDict];
    }
    BugsnagStacktrace *stacktrace = [[BugsnagStacktrace alloc] initWithTrace:trace binaryImages:self.binaryImages];
    XCTAssertEqual(200, [stacktrace.trace count]);
}

@end
