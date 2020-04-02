//
//  BugsnagDeviceWithState.m
//  Bugsnag
//
//  Created by Jamie Lynch on 01/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "BugsnagDeviceWithState.h"
#import "BugsnagCollections.h"
#import "BugsnagLogger.h"

NSNumber *BSGDeviceFreeSpace(NSSearchPathDirectory directory) {
    NSNumber *freeBytes = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(directory, NSUserDomainMask, true);
    NSString *path = [searchPaths lastObject];

    NSError *error;
    NSDictionary *fileSystemAttrs =
            [fileManager attributesOfFileSystemForPath:path error:&error];

    if (error) {
        bsg_log_warn(@"Failed to read free disk space: %@", error);
    } else {
        freeBytes = [fileSystemAttrs objectForKey:NSFileSystemFreeSize];
    }
    return freeBytes;
}

@interface BugsnagDevice ()
+ (void)populateFields:(BugsnagDevice *)device
            dictionary:(NSDictionary *)event;

- (NSDictionary *)toDict;
@end

@interface BugsnagDeviceWithState ()
@property (nonatomic, readonly) NSDateFormatter *formatter;
@end

@implementation BugsnagDeviceWithState

- (instancetype)init {
    if (self = [super init]) {
        _formatter = [NSDateFormatter new];
        _formatter.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ssZZZ";
        _formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    }
    return self;
}

+ (BugsnagDeviceWithState *)deviceWithOomData:(NSDictionary *)data {
    BugsnagDeviceWithState *device = [BugsnagDeviceWithState new];
    device.id = data[@"id"];
    device.osVersion = data[@"osVersion"];
    device.osName = data[@"osName"];
    device.model = data[@"model"];
    device.modelNumber = data[@"modelNumber"];
    device.locale = data[@"locale"];
    return device;
}

+ (BugsnagDeviceWithState *)deviceWithDictionary:(NSDictionary *)event {
    BugsnagDeviceWithState *device = [BugsnagDeviceWithState new];
    [self populateFields:device dictionary:event];
    device.orientation = [event valueForKeyPath:@"user.state.deviceState.orientation"];
    device.freeMemory = [event valueForKeyPath:@"system.memory.free"];
    device.freeDisk = BSGDeviceFreeSpace(NSCachesDirectory);

    NSString *val = [event valueForKeyPath:@"report.timestamp"];

    if (val != nil) {
        device.time = [device.formatter dateFromString:val];
    }
    return device;
}

- (NSDictionary *)toDict {
    NSMutableDictionary *dict = (NSMutableDictionary *) [super toDict];
    BSGDictInsertIfNotNil(dict, self.freeDisk, @"freeDisk");
    BSGDictInsertIfNotNil(dict, self.freeMemory, @"freeMemory");
    BSGDictInsertIfNotNil(dict, self.orientation, @"orientation");

    if (self.time != nil) {
        BSGDictInsertIfNotNil(dict, [self.formatter stringFromDate:self.time], @"time");
    }
    return dict;
}

@end
