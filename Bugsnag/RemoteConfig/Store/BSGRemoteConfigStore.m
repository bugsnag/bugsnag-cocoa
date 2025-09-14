//
//  BSGRemoteConfigStore.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 11/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGRemoteConfigStore.h"
#import "BSGJSONSerialization.h"
#import "BugsnagLogger.h"

@interface BSGRemoteConfigStore ()
@property (nonatomic, strong) BSGFileLocations *fileLocations;
@property (nonatomic, strong) BugsnagConfiguration *configuration;
@end

@implementation BSGRemoteConfigStore

+ (instancetype)storeWithLocations:(BSGFileLocations *)fileLocations
                     configuration:(BugsnagConfiguration *)configuration {
    return [[self alloc] initWithLocations:fileLocations
                             configuration:configuration];
}

- (instancetype)initWithLocations:(BSGFileLocations *)fileLocations
                    configuration:(BugsnagConfiguration *)configuration {
    self = [super init];
    if (self) {
        _fileLocations = fileLocations;
        _configuration = configuration;
    }
    return self;
}

- (void)saveConfiguration:(BSGRemoteConfiguration *)configuration {
    NSDictionary *configurationJson = [configuration toJson];
    if (configurationJson) {
        NSError *error = nil;
        if(!BSGJSONWriteToFileAtomically(configurationJson, [self configurationFilePath], &error)) {
            bsg_log_debug(@"%s: %@", __FUNCTION__, error);
        }
    }
}

- (BSGRemoteConfiguration *)loadConfiguration {
    NSData *configurationData = [NSData dataWithContentsOfFile:[self configurationFilePath]];
    NSError *error = nil;
    NSDictionary *configurationJson = BSGJSONDictionaryFromData(configurationData, 0, &error);
    return [BSGRemoteConfiguration configFromJson:configurationJson];
}

- (void)clear {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *remoteConfigPath = [self.fileLocations remoteConfigurations];
    NSError *error = nil;
    NSArray<NSString *> *files = [fileManager contentsOfDirectoryAtPath:remoteConfigPath error:&error];
    if (error) {
        bsg_log_debug(@"%s: %@", __FUNCTION__, error);
        return;
    }
    for (NSString *file in files) {
        NSString *filePath = [remoteConfigPath stringByAppendingPathComponent:file];
        NSError *removeError = nil;
        [fileManager removeItemAtPath:filePath error:&removeError];
        if (removeError) {
            bsg_log_debug(@"%s: %@", __FUNCTION__, removeError);
        }
    }
}

#pragma mark - Helpers

- (NSString *)configurationFilePath {
    NSString *fileName = [NSString stringWithFormat:@"core-%@", self.configuration.appVersion];
    return [[self.fileLocations remoteConfigurations] stringByAppendingPathComponent:fileName];
}

@end
