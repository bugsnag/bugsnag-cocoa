//
//  BugsnagStackframeTest.m
//  Tests
//
//  Created by Jamie Lynch on 06/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "BSG_KSMachHeaders.h"
#import "BugsnagStackframe+Private.h"

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
    XCTAssertNil(frame.type);
    XCTAssertFalse(frame.isPc);
    XCTAssertFalse(frame.isLr);
}

- (void)testStackframeToDict {
    BugsnagStackframe *frame = [BugsnagStackframe frameFromDict:self.frameDict withImages:self.binaryImages];
    NSDictionary *dict = [frame toDictionary];
    XCTAssertTrue([NSJSONSerialization isValidJSONObject:dict]);
    XCTAssertEqualObjects(@"-[BugsnagClient notify:handledState:block:]", dict[@"method"]);
    XCTAssertEqualObjects(@"/Users/foo/Bugsnag.h", dict[@"machoFile"]);
    XCTAssertEqualObjects(@"B6D80CB5-A772-3D2F-B5A1-A3A137B8B58F", dict[@"machoUUID"]);
    XCTAssertEqualObjects(@"0x102340922", dict[@"machoVMAddress"]);
    XCTAssertEqualObjects(@"0x10b574fa0", dict[@"symbolAddress"]);
    XCTAssertEqualObjects(@"0x10b54b000", dict[@"machoLoadAddress"]);
    XCTAssertEqualObjects(@"0x10b5756bf", dict[@"frameAddress"]);
    XCTAssertNil(frame.type);
    XCTAssertNil(dict[@"isPC"]);
    XCTAssertNil(dict[@"isLR"]);
}

- (void)testStackframeFromJson {
    BugsnagStackframe *frame = [BugsnagStackframe frameFromJson:@{
        @"frameAddress":        @"0x10b5756bf",
        @"isLR":                @NO,
        @"isPC":                @NO,
        @"machoFile":           @"/Users/foo/Bugsnag.h",
        @"machoLoadAddress":    @"0x10b54b000",
        @"machoUUID":           @"B6D80CB5-A772-3D2F-B5A1-A3A137B8B58F",
        @"machoVMAddress":      @"0x102340922",
        @"method":              @"-[BugsnagClient notify:handledState:block:]",
        @"symbolAddress":       @"0x10b574fa0",
        @"type":                @"cocoa",
    }];
    XCTAssertEqual(frame.isLr, NO);
    XCTAssertEqual(frame.isPc, NO);
    XCTAssertEqualObjects(frame.frameAddress,       @0x10b5756bf);
    XCTAssertEqualObjects(frame.machoFile,          @"/Users/foo/Bugsnag.h");
    XCTAssertEqualObjects(frame.machoLoadAddress,   @0x10b54b000);
    XCTAssertEqualObjects(frame.machoUuid,          @"B6D80CB5-A772-3D2F-B5A1-A3A137B8B58F");
    XCTAssertEqualObjects(frame.machoVmAddress,     @0x102340922);
    XCTAssertEqualObjects(frame.method,             @"-[BugsnagClient notify:handledState:block:]");
    XCTAssertEqualObjects(frame.symbolAddress,      @0x10b574fa0);
    XCTAssertEqualObjects(frame.type,               BugsnagStackframeTypeCocoa);
}

