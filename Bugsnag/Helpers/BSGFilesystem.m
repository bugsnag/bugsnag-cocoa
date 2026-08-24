//
//  BSGFilesystem.m
//  Bugsnag
//
//  Created by Karl Stenerud on 27.06.23.
//  Copyright © 2023 Bugsnag Inc. All rights reserved.
//

#import "BSGFilesystem.h"

#import "BugsnagLogger.h"

@implementation BSGFilesystem

// Mirrors BugsnagConfiguration.fileBackupSupport:
// NO keeps SDK diagnostic files local-only by excluding them from Apple backups.
// YES allows those files to be included in iCloud and Finder/iTunes backups.
static BOOL g_fileBackupSupport = NO;
static NSString *const BSGFileBackupSupportReconciliationKey =
    @"com.bugsnag.file-backup-support.reconciled-value";

+ (NSString *)backupSupportDescription {
    return self.fileBackupSupport ? @"enabled (included in backups)" : @"disabled (excluded from backups)";
}

+ (NSString *)backupExclusionDescription {
#if TARGET_OS_TV
    return @"unchanged on tvOS";
#else
    return self.fileBackupSupport ? @"NO" : @"YES";
#endif
}

+ (nullable NSError *)ensurePathExists:(NSString *)path {
    NSError *error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = false;
    BOOL exists = [fm fileExistsAtPath:path isDirectory:&isDir];

    if (exists && !isDir) {
        bsg_log_debug(@"[File backup support] Replacing non-directory at SDK path: %@", path);
        [fm removeItemAtPath:path error:&error];
        if (error != nil) {
            return error;
        }
        exists = NO;
    }

    if (!exists) {
        [fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
        if (error == nil) {
            bsg_log_debug(@"[File backup support] Created SDK directory: %@", path);
        }
    } else {
        bsg_log_debug(@"[File backup support] SDK directory already exists: %@", path);
    }
    if (error == nil) {
        // New/rebuilt SDK directories must follow the current backup policy.
        [self applyFileBackupSupportToPath:path];
    }
    return error;
}

+ (nullable NSError *)rebuildPath:(NSString *)path {
    NSError *error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:path]) {
        bsg_log_debug(@"[File backup support] Rebuilding SDK directory, deleting existing path first: %@", path);
        [fm removeItemAtPath:path error:&error];
        if (error != nil) {
            return error;
        }
    }
    return [self ensurePathExists:path];
}

+ (BOOL)fileBackupSupport {
    @synchronized (self) {
        return g_fileBackupSupport;
    }
}

+ (void)setFileBackupSupport:(BOOL)fileBackupSupport {
    @synchronized (self) {
        g_fileBackupSupport = fileBackupSupport;
    }
    bsg_log_debug(@"[File backup support] BugsnagConfiguration.fileBackupSupport is %@; NSURLIsExcludedFromBackupKey should be %@ for Bugsnag files",
                  [self backupSupportDescription],
                  [self backupExclusionDescription]);
}

+ (NSString *)fileBackupSupportReconciliationValue {
    return self.fileBackupSupport ? @"enabled" : @"disabled";
}

+ (BOOL)needsFileBackupSupportReconciliation {
    NSString *lastReconciledValue =
        [NSUserDefaults.standardUserDefaults stringForKey:BSGFileBackupSupportReconciliationKey];
    return ![lastReconciledValue isEqualToString:[self fileBackupSupportReconciliationValue]];
}

+ (void)markFileBackupSupportReconciled {
    [NSUserDefaults.standardUserDefaults setObject:[self fileBackupSupportReconciliationValue]
                                            forKey:BSGFileBackupSupportReconciliationKey];
}

+ (nullable NSError *)applyFileBackupSupportToURL:(NSURL *)url {
#if TARGET_OS_TV
    bsg_log_debug(@"[File backup support] tvOS uses Caches storage; leaving backup metadata unchanged for %@", url.path);
    return nil;
#else
    // Apple uses an inverse key: excludedFromBackup=YES means no backup support.
    BOOL excludeFromBackup = !self.fileBackupSupport;
    NSNumber *currentValue = nil;
    [url getResourceValue:&currentValue forKey:NSURLIsExcludedFromBackupKey error:nil];
    if (currentValue != nil && currentValue.boolValue == excludeFromBackup) {
        return nil;
    }

    NSError *error = nil;
    if (![url setResourceValue:@(excludeFromBackup) forKey:NSURLIsExcludedFromBackupKey error:&error]) {
        // Backup metadata should not block Bugsnag's local persistence/retry flow.
        bsg_log_warn(@"Could not set backup support for %@: %@", url.path, error);
        return error;
    }
#if BSG_LOG_LEVEL >= BSG_LOGLEVEL_DEBUG
    [url getResourceValue:&currentValue forKey:NSURLIsExcludedFromBackupKey error:nil];
    bsg_log_debug(@"[File backup support] Applied NSURLIsExcludedFromBackupKey=%@ to %@ (actual=%@)",
                  excludeFromBackup ? @"YES" : @"NO",
                  url.path,
                  currentValue);
#endif  BSG_LOG_LEVEL >= BSG_LOGLEVEL_DEBUG
    return nil;
#endif
}

+ (nullable NSError *)applyFileBackupSupportToPath:(NSString *)path {
    if (![NSFileManager.defaultManager fileExistsAtPath:path]) {
        bsg_log_debug(@"[File backup support] Skipping missing SDK path: %@", path);
        return nil;
    }

    return [self applyFileBackupSupportToURL:[NSURL fileURLWithPath:path]];
}

+ (void)applyFileBackupSupportToPathAndContents:(NSString *)path {
    bsg_log_debug(@"[File backup support] Reconciling existing SDK path and contents: %@", path);
    [self applyFileBackupSupportToPath:path];

#if TARGET_OS_TV
    return;
#else
    BOOL isDirectory = NO;
    if (![NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDirectory] || !isDirectory) {
        return;
    }

    NSURL *rootURL = [NSURL fileURLWithPath:path];
    NSDirectoryEnumerator<NSURL *> *enumerator =
        [NSFileManager.defaultManager enumeratorAtURL:rootURL
                           includingPropertiesForKeys:@[NSURLIsExcludedFromBackupKey]
                                              options:0
                                         errorHandler:nil];
    for (NSURL *url in enumerator) {
        // The prefetched resource value avoids writes when policy is already correct.
        [self applyFileBackupSupportToURL:url];
    }
#endif
}

+ (BOOL)writeData:(NSData *)data toFile:(NSString *)path options:(NSDataWritingOptions)options error:(NSError * __autoreleasing *)error {
    BOOL success = [data writeToFile:path options:options error:error];
    if (success) {
        // File replacement can drop resource values, so reapply after each write.
        bsg_log_debug(@"[File backup support] Wrote SDK file; reapplying backup policy: %@", path);
        [self applyFileBackupSupportToPath:path];
    }
    return success;
}

@end
