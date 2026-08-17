//
//  BSGFilesystem.h
//  Bugsnag
//
//  Created by Karl Stenerud on 27.06.23.
//  Copyright © 2023 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BSGFilesystem : NSObject

/**
 * Builds all necessary intervening directories to make the given directory path exist.
 */
+ (nullable NSError *)ensurePathExists:(NSString *)path;

/**
 * Deletes the given path and recreates it (as a directory).
 */
+ (nullable NSError *)rebuildPath:(NSString *)path;

/**
 * Whether Bugsnag-managed files should be included in device backups.
 */
+ (BOOL)fileBackupSupport;

/**
 * Controls whether Bugsnag-managed files should be included in device backups.
 */
+ (void)setFileBackupSupport:(BOOL)fileBackupSupport;

/**
 * Returns YES when existing SDK files must be reconciled with the current
 * backup setting. The result is persisted after reconciliation completes.
 */
+ (BOOL)needsFileBackupSupportReconciliation;

/** Marks existing SDK files as reconciled with the current backup setting. */
+ (void)markFileBackupSupportReconciled;

/**
 * Applies the current backup support setting to the given path, if it exists.
 */
+ (nullable NSError *)applyFileBackupSupportToPath:(NSString *)path;

/**
 * Applies the current backup support setting to the given path and any existing contents.
 */
+ (void)applyFileBackupSupportToPathAndContents:(NSString *)path;

/**
 * Writes data to a file and applies the current backup support setting to the file.
 */
+ (BOOL)writeData:(NSData *)data toFile:(NSString *)path options:(NSDataWritingOptions)options error:(NSError * __autoreleasing *)error;

@end

NS_ASSUME_NONNULL_END
