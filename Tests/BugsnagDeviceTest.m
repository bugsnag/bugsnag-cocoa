//
//  BugsnagDeviceTest.m
//  Tests
//
//  Created by Jamie Lynch on 02/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "BugsnagConfiguration.h"
#import "BugsnagDeviceWithState.h"
#import "BugsnagDevice.h"
#import "BugsnagTestConstants.h"

NSNumber *BSGDeviceFreeSpace(NSSearchPathDirectory directory);

@interface BugsnagDevice ()
+ (BugsnagDevice *)deviceWithDictionary:(NSDictionary *)event;

- (NSDictionary *)toDictionary;
@end

@interface BugsnagDeviceWithState ()
+ (BugsnagDeviceWithState *)deviceWithDictionary:(NSDictionary *)event;

+ (BugsnagDeviceWithState *)deviceWithOomData:(NSDictionary *)data;

- (NSDictionary *)toDictionary;
@end

@interface BugsnagDeviceTest : XCTestCase
@property NSDictionary *data;
@end

@implementation BugsnagDeviceTest

- (void)setUp {
    [super setUp];
    self.data = @{
            @"system": @{
                    @"model": @"iPhone 6",
                    @"machine": @"x86_64",
                    @"system_name": @"iPhone OS",
                    @"system_version": @"8.1",
                    @"os_version": @"14B25",
                    @"clang_version": @"10.0.0 (clang-1000.11.45.5)",
                    @"jailbroken": @YES,
                    @"memory": @{
                            @"usable": @15065522176,
                            @"free": @742920192
                    },
                    @"device_app_hash": @"123"
            },
            @"report": @{
                    @"timestamp": @"2014-12-02T01:56:13Z"
            },
            @"user": @{
                    @"state": @{
                            @"deviceState": @{
                                    @"orientation": @"portrait"
                            }
                    }
            }
    };
}

- (void)testDevice {
    BugsnagDevice *device = [BugsnagDevice deviceWithDictionary:self.data];

    // verify stateless fields
    XCTAssertTrue(device.jailbroken);
    XCTAssertEqualObjects(@"123", device.id);
    XCTAssertNotNil(device.locale);
    XCTAssertEqualObjects(@"Apple", device.manufacturer);
    XCTAssertEqualObjects(@"x86_64", device.model);
    XCTAssertEqualObjects(@"iPhone 6", device.modelNumber);
    XCTAssertEqualObjects(@"iPhone OS", device.osName);
    XCTAssertEqualObjects(@"8.1", device.osVersion);
    XCTAssertEqualObjects(@15065522176, device.totalMemory);
    NSDictionary *runtimeVersions = @{
            @"osBuild": @"14B25",
            @"clangVersion": @"10.0.0 (clang-1000.11.45.5)"
    };
    XCTAssertEqualObjects(runtimeVersions, device.runtimeVersions);
}

- (void)testDeviceWithState {
    BugsnagDeviceWithState *device = [BugsnagDeviceWithState deviceWithDictionary:self.data];

    // verify stateless fields
    XCTAssertTrue(device.jailbroken);
    XCTAssertEqualObjects(@"123", device.id);
    XCTAssertNotNil(device.locale);
    XCTAssertEqualObjects(@"Apple", device.manufacturer);
    XCTAssertEqualObjects(@"x86_64", device.model);
    XCTAssertEqualObjects(@"iPhone 6", device.modelNumber);
    XCTAssertEqualObjects(@"iPhone OS", device.osName);
    XCTAssertEqualObjects(@"8.1", device.osVersion);
    XCTAssertEqualObjects(@15065522176, device.totalMemory);
    NSDictionary *runtimeVersions = @{
            @"osBuild": @"14B25",
            @"clangVersion": @"10.0.0 (clang-1000.11.45.5)"
    };
    XCTAssertEqualObjects(runtimeVersions, device.runtimeVersions);

    // verify stateful fields
    XCTAssertTrue(device.freeDisk > 0);
    XCTAssertEqualObjects(@742920192, device.freeMemory);
    XCTAssertEqualObjects(@"portrait", device.orientation);

    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ssZZZ";
    formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    XCTAssertEqualObjects([formatter dateFromString:@"2014-12-02T01:56:13Z"], device.time);
}

