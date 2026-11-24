//
//  BSGFileProtectionTestHelpers.h
//  Bugsnag
//
//  Helpers shared by the tests that set NSFileProtectionComplete on real files (BSGUtilsTests and BSGRunContextTests).
//

#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Real file protection classes

/// Whether real-file protection tests must fail rather than skip. Set BSG_REQUIRE_FILE_PROTECTION_TESTS=1
/// (TEST_RUNNER_BSG_REQUIRE_FILE_PROTECTION_TESTS=1 with xcodebuild) on a host whose screen is unlocked.
static inline BOOL BSGFileProtectionTestsAreRequired(void) {
    return [NSProcessInfo.processInfo.environment[@"BSG_REQUIRE_FILE_PROTECTION_TESTS"] isEqualToString:@"1"];
}

/// Sets NSFileProtectionComplete on a real file, returning nil or why it failed. On devices and Apple silicon Macs
/// (including the simulator) it needs an unlocked screen, else fails with NSCocoaErrorDomain 513.
static inline NSString *_Nullable BSGSetRealFileProtectionComplete(NSString *path) {
    NSURL *url = [NSURL fileURLWithPath:path];
    NSError *error = nil;
    if (![url setResourceValue:NSURLFileProtectionComplete forKey:NSURLFileProtectionKey error:&error]) {
        return [NSString stringWithFormat:@"setting it failed with %@ %ld (%@); is the screen locked?",
                error.domain, (long)error.code, error.localizedDescription];
    }
    NSURLFileProtectionType protection = nil;
    [url removeCachedResourceValueForKey:NSURLFileProtectionKey];
    if (![url getResourceValue:&protection forKey:NSURLFileProtectionKey error:&error]) {
        return [NSString stringWithFormat:@"reading it failed with %@ %ld (%@)",
                error.domain, (long)error.code, error.localizedDescription];
    }
    if (![protection isEqual:NSURLFileProtectionComplete]) {
        return [NSString stringWithFormat:@"the file has %@ after setting it", protection];
    }
    return nil;
}

/// Why this host cannot change a real file from NSFileProtectionComplete to NSFileProtectionCompleteUnlessOpen, or nil.
/// Tried on a scratch file holding `contents`. Some macOS versions (e.g. 26.7.2) refuse it with NSCocoaErrorDomain 513
/// even when unlocked. BSGDisableNSFileProtectionComplete failed there before this change too, so it is not a
/// regression and such hosts skip the test.
static inline NSString *_Nullable BSGRealCompleteFileCannotBeChanged(NSData *contents) {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    if (![contents writeToFile:path atomically:NO]) {
        return @"a scratch file could not be written";
    }
    NSString *reason = BSGSetRealFileProtectionComplete(path);
    NSError *error = nil;
    if (!reason && ![[NSURL fileURLWithPath:path] setResourceValue:NSURLFileProtectionCompleteUnlessOpen
                                                             forKey:NSURLFileProtectionKey error:&error]) {
        reason = [NSString stringWithFormat:@"changing NSFileProtectionComplete to NSFileProtectionCompleteUnlessOpen "
                  "failed with %@ %ld (%@)", error.domain, (long)error.code, error.localizedDescription];
    }
    [NSFileManager.defaultManager removeItemAtPath:path error:nil];
    return reason;
}

/// If `reason` is set, skips the test (or fails it with BSG_REQUIRE_FILE_PROTECTION_TESTS=1).
#define BSGSkipUnlessFileProtectionComplete(reason, path) \
    if (reason) { \
        [NSFileManager.defaultManager removeItemAtPath:(path) error:nil]; \
        if (BSGFileProtectionTestsAreRequired()) { \
            XCTFail(@"Real protection classes cannot be tested on this host: %@", reason); \
            return; \
        } \
        XCTSkip(@"Real protection classes cannot be tested on this host: %@", reason); \
    }

NS_ASSUME_NONNULL_END
