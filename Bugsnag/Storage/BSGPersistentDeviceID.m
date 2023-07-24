//
//  BSGPersistentDeviceID.m
//  Bugsnag-iOS
//
//  Created by Karl Stenerud on 26.06.23.
//  Copyright © 2023 Bugsnag Inc. All rights reserved.
//

#import "BSGPersistentDeviceID.h"
#import "BSGJSONSerialization.h"
#import "BSGFilesystem.h"
#import "BSG_KSSysCtl.h"
#import "BSGKeys.h"
#if __has_include(<UIKit/UIDevice.h>)
#import <UIKit/UIKit.h>
#endif
#if __has_include(<WatchKit/WatchKit.h>)
#import <WatchKit/WatchKit.h>
#endif
#import <CommonCrypto/CommonDigest.h>
#import <sys/sysctl.h>
#import <mach/machine.h>

@interface BSGPersistentDeviceID ()

- (instancetype)initWithExternalID:(nonnull NSString *)externalID internalID:(nonnull NSString *)internalID;

@end

#pragma mark Generator

// Used to compute deviceId; mimics +[BSG_KSSystemInfo CPUArchForCPUType:subType:]
static NSString * _Nullable cpuArch(void) {
    cpu_type_t cpuType = 0;
    size_t size = sizeof cpuType;
    if (sysctlbyname("hw.cputype", &cpuType, &size, NULL, 0) != 0) {
        return nil;
    }

    cpu_subtype_t subType = 0;
    size = sizeof subType;
    if (sysctlbyname("hw.cpusubtype", &subType, &size, NULL, 0) != 0) {
        return nil;
    }

    switch (cpuType) {
        case CPU_TYPE_ARM: {
            switch (subType) {
                case CPU_SUBTYPE_ARM_V6:
                    return @"armv6";
                case CPU_SUBTYPE_ARM_V7:
                    return @"armv7";
                case CPU_SUBTYPE_ARM_V7F:
                    return @"armv7f";
                case CPU_SUBTYPE_ARM_V7K:
                    return @"armv7k";
#ifdef CPU_SUBTYPE_ARM_V7S
                case CPU_SUBTYPE_ARM_V7S:
                    return @"armv7s";
#endif
                case CPU_SUBTYPE_ARM_V8:
                    return @"armv8";
            }
            break;
        }
        case CPU_TYPE_ARM64: {
            switch (subType) {
                case CPU_SUBTYPE_ARM64E:
                    return @"arm64e";
                default:
                    return @"arm64";
            }
        }
        case CPU_TYPE_ARM64_32: {
            // Ignore arm64_32_v8 subtype
            return @"arm64_32";
        }
        case CPU_TYPE_X86:
            return @"x86";
        case CPU_TYPE_X86_64:
            return @"x86_64";
    }

    return nil;
}

static NSString * _Nullable sysctlString(const char *name) {
    char value[32];
    size_t size = sizeof value;
    if (sysctlbyname(name, value, &size, NULL, 0) == 0) {
        value[sizeof value - 1] = '\0';
        return [NSString stringWithCString:value encoding:NSUTF8StringEncoding];
    } else {
        return nil;
    }
}

static NSData * _Nonnull dataForString(NSString * _Nullable str) {
    if (str == nil) {
        return [NSData data];
    }
    return (NSData * _Nonnull)[str dataUsingEncoding:NSUTF8StringEncoding];
}

static bool isAllZeroes(NSData * _Nullable data) {
    const uint8_t *bytes = (const uint8_t*)data.bytes;
    for (NSUInteger i = 0; i < data.length; i++) {
        if (bytes[i] != 0) {
            return false;
        }
    }
    return true;
}

