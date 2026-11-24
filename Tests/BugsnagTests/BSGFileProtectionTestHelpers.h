//
//  BSGFileProtectionTestHelpers.h
//  Bugsnag
//
//  Helpers shared by the tests that set NSFileProtectionComplete on real files (BSGUtilsTests and BSGRunContextTests).
//

#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Real file protection classes

/// Whether the tests that set NSFileProtectionComplete on real files must run rather than be skipped. Set
/// BSG_REQUIRE_FILE_PROTECTION_TESTS=1 (TEST_RUNNER_BSG_REQUIRE_FILE_PROTECTION_TESTS=1 with xcodebuild) on a host
/// whose screen is unlocked, so that those tests fail instead of silently skipping.
static inline BOOL BSGFileProtectionTestsAreRequired(void) {
    return [NSProcessInfo.processInfo.environment[@"BSG_REQUIRE_FILE_PROTECTION_TESTS"] isEqualToString:@"1"];
}

/// Sets NSFileProtectionComplete on a real file, returning nil on success or why it could not be set. On Apple
/// silicon Macs (and so in the simulator) and on devices, class A can only be set while the screen is unlocked;
/// otherwise setting it fails with NSCocoaErrorDomain 513 (EPERM).
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

/// Why this host cannot change a real file from NSFileProtectionComplete to NSFileProtectionCompleteUnlessOpen, or nil
/// if it can. The change is tried on a scratch file holding `contents`, as the file the test uses does. Some macOS
/// versions refuse it with NSCocoaErrorDomain 513 even while the screen is unlocked (seen on macOS 26.7.2), although
/// NSFileProtectionComplete itself can be set. On such a host BSGDisableNSFileProtectionComplete fails in the same way
/// without these changes, so the SDK behaves no differently there; the test is skipped rather than failed.
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

/// Skips the test, or fails it if BSG_REQUIRE_FILE_PROTECTION_TESTS=1, when real protection classes cannot be tested on
/// this host (NSFileProtectionComplete could not be set, or could not be changed; `reason` says which).
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
