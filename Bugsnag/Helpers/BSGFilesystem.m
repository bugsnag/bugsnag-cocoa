//
//  BSGFilesystem.m
//  Bugsnag
//
//  Created by Karl Stenerud on 27.06.23.
//  Copyright © 2023 Bugsnag Inc. All rights reserved.
//

#import "BSGFilesystem.h"

@implementation BSGFilesystem

+ (nullable NSError *)ensurePathExists:(NSString *)path {
    NSError *error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = false;
    BOOL exists = [fm fileExistsAtPath:path isDirectory:&isDir];

    if (exists && !isDir) {
        [fm removeItemAtPath:path error:&error];
        if (error != nil) {
            return error;
        }
        exists = NO;
    }

    if (!exists) {
        [fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
    }
    return error;
}

+ (nullable NSError *)rebuildPath:(NSString *)path {
    NSError *error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:path]) {
        [fm removeItemAtPath:path error:&error];
        if (error != nil) {
            return error;
        }
    }
    return [self ensurePathExists:path];
}

@end
