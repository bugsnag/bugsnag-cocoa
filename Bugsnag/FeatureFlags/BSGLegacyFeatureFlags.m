//
//  BSGLegacyFeatureFlags.m
//  Bugsnag
//
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import "BSGLegacyFeatureFlags.h"

#import "BSGFeatureFlagFileFormat.h"
#import "BSGKeys.h"
#import "BSGStoredFeatureFlag.h"
#import "BugsnagFeatureFlag.h"
#import "BSGUtils.h"
#import "BugsnagLogger.h"

#import <fcntl.h>
#import <sys/stat.h>
#import <unistd.h>

// Each file holds one flag; this only stops an unexpectedly large file being read into memory
static const off_t BSGLegacyFeatureFlagMaxFileSize = 16 * 1024 * 1024;

/// Reads a JSON file, returning nil if it cannot be read. As with featureflag.bin, a symbolic link at the path is
/// not followed, and only regular files are read: anything else, such as a FIFO, is refused without blocking (see
/// BSGOpenRegularFile).
static NSData *_Nullable BSGReadLegacyFeatureFlagFile(NSString *path) {
    const int fd = BSGOpenRegularFile(path, O_RDONLY);
    if (fd == -1) {
        return nil;
    }
    NSMutableData *data = nil;
    struct stat st;
    if (fstat(fd, &st) == 0 && st.st_size <= BSGLegacyFeatureFlagMaxFileSize) {
        data = [NSMutableData dataWithLength:(NSUInteger)st.st_size];
        // A file that was shortened after fstat() cannot be read whole, and is skipped like any unreadable file
        if (data && !BSGFeatureFlagFileRead(fd, data.mutableBytes, data.length, 0)) {
            data = nil;
        }
    }
    close(fd);
    return data;
}

/// Returns whether a file's contents have the types expected by BSGStoredFeatureFlag. The SDK always
/// wrote a name, so a file without one is not a feature flag file.
static BOOL BSGIsValidStoredFeatureFlag(id content) {
    if (![content isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    id name = content[BSGKeyFeatureFlag];
    id variant = content[BSGKeyVariant];
    id index = content[@"index"];
    return ([name isKindOfClass:[NSString class]] &&
            (!variant || [variant isKindOfClass:[NSString class]]) &&
            (!index || [index isKindOfClass:[NSNumber class]]));
}

/// Whether a file in the directory is one of the JSON files. A flag with an empty name was saved as
/// ".json", which pathExtension treats as having no extension.
BOOL BSGIsLegacyFeatureFlagFile(NSString *file) {
    return [file hasSuffix:@".json"];
}

/// The flags saved in the JSON files, in the order they were added. Files that cannot be read or
/// decoded are skipped.
NSArray<BugsnagFeatureFlag *> * BSGLegacyFeatureFlags(NSArray<NSString *> *paths) {
    NSMutableArray<BSGStoredFeatureFlag *> *storedFlags = [NSMutableArray array];
    for (NSString *path in paths) {
        // A file can be deleted or become unreadable between listing and reading it
        NSData *data = BSGReadLegacyFeatureFlagFile(path);
        id content = data ? [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil] : nil;
        if (content && BSGIsValidStoredFeatureFlag(content)) {
            [storedFlags addObject:[BSGStoredFeatureFlag fromJSON:content]];
        } else {
            bsg_log_err(@"Unable to decode feature flag in %@", path.lastPathComponent);
        }
    }
    // A stable sort keeps files with the same index in the order they were listed
    [storedFlags sortWithOptions:NSSortStable usingComparator:^NSComparisonResult(BSGStoredFeatureFlag * _Nonnull obj1, BSGStoredFeatureFlag * _Nonnull obj2) {
        if (obj1.index == obj2.index) {
            return NSOrderedSame;
        }
        return obj1.index < obj2.index ? NSOrderedAscending : NSOrderedDescending;
    }];
    NSMutableArray<BugsnagFeatureFlag *> *flags = [NSMutableArray arrayWithCapacity:storedFlags.count];
    for (BSGStoredFeatureFlag *storedFlag in storedFlags) {
        [flags addObject:[BugsnagFeatureFlag flagWithName:storedFlag.name variant:storedFlag.variant]];
    }
    return flags;
}

NSArray<NSString *> * BSGRemoveLegacyFeatureFlagFiles(NSArray<NSString *> *paths) {
    NSMutableArray<NSString *> *remaining = [NSMutableArray array];
    for (NSString *path in paths) {
        NSError *error = nil;
        if (![[NSFileManager defaultManager] removeItemAtPath:path error:&error] &&
            !([error.domain isEqualToString:NSCocoaErrorDomain] && error.code == NSFileNoSuchFileError)) {
            bsg_log_err(@"Unable to delete a feature flag file: %@", error);
            [remaining addObject:path];
        }
    }
    return remaining;
}
