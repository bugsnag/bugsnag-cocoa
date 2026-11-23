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
#import "BSGUtils.h"

@interface BSGRemoteConfigStore ()
@property (nonatomic, strong) BSGFileLocations *fileLocations;
@property (nonatomic, strong) BugsnagConfiguration *configuration;
@end

static NSString *_Nullable BSGNormalizeETag(NSString *_Nullable etag) {
    if (![etag isKindOfClass:[NSString class]]) {
        return nil;
    }
    NSString *normalized = [etag stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([normalized hasPrefix:@"W/"]) {
        normalized = [normalized substringFromIndex:2];
    }
    if (normalized.length >= 2 && [normalized hasPrefix:@"\""] && [normalized hasSuffix:@"\""]) {
        normalized = [normalized substringWithRange:NSMakeRange(1, normalized.length - 2)];
    }
    return normalized;
}

static NSString * const BSGFetchStateAppVersionKey = @"appVersion";
static NSString * const BSGFetchStateFailureCountKey = @"fetchFailureCount";
static NSString * const BSGFetchStateNextAllowedFetchAtKey = @"nextAllowedFetchAt";
static NSString * const BSGFetchStateAttemptInProgressKey = @"attemptInProgress";

@implementation BSGRemoteConfigFetchState

+ (instancetype)stateFromJson:(NSDictionary *)json {
    if (![json isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    BSGRemoteConfigFetchState *state = [self new];
    id appVersion = json[BSGFetchStateAppVersionKey];
    if ([appVersion isKindOfClass:[NSString class]]) {
        state.appVersion = appVersion;
    }
    id failureCount = json[BSGFetchStateFailureCountKey];
    if ([failureCount isKindOfClass:[NSNumber class]] && [failureCount integerValue] > 0) {
        state.fetchFailureCount = [failureCount unsignedIntegerValue];
    }
    id nextAllowedFetchAt = json[BSGFetchStateNextAllowedFetchAtKey];
    if ([nextAllowedFetchAt isKindOfClass:[NSNumber class]]) {
        state.nextAllowedFetchAt = [NSDate dateWithTimeIntervalSince1970:[nextAllowedFetchAt doubleValue]];
    }
    id attemptInProgress = json[BSGFetchStateAttemptInProgressKey];
    if ([attemptInProgress isKindOfClass:[NSNumber class]]) {
        state.attemptInProgress = [attemptInProgress boolValue];
    }
    return state;
}

- (NSDictionary *)toJson {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    json[BSGFetchStateAppVersionKey] = self.appVersion;
    json[BSGFetchStateFailureCountKey] = @(self.fetchFailureCount);
    if (self.nextAllowedFetchAt) {
        json[BSGFetchStateNextAllowedFetchAtKey] = @([self.nextAllowedFetchAt timeIntervalSince1970]);
    }
    json[BSGFetchStateAttemptInProgressKey] = @(self.attemptInProgress);
    return json;
}

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

- (BSGRemoteConfiguration *)saveConfiguration:(BSGRemoteConfiguration *)configuration {
    NSDictionary *configurationJson = [configuration toJson];
    if (!configurationJson) {
        return nil;
    }
    NSString *path = [self configurationFilePath];
    __block BOOL saved = NO;
    // Serialised with other Bugsnag file operations (see saveFetchState:).
    dispatch_sync(BSGGetFileSystemQueue(), ^{
        NSError *error = nil;
        saved = BSGJSONWriteToFileAtomically(configurationJson, path, &error);
        if (!saved) {
            bsg_log_debug(@"%s: %@", __FUNCTION__, error);
        }
    });
    return saved ? configuration : nil;
}

- (BSGRemoteConfiguration *)updateExpiryDate:(NSDate *)expiryDate
                            configurationTag:(NSString *)configurationTag {
    BSGRemoteConfiguration *configuration = [self loadConfiguration];
    NSString *storedTag = BSGNormalizeETag(configuration.configurationTag);
    NSString *incomingTag = BSGNormalizeETag(configurationTag);
    if (storedTag != nil && incomingTag != nil && ![storedTag isEqualToString:incomingTag]) {
        return nil;
    }
    if (configuration != nil) {
        NSDate *previousExpiryDate = configuration.expiryDate;
        configuration.expiryDate = expiryDate;
        if ([self saveConfiguration:configuration]) {
            return configuration;
        }
        configuration.expiryDate = previousExpiryDate;
    }
    return nil;
}

- (BSGRemoteConfiguration *)loadConfiguration {
    NSError *error = nil;
    NSData *configurationData = [NSData dataWithContentsOfFile:[self configurationFilePath] options:0 error:&error];
    if (error) {
        return nil;
    }
    NSDictionary *configurationJson = BSGJSONDictionaryFromData(configurationData, 0, &error);
    return [BSGRemoteConfiguration configFromJson:configurationJson];
}

- (void)clear {
    NSString *remoteConfigPath = [self.fileLocations remoteConfigurations];
    // Serialised with other Bugsnag file operations (see saveFetchState:).
    dispatch_sync(BSGGetFileSystemQueue(), ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
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
    });
}

- (BSGRemoteConfigFetchState *)loadFetchState {
    NSString *path = self.fileLocations.remoteConfigFetchState;
    if (!path) {
        return nil;
    }
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:&error];
    if (!data) {
        return nil;
    }
    return [BSGRemoteConfigFetchState stateFromJson:BSGJSONDictionaryFromData(data, 0, &error)];
}

// The fetch state file lives in the Bugsnag root directory, so writes are serialised on the shared
// filesystem queue. This stops a fetch completing on a network queue from creating files while the
// root directory is being removed (e.g. Bugsnag.purge / test teardown). Must not be called on that queue.
- (BOOL)saveFetchState:(BSGRemoteConfigFetchState *)fetchState {
    NSString *path = self.fileLocations.remoteConfigFetchState;
    if (!path || !fetchState) {
        return NO;
    }
    NSDictionary *json = [fetchState toJson];
    __block BOOL saved = NO;
    dispatch_sync(BSGGetFileSystemQueue(), ^{
        NSError *error = nil;
        saved = BSGJSONWriteToFileAtomically(json, path, &error);
        if (!saved) {
            bsg_log_debug(@"%s: %@", __FUNCTION__, error);
        }
    });
    return saved;
}

- (void)clearFetchState {
    NSString *path = self.fileLocations.remoteConfigFetchState;
    if (!path) {
        return;
    }
    dispatch_sync(BSGGetFileSystemQueue(), ^{
        if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
            return;
        }
        NSError *error = nil;
        if (![[NSFileManager defaultManager] removeItemAtPath:path error:&error]) {
            bsg_log_debug(@"%s: %@", __FUNCTION__, error);
        }
    });
}

#pragma mark - Helpers

- (NSString *)configurationFilePath {
    NSString *fileName = [NSString stringWithFormat:@"core-%@", self.configuration.appVersion];
    return [[self.fileLocations remoteConfigurations] stringByAppendingPathComponent:fileName];
}

@end