- (void)testDeviceToDict {
    BugsnagDevice *device = [BugsnagDevice deviceWithDictionary:self.data];
    device.locale = @"en-US";
    NSDictionary *dict = [device toDictionary];

    // verify stateless fields
    XCTAssertTrue(dict[@"jailbroken"]);
    XCTAssertEqualObjects(@"123", dict[@"id"]);
    XCTAssertEqualObjects(@"en-US", dict[@"locale"]);
    XCTAssertEqualObjects(@"Apple", dict[@"manufacturer"]);
    XCTAssertEqualObjects(@"x86_64", dict[@"model"]);
    XCTAssertEqualObjects(@"iPhone 6", dict[@"modelNumber"]);
    XCTAssertEqualObjects(@"iPhone OS", dict[@"osName"]);
    XCTAssertEqualObjects(@"8.1", dict[@"osVersion"]);
    XCTAssertEqualObjects(@15065522176, dict[@"totalMemory"]);

    NSDictionary *runtimeVersions = @{
            @"osBuild": @"14B25",
            @"clangVersion": @"10.0.0 (clang-1000.11.45.5)"
    };
    XCTAssertEqualObjects(runtimeVersions, dict[@"runtimeVersions"]);
}

- (void)testDeviceWithStateToDict {
    BugsnagDeviceWithState *device = [BugsnagDeviceWithState deviceWithDictionary:self.data];
    device.locale = @"en-US";
    NSDictionary *dict = [device toDictionary];

    XCTAssertTrue(dict[@"jailbroken"]);
    XCTAssertEqualObjects(@"123", dict[@"id"]);
    XCTAssertEqualObjects(@"en-US", dict[@"locale"]);
    XCTAssertEqualObjects(@"Apple", dict[@"manufacturer"]);
    XCTAssertEqualObjects(@"x86_64", dict[@"model"]);
    XCTAssertEqualObjects(@"iPhone 6", dict[@"modelNumber"]);
    XCTAssertEqualObjects(@"iPhone OS", dict[@"osName"]);
    XCTAssertEqualObjects(@"8.1", dict[@"osVersion"]);
    XCTAssertEqualObjects(@15065522176, dict[@"totalMemory"]);

    NSDictionary *runtimeVersions = @{
            @"osBuild": @"14B25",
            @"clangVersion": @"10.0.0 (clang-1000.11.45.5)"
    };
    XCTAssertEqualObjects(runtimeVersions, dict[@"runtimeVersions"]);

    // verify stateless fields
    XCTAssertEqualObjects(@"portrait", dict[@"orientation"]);
    XCTAssertTrue(dict[@"freeDisk"] > 0);
    XCTAssertEqualObjects(@742920192, dict[@"freeMemory"]);

    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ssZZZ";
    formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    XCTAssertEqualObjects([formatter dateFromString:@"2014-12-02T01:56:13Z"], device.time);
}

- (void)testDeviceFromOOM {
    NSDictionary *oomData = @{
            @"id": @"123",
            @"osVersion": @"13.1",
            @"osName": @"macOS",
            @"model": @"iPhone 6",
            @"modelNumber": @"iPhone X",
            @"locale": @"yue"
    };

    BugsnagDeviceWithState *device = [BugsnagDeviceWithState deviceWithOomData:oomData];
    XCTAssertEqualObjects(@"123", device.id);
    XCTAssertEqualObjects(@"13.1", device.osVersion);
    XCTAssertEqualObjects(@"macOS", device.osName);
    XCTAssertEqualObjects(@"iPhone 6", device.model);
    XCTAssertEqualObjects(@"iPhone X", device.modelNumber);
    XCTAssertEqualObjects(@"yue", device.locale);
}

- (void)testDeviceFreeSpaceShouldBeLargeNumber {
    NSNumber *freeBytes = BSGDeviceFreeSpace(NSCachesDirectory);
    XCTAssertNotNil(freeBytes, @"expect a valid number for successful call to retrieve free space");
    XCTAssertGreaterThan([freeBytes integerValue], 1000, @"expect at least 1k of free space on test device");
}

- (void)testDeviceFreeSpaceShouldBeNilWhenFailsToRetrieveIt {
    NSSearchPathDirectory notAccessibleDirectory = NSAdminApplicationDirectory;
    NSNumber *freeBytes = BSGDeviceFreeSpace(notAccessibleDirectory);
    XCTAssertNil(freeBytes, @"expect nil when fails to retrieve free space for the directory");
}

@end
