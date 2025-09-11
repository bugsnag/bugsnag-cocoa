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
@property (nonatomic, strong) NSString *appVersion;
@end

@implementation BSGRemoteConfigStore

+ (instancetype)repositoryWithLocations:(BSGFileLocations *)fileLocations
                             appVersion:(NSString *)appVersion {
    return [[self alloc] initWithLocations:fileLocations
                                appVersion:appVersion];
}

- (instancetype)initWithLocations:(BSGFileLocations *)fileLocations
                       appVersion:(NSString *)appVersion {
    self = [super init];
    if (self) {
        _fileLocations = fileLocations;
        _appVersion = appVersion;
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

- (NSString *)configurationFilePath {
    NSString *fileName = [NSString stringWithFormat:@"core-%@", self.appVersion];
    return [[self.fileLocations remoteConfigurations] stringByAppendingPathComponent:fileName];
}

@end
