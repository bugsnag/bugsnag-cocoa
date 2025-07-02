//
//  BugsnagDevice.m
//  Bugsnag
//
//  Created by Jamie Lynch on 01/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "BugsnagDevice.h"

#import "KSCrashReportFields.h"
#import "BSGSystemInfo.h"
#import "BugsnagConfiguration.h"
#import "BugsnagCollections.h"
#import "BSGPersistentDeviceID.h"

@implementation BugsnagDevice

+ (BugsnagDevice *)deserializeFromJson:(NSDictionary *)json {
    BugsnagDevice *device = [BugsnagDevice new];
    if (json != nil) {
        device.jailbroken = [json[@"jailbroken"] boolValue];
        device.id = BSGPersistentDeviceID.current.external;
        device.locale = json[@"locale"];
        device.manufacturer = json[@"manufacturer"];
        device.model = json[@"model"];
        device.modelNumber = json[@"modelNumber"];
        device.osName = json[@"osName"];
        device.osVersion = json[@"osVersion"];
        device.runtimeVersions = json[@"runtimeVersions"];
        device.totalMemory = json[@"totalMemory"];
    }
    return device;
}

+ (BugsnagDevice *)deviceWithKSCrashReport:(NSDictionary *)event {
    BugsnagDevice *device = [BugsnagDevice new];
    [self populateFields:device dictionary:event];
    return device;
}

+ (void)populateFields:(BugsnagDevice *)device
            dictionary:(NSDictionary *)event {
    NSDictionary *system = event[@"system"];
    device.jailbroken = [system[KSCrashField_Jailbroken] boolValue];
    device.id = BSGPersistentDeviceID.current.external;
    device.locale = [[NSLocale currentLocale] localeIdentifier];
    device.manufacturer = @"Apple";
    device.model = system[KSCrashField_Machine];
    device.modelNumber = system[KSCrashField_Model];
    device.osName = system[KSCrashField_SystemName];
    // "ProductName" changed from "Mac OS X" to "macOS" in 11.0
    if ([system[KSCrashField_SystemName] isEqual:@"macOS"] || [system[KSCrashField_SystemName] isEqual:@"Mac OS X"]) {
        device.osName = @"Mac OS";
    }

    device.osVersion = system[KSCrashField_SystemVersion];
    device.totalMemory = system[KSCrashField_Memory][KSCrashField_Size];

    NSMutableDictionary *runtimeVersions = [NSMutableDictionary new];
    runtimeVersions[@"osBuild"] = system[KSCrashField_OSVersion];
    runtimeVersions[@"clangVersion"] = system[KSCrashField_ClangVersion];
    device.runtimeVersions = runtimeVersions;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[@"jailbroken"] = @(self.jailbroken);
    dict[@"id"] = self.id;
    dict[@"locale"] = self.locale;
    dict[@"manufacturer"] = self.manufacturer;
    dict[@"model"] = self.model;
    dict[@"modelNumber"] = self.modelNumber;
    dict[@"osName"] = self.osName;
    dict[@"osVersion"] = self.osVersion;
    dict[@"runtimeVersions"] = self.runtimeVersions;
    dict[@"totalMemory"] = self.totalMemory;
    return dict;
}

- (void)appendRuntimeInfo:(NSDictionary *)info {
    NSMutableDictionary *versions = [self.runtimeVersions mutableCopy];
    [versions addEntriesFromDictionary:info];
    self.runtimeVersions = versions;
}

@end