- (void)testStackframeFromJsonWithoutType {
    BugsnagStackframe *frame = [BugsnagStackframe frameFromJson:@{}];
    XCTAssertNil(frame.type);
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

#define AssertStackframeValues(stackframe_, machoFile_, frameAddress_, method_) \
    XCTAssertEqualObjects(stackframe_.method, method_); \
    XCTAssertEqualObjects(stackframe_.machoFile, machoFile_); \
    XCTAssertEqualObjects(stackframe_.frameAddress, @(frameAddress_)); \
    XCTAssertNil(stackframe_.type);

- (void)testDummyCallStackSymbols {
    bsg_mach_headers_initialize(); // Prevent symbolication
    
    NSArray<BugsnagStackframe *> *stackframes = [BugsnagStackframe stackframesWithCallStackSymbols:@[]];
    XCTAssertEqual(stackframes.count, 0);
    
    stackframes = [BugsnagStackframe stackframesWithCallStackSymbols:@[
        @"",
        @"1",
        @"ReactNativeTest",
        @"0x0000000000000000",
        @"__invoking___ + 140"]];
    XCTAssertEqual(stackframes.count, 0, @"Invalid stack frame strings should be ignored");
    
    stackframes = [BugsnagStackframe stackframesWithCallStackSymbols:@[
        @"0   ReactNativeTest                     0x000000010fda7f1b RCTJSErrorFromCodeMessageAndNSError + 79",
        @"1   ReactNativeTest                     0x000000010fd76897 __41-[RCTModuleMethod processMethodSignature]_block_invoke_2.103 + 97",
        @"2   ReactNativeTest                     0x000000010fccd9c3 -[BenCrash asyncReject:rejecter:] + 106",
        @"3   CoreFoundation                      0x00007fff23e44dec __invoking___ + 140",
        @"4   CoreFoundation                      0x00007fff23e41fd1 -[NSInvocation invoke] + 321",
        @"5   CoreFoundation                      0x00007fff23e422a4 -[NSInvocation invokeWithTarget:] + 68",
        @"6  ReactNativeTest                     0x000000010fd76eae -[RCTModuleMethod invokeWithBridge:module:arguments:] + 578",
        @"7 ReactNativeTest                     0x000000010fd79138 _ZN8facebook5reactL11invokeInnerEP9RCTBridgeP13RCTModuleDatajRKN5folly7dynamicE + 246"]];
    
    AssertStackframeValues(stackframes[0], @"ReactNativeTest",  0x000000010fda7f1b, @"RCTJSErrorFromCodeMessageAndNSError");
    AssertStackframeValues(stackframes[1], @"ReactNativeTest",  0x000000010fd76897, @"__41-[RCTModuleMethod processMethodSignature]_block_invoke_2.103");
    AssertStackframeValues(stackframes[2], @"ReactNativeTest",  0x000000010fccd9c3, @"-[BenCrash asyncReject:rejecter:]");
    AssertStackframeValues(stackframes[3], @"CoreFoundation",   0x00007fff23e44dec, @"__invoking___");
    AssertStackframeValues(stackframes[4], @"CoreFoundation",   0x00007fff23e41fd1, @"-[NSInvocation invoke]");
    AssertStackframeValues(stackframes[5], @"CoreFoundation",   0x00007fff23e422a4, @"-[NSInvocation invokeWithTarget:]");
    AssertStackframeValues(stackframes[6], @"ReactNativeTest",  0x000000010fd76eae, @"-[RCTModuleMethod invokeWithBridge:module:arguments:]");
    AssertStackframeValues(stackframes[7], @"ReactNativeTest",  0x000000010fd79138, @"_ZN8facebook5reactL11invokeInnerEP9RCTBridgeP13RCTModuleDatajRKN5folly7dynamicE");
    
    stackframes = [BugsnagStackframe stackframesWithCallStackSymbols:@[
        @"0   ReactNativeTest                     0x000000010fda7f1b",
        @"1   ReactNativeTest                     0x000000010fd76897",
        @"2   ReactNativeTest                     0x000000010fccd9c3",
        @"3   CoreFoundation                      0x00007fff23e44dec",
        @"4   CoreFoundation                      0x00007fff23e41fd1",
        @"5   CoreFoundation                      0x00007fff23e422a4",
        @"6   ReactNativeTest                     0x000000010fd76eae",
        @"7   ReactNative App                     0x000000010fd79138"]];
    
    AssertStackframeValues(stackframes[0], @"ReactNativeTest",  0x000000010fda7f1b, @"0x000000010fda7f1b");
    AssertStackframeValues(stackframes[1], @"ReactNativeTest",  0x000000010fd76897, @"0x000000010fd76897");
    AssertStackframeValues(stackframes[2], @"ReactNativeTest",  0x000000010fccd9c3, @"0x000000010fccd9c3");
    AssertStackframeValues(stackframes[3], @"CoreFoundation",   0x00007fff23e44dec, @"0x00007fff23e44dec");
    AssertStackframeValues(stackframes[4], @"CoreFoundation",   0x00007fff23e41fd1, @"0x00007fff23e41fd1");
    AssertStackframeValues(stackframes[5], @"CoreFoundation",   0x00007fff23e422a4, @"0x00007fff23e422a4");
    AssertStackframeValues(stackframes[6], @"ReactNativeTest",  0x000000010fd76eae, @"0x000000010fd76eae");
    AssertStackframeValues(stackframes[7], @"ReactNative App",  0x000000010fd79138, @"0x000000010fd79138");
}

- (void)testRealCallStackSymbols {
    bsg_mach_headers_register_for_changes(); // Ensure call stack can be symbolicated
    
    NSArray<NSString *> *callStackSymbols = [NSThread callStackSymbols];
    NSArray<BugsnagStackframe *> *stackframes = [BugsnagStackframe stackframesWithCallStackSymbols:callStackSymbols];
    XCTAssertEqual(stackframes.count, callStackSymbols.count, @"All valid stack frame strings should be parsed");
    XCTAssertTrue(stackframes.firstObject.isPc, @"The first stack frame should have isPc set to true");
    [stackframes enumerateObjectsUsingBlock:^(BugsnagStackframe *stackframe, NSUInteger idx, BOOL *stop) {
        XCTAssertNotNil(stackframe.frameAddress);
        XCTAssertNotNil(stackframe.machoFile);
        XCTAssertNotNil(stackframe.method);
        if (idx == stackframes.count - 1 &&
            (stackframe.machoLoadAddress == nil || stackframe.symbolAddress == nil)) {
            // The last callStackSymbol is often not in any Mach-O image, e.g.
            // "41  ???                                 0x0000000000000005 0x0 + 5"
            return;
        }
        XCTAssertNotNil(stackframe.machoUuid);
        XCTAssertNotNil(stackframe.machoVmAddress);
        XCTAssertNotNil(stackframe.machoLoadAddress);
        XCTAssertNotNil(stackframe.symbolAddress);
        XCTAssertNil(stackframe.type);
        XCTAssertTrue([callStackSymbols[idx] containsString:stackframe.method]);
    }];
}

@end
