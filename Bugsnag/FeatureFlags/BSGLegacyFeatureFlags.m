//
//  BSGLegacyFeatureFlags.m
//  Bugsnag
//
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import "BSGLegacyFeatureFlags.h"

#import "BSGKeys.h"
#import "BSGStoredFeatureFlag.h"
#import "BugsnagFeatureFlag.h"
#import "BugsnagLogger.h"

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
        NSData *data = [NSData dataWithContentsOfFile:path];
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
