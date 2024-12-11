//
//  BSGPersistentFeatureFlagStore.m
//  Bugsnag
//
//  Created by Robert B on 25/11/2024.
//  Copyright © 2024 Bugsnag. All rights reserved.
//

#import "BSGPersistentFeatureFlagStore.h"
#import "BugsnagInternals.h"
#import "BSGStoredFeatureFlag.h"
#import "BugsnagLogger.h"
#import <Foundation/Foundation.h>

BSG_OBJC_DIRECT_MEMBERS
@interface BSGPersistentFeatureFlagStore ()

@property(nonatomic, readwrite) uint64_t currentIndex;
@property(nonatomic, strong) NSString *directoryPath;

@end

BSG_OBJC_DIRECT_MEMBERS
@implementation BSGPersistentFeatureFlagStore

- (nonnull instancetype)initWithStorageDirectory:(NSString *)directory {
    if ((self = [super init]) != nil) {
        _currentIndex = 0;
        _directoryPath = directory;
    }
    return self;
}

#pragma mark - BSGFeatureFlagStore

- (nonnull NSArray<BugsnagFeatureFlag *> *)allFlags {
    NSMutableArray<BSGStoredFeatureFlag *> *storedFlags = [NSMutableArray new];
    for (NSString *path in [self pathsForFlags]) {
        NSData *data = [NSData dataWithContentsOfFile:path];
        NSError *error = nil;
        NSDictionary *content = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
        if (error == nil) {
            [storedFlags addObject:[BSGStoredFeatureFlag fromJSON:content]];
        } else {
            bsg_log_err(@"Unable to decode feature flag: %@", error);
        }
    }
    
    [storedFlags sortUsingComparator:^NSComparisonResult(BSGStoredFeatureFlag *  _Nonnull obj1, BSGStoredFeatureFlag *  _Nonnull obj2) {
        if (obj1.index == obj2.index) {
            return NSOrderedSame;
        }
        return obj1.index < obj2.index ? NSOrderedAscending : NSOrderedDescending;
    }];
    NSMutableArray<BugsnagFeatureFlag *> *flags = [NSMutableArray new];
    for (BSGStoredFeatureFlag *storedFeatureFlag in storedFlags) {
        BugsnagFeatureFlag *featureFlag = [BugsnagFeatureFlag flagWithName:storedFeatureFlag.name variant:storedFeatureFlag.variant];
        [flags addObject:featureFlag];
    }
    return flags;
}

- (BOOL)isEmpty {
    return [self pathsForFlags].count == 0;
}

- (void)addFeatureFlag:(nonnull NSString *)name withVariant:(nullable NSString *)variant {
    @synchronized (self) {
        NSString *path = [self pathForFlagWithName:name];
        BSGStoredFeatureFlag *flag = [[BSGStoredFeatureFlag alloc] initWithName:name
                                                                        variant:variant
                                                                          index:self.currentIndex];
        self.currentIndex += 1;
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:[flag toJson] options:kNilOptions error:&error];
        if (error == nil) {
            [data writeToFile:path options:0 error:&error];
            if (error != nil) {
                bsg_log_err(@"Unable to save feature flag: %@", error);
            }
        } else {
            bsg_log_err(@"Unable to encode feature flag: %@", error);
        }
    }
}

- (void)addFeatureFlags:(nonnull NSArray<BugsnagFeatureFlag *> *)featureFlags {
    for (BugsnagFeatureFlag *flag in featureFlags) {
        [self addFeatureFlag:flag.name withVariant:flag.variant];
    }
}

- (void)clear:(nullable NSString *)name {
    @synchronized (self) {
        [self deleteFile:[self pathForFlagWithName:name]];
    }
}

- (void)clear {
    @synchronized (self) {
        NSArray *paths = [self pathsForFlags];
        for (NSString *path in paths) {
            [self deleteFile:path];
        }
    }
}

- (NSArray *)pathsForFlags {
    NSError *error = nil;
    NSArray *paths = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.directoryPath error:&error];
    if (error == nil) {
        NSMutableArray *result = [NSMutableArray new];
        for (NSString *path in paths) {
            [result addObject:[self.directoryPath stringByAppendingPathComponent:path]];
        }
        return result;
    } else {
        bsg_log_err(@"Unable to get paths for feature flags: %@", error);
        return @[];
    }
}

- (NSString *)pathForFlagWithName:(NSString *)name {
    return [self.directoryPath stringByAppendingPathComponent: [NSString stringWithFormat:@"%@.json", name]];
}

- (void)deleteFile:(NSString *)path {
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
    if (error != nil) {
        bsg_log_err(@"Unable to delete a feature flag file: %@", error);
    }
}

@end
