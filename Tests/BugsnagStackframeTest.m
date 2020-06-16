//
//  BugsnagStackframeTest.m
//  Tests
//
//  Created by Jamie Lynch on 06/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "BugsnagStackframe.h"

@interface BugsnagStackframe ()
- (NSDictionary *)toDictionary;
+ (BugsnagStackframe *)frameFromDict:(NSDictionary *)dict withImages:(NSArray *)binaryImages;
@end

@interface BugsnagStackframeTest : XCTestCase
@property NSDictionary *frameDict;
@property NSArray *binaryImages;
@end

@implementation BugsnagStackframeTest

- (void)setUp {
    self.frameDict = @{
            @"symbol_addr": @0x10b574fa0,
            @"instruction_addr": @0x10b5756bf,
            @"object_addr": @0x10b54b000,
            @"object_name": @"/Library/bar/Bugsnag.h",
            @"symbol_name": @"-[BugsnagClient notify:handledState:block:]",
    };
    self.binaryImages = @[@{
            @"image_addr": @0x10b54b000,
            @"image_vmaddr": @0x102340922,
            @"uuid": @"B6D80CB5-A772-3D2F-B5A1-A3A137B8B58F",
            @"name": @"/Users/foo/Bugsnag.h",
    }];
}

- (void)testStackframeFromDict {
    BugsnagStackframe *frame = [BugsnagStackframe frameFromDict:self.frameDict withImages:self.binaryImages];
    XCTAssertEqualObjects(@"-[BugsnagClient notify:handledState:block:]", frame.method);
    XCTAssertEqualObjects(@"/Users/foo/Bugsnag.h", frame.machoFile);
    XCTAssertEqualObjects(@"B6D80CB5-A772-3D2F-B5A1-A3A137B8B58F", frame.machoUuid);
    XCTAssertEqualObjects(@0x102340922, frame.machoVmAddress);
    XCTAssertEqualObjects(@0x10b574fa0, frame.symbolAddress);
    XCTAssertEqualObjects(@0x10b54b000, frame.machoLoadAddress);
    XCTAssertEqualObjects(@0x10b5756bf, frame.frameAddress);
    XCTAssertFalse(frame.isPc);
    XCTAssertFalse(frame.isLr);
}

- (void)testStackframeToDict {
    BugsnagStackframe *frame = [BugsnagStackframe frameFromDict:self.frameDict withImages:self.binaryImages];
    NSDictionary *dict = [frame toDictionary];
    XCTAssertEqualObjects(@"-[BugsnagClient notify:handledState:block:]", dict[@"method"]);
    XCTAssertEqualObjects(@"/Users/foo/Bugsnag.h", dict[@"machoFile"]);
    XCTAssertEqualObjects(@"B6D80CB5-A772-3D2F-B5A1-A3A137B8B58F", dict[@"machoUUID"]);
    XCTAssertEqualObjects(@"0x102340922", dict[@"machoVMAddress"]);
    XCTAssertEqualObjects(@"0x10b574fa0", dict[@"symbolAddress"]);
    XCTAssertEqualObjects(@"0x10b54b000", dict[@"machoLoadAddress"]);
    XCTAssertEqualObjects(@"0x10b5756bf", dict[@"frameAddress"]);
    XCTAssertNil(dict[@"isPC"]);
    XCTAssertNil(dict[@"isLR"]);
}

- (void)testStackframeToDictPcLr {
    BugsnagStackframe *frame = [BugsnagStackframe frameFromDict:self.frameDict withImages:self.binaryImages];
    frame.isPc = true;
    frame.isLr = true;
    NSDictionary *dict = [frame toDictionary];
    XCTAssertTrue(dict[@"isPC"]);
    XCTAssertTrue(dict[@"isLR"]);
}

- (void)testStackframeBools {
    NSDictionary *dict = @{
            @"symbol_addr": @0x10b574fa0,
            @"instruction_addr": @0x10b5756bf,
            @"object_addr": @0x10b54b000,
            @"object_name": @"/Users/foo/Bugsnag.h",
            @"symbol_name": @"-[BugsnagClient notify:handledState:block:]",
            @"isPC": @YES,
            @"isLR": @NO
    };
    BugsnagStackframe *frame = [BugsnagStackframe frameFromDict:dict withImages:self.binaryImages];
    XCTAssertTrue(frame.isPc);
    XCTAssertFalse(frame.isLr);
}

- (void)testInvalidFrame {
    BugsnagStackframe *frame = [BugsnagStackframe frameFromDict:self.frameDict withImages:@[]];
    XCTAssertNil(frame);
}

@end