static NSMutableData * _Nonnull generateIdentificationData(void) {
    NSMutableData *data = nil;

#if TARGET_OS_WATCH
    data = [NSMutableData dataWithLength:16];
    [[[WKInterfaceDevice currentDevice] identifierForVendor] getUUIDBytes:(uint8_t*)data.mutableBytes];
#elif __has_include(<UIKit/UIDevice.h>)
    data = [NSMutableData dataWithLength:16];
    [[UIDevice currentDevice].identifierForVendor getUUIDBytes:(uint8_t*)data.mutableBytes];
#else
    data = [NSMutableData dataWithLength:6];
    bsg_kssysctl_getMacAddress(BSGKeyDefaultMacName, [data mutableBytes]);
#endif

    if (isAllZeroes(data)) {
        // If we failed to get an initial identifier via Apple APIs, generate a random one.
        data = [NSMutableData dataWithLength:16];
        [[NSUUID UUID] getUUIDBytes:(uint8_t *)data.mutableBytes];
    }

    // Append some device-specific data.
    [data appendData:dataForString(sysctlString("hw.machine"))];
    [data appendData:dataForString(sysctlString("hw.model"))];
    [data appendData:dataForString(cpuArch())];

    // Append the bundle ID.
    [data appendData:dataForString(NSBundle.mainBundle.bundleIdentifier)];

    return data;
}

static NSString * _Nonnull computeHash(NSData * _Nullable data) {
    // SHA the whole thing.
    uint8_t sha[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1([data bytes], (CC_LONG)[data length], sha);

    NSMutableString *hash = [NSMutableString string];
    for (size_t i = 0; i < sizeof(sha); i++) {
        [hash appendFormat:@"%02x", sha[i]];
    }

    return hash;
}

static NSString * _Nonnull generateExternalDeviceID(void) {
    return computeHash(generateIdentificationData());
}

static NSString * _Nonnull generateInternalDeviceID(void) {
    // ROAD-1488: internal device ID should be different.
    uint8_t additionalData[] = {251};
    NSMutableData *data = generateIdentificationData();
    [data appendBytes:additionalData length:sizeof(additionalData)];
    return computeHash(data);
}

#pragma mark -
#pragma mark Persistence

static NSString * _Nullable getString(NSDictionary* _Nonnull dict, NSString * _Nonnull key) {
    NSString *value = dict[key];
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

static NSError *save(NSString * _Nonnull filePath, BSGPersistentDeviceID *deviceID) {
    NSString *dir = [filePath stringByDeletingLastPathComponent];
    NSError *error = [BSGFilesystem ensurePathExists:dir];
    if (error != nil) {
        return error;
    }

    BSGJSONWriteToFileAtomically(@{
        @"deviceID": deviceID.external,
        @"internalDeviceID": deviceID.internal,
    }, filePath, &error);
    return error;
}

static BSGPersistentDeviceID * _Nonnull deviceIDWithPath(NSString * _Nonnull filePath) {
    bool requiresSave = false;
    NSString *externalID = nil;
    NSString *internalID = nil;

    NSError *error = nil;
    NSDictionary *dict = BSGJSONDictionaryFromFile(filePath, 0, &error);
    if (dict) {
        externalID = getString(dict, @"deviceID");
        internalID = getString(dict, @"internalDeviceID");
    }
    if (externalID == nil) {
        externalID = generateExternalDeviceID();
        requiresSave = true;
    }
    if (internalID == nil) {
        internalID = generateInternalDeviceID();
        requiresSave = true;
    }

    BSGPersistentDeviceID *deviceID = [[BSGPersistentDeviceID alloc] initWithExternalID:externalID
                                                                             internalID:internalID];

    if (requiresSave) {
        save(filePath, deviceID);
    }

    return deviceID;
}

#pragma mark -
#pragma mark BSGPersistentDeviceID

@implementation BSGPersistentDeviceID

+ (nonnull BSGPersistentDeviceID *)current {
    static dispatch_once_t once_t;
    static BSGPersistentDeviceID *deviceID;
    dispatch_once(&once_t, ^{
        NSString *topLevelDir = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
        NSString *dirPath = [topLevelDir stringByAppendingFormat:@"/bugsnag-shared-%@", [[NSBundle mainBundle] bundleIdentifier]];
        NSString *filePath = [dirPath stringByAppendingPathComponent:@"device-id.json"];
        deviceID = deviceIDWithPath(filePath);
    });
    return deviceID;
}

- (instancetype)initWithExternalID:(nonnull NSString *)externalID internalID:(nonnull NSString *)internalID {
    if ((self = [super init])) {
        _external = externalID;
        _internal = internalID;
    }
    return self;
}

+ (instancetype)unitTest_deviceIDWithFilePath:(nonnull NSString *)filePath {
    return deviceIDWithPath(filePath);
}

@end
