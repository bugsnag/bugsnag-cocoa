//
//  BSGRunContextTests.m
//  Bugsnag
//
//  Created by Nick Dowell on 14/07/2022.
//  Copyright © 2022 Bugsnag Inc. All rights reserved.
//

#import "BSGTestCase.h"

#import "BSGFileLocations.h"
#import "BSGRunContext.h"
#import "BSGUtils.h"

#import <fcntl.h>
#import <sys/mman.h>
#import <sys/param.h>
#import <sys/stat.h>
#import <unistd.h>

@interface BSGRunContextTests : BSGTestCase

/// A run context file in a directory of its own, so that tests which map, replace or reopen it don't depend on the
/// SDK's storage folder, which other tests in the same process may delete.
@property (nonatomic) NSString *runContextPath;

@end

@implementation BSGRunContextTests

- (void)setUp {
    [super setUp];
    // bsg_runContext is never NULL: before BSGRunContextInit() is called it points to a zeroed fallback, whose
    // structVersion is not set. It is initialised here when this test case runs on its own; in the full suite
    // an earlier test (e.g. one that starts Bugsnag) may already have done it.
    if (bsg_runContext->structVersion != BSGRUNCONTEXT_VERSION) {
        BSGRunContextInit(BSGFileLocations.current.runContext);
    }
    NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    self.runContextPath = [directory stringByAppendingPathComponent:@"run_context"];
}

- (void)tearDown {
    // Map the SDK's own run context file again, as the other tests in this process expect
    NSString *path = BSGFileLocations.current.runContext;
    [NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent
                            withIntermediateDirectories:YES attributes:nil error:nil];
    BSGRunContextInit(path);
    [NSFileManager.defaultManager removeItemAtPath:self.runContextPath.stringByDeletingLastPathComponent error:nil];
    [super tearDown];
}

- (void)testMemory {
    unsigned long long physicalMemory = NSProcessInfo.processInfo.physicalMemory;
    
    XCTAssertGreaterThan(bsg_runContext->hostMemoryFree, 0);
    XCTAssertLessThan   (bsg_runContext->hostMemoryFree, physicalMemory);
    
    XCTAssertGreaterThan(bsg_runContext->memoryFootprint, 0);
    XCTAssertLessThan   (bsg_runContext->memoryFootprint, physicalMemory);
    
#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
    XCTAssertEqual(bsg_runContext->memoryAvailable, 0);
    XCTAssertEqual(bsg_runContext->memoryLimit, 0);
#else
    if (@available(iOS 13.0, tvOS 13.0, watchOS 6.0, *)) {
#if !TARGET_OS_SIMULATOR
        XCTAssertGreaterThan(bsg_runContext->memoryAvailable, 0);
#else
        XCTAssertEqual(bsg_runContext->memoryAvailable, 0);
#endif
        XCTAssertLessThan   (bsg_runContext->memoryAvailable, physicalMemory);
        
        XCTAssertGreaterThan(bsg_runContext->memoryLimit, 0);
        XCTAssertLessThan   (bsg_runContext->memoryLimit, physicalMemory);
    } else {
        XCTAssertEqual(bsg_runContext->memoryAvailable, 0);
        XCTAssertEqual(bsg_runContext->memoryLimit, 0);
    }
#endif
}

#pragma mark - File descriptor & protection

/// Returns the number of open descriptors in this process that refer to `path`.
static int CountOpenDescriptorsForPath(NSString *path) {
    char resolved[MAXPATHLEN] = {0};
    if (!realpath(path.fileSystemRepresentation, resolved)) {
        return -1;
    }
    int count = 0;
    const int maxFd = getdtablesize();
    for (int fd = 0; fd < maxFd; fd++) {
        char fdPath[MAXPATHLEN] = {0};
        if (fcntl(fd, F_GETPATH, fdPath) != -1 && strcmp(fdPath, resolved) == 0) {
            count++;
        }
    }
    return count;
}

/// The descriptors in this process that refer to `path`, with their open flags, for failure messages.
static NSString * DescribeOpenDescriptorsForPath(NSString *path) {
    char resolved[MAXPATHLEN] = {0};
    if (!realpath(path.fileSystemRepresentation, resolved)) {
        return @"(the path could not be resolved)";
    }
    NSMutableArray<NSString *> *descriptions = [NSMutableArray array];
    const int maxFd = getdtablesize();
    for (int fd = 0; fd < maxFd; fd++) {
        char fdPath[MAXPATHLEN] = {0};
        if (fcntl(fd, F_GETPATH, fdPath) != -1 && strcmp(fdPath, resolved) == 0) {
            [descriptions addObject:[NSString stringWithFormat:@"fd %d (flags 0x%x)", fd, fcntl(fd, F_GETFL)]];
        }
    }
    return [descriptions componentsJoinedByString:@", "];
}

/// Returns the number of open descriptors that refer to `path` once it is `expected`, or after `timeout` seconds if
/// it never is. Something else in the process (e.g. Foundation reading the file's attributes on another thread) can
/// hold a descriptor for the file for a moment; a descriptor that the run context leaked would still be open when the
/// timeout expires.
static int WaitForOpenDescriptorCount(NSString *path, int expected, NSTimeInterval timeout) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    int count = CountOpenDescriptorsForPath(path);
    BOOL logged = NO;
    while (count != expected && deadline.timeIntervalSinceNow > 0) {
        if (!logged) {
            NSLog(@"BSGRunContextTests: %d descriptors for %@ (%@), waiting for %d", count, path.lastPathComponent,
                  DescribeOpenDescriptorsForPath(path), expected);
            logged = YES;
        }
        [NSThread sleepForTimeInterval:0.01];
        count = CountOpenDescriptorsForPath(path);
    }
    return count;
}

- (void)testRunContextFileStaysOpenWhileMapped {
    NSString *path = self.runContextPath;

    BSGRunContextInit(path);
    // The descriptor must stay open so that NSFileProtectionCompleteUnlessOpen
    // keeps the mapped file accessible while the device is locked.
    XCTAssertEqual(WaitForOpenDescriptorCount(path, 1, 10), 1, @"%@", DescribeOpenDescriptorsForPath(path));

    // Writes through the mapping must reach the file.
    bsg_runContext->unhandledCount = 0x5EED;
    XCTAssertEqual(msync(bsg_runContext, sizeof(struct BSGRunContext), MS_SYNC), 0);
    NSData *data = [NSData dataWithContentsOfFile:path];
    XCTAssertEqual(data.length, sizeof(struct BSGRunContext));
    if (data.length < sizeof(struct BSGRunContext)) {
        return;
    }
    XCTAssertEqual(((const struct BSGRunContext *)data.bytes)->unhandledCount, 0x5EEDUL);

    // Reinitialising replaces the descriptor rather than leaking it. The previous descriptor is closed although its
    // mapping is left in place (see ResizeAndMapFile), so code still holding the old address would lose the guarantee
    // that the file stays accessible while the device is locked. Only tests call BSGRunContextInit more than once.
    BSGRunContextInit(path);
    XCTAssertEqual(WaitForOpenDescriptorCount(path, 1, 10), 1, @"%@", DescribeOpenDescriptorsForPath(path));
}

/// Sets O_NONBLOCK on the open file description of each descriptor that refers to the file at `path`, so that a
/// descriptor opened before this was called can be told apart from one opened afterwards (which has its own
/// description, without the flag). Returns the descriptors that were marked.
static NSArray<NSNumber *> * MarkDescriptorsForPath(NSString *path) {
    NSMutableArray<NSNumber *> *marked = [NSMutableArray array];
    struct stat byPath;
    if (lstat(path.fileSystemRepresentation, &byPath) != 0) {
        return marked;
    }
    const int maxFd = getdtablesize();
    for (int fd = 0; fd < maxFd; fd++) {
        struct stat st;
        if (fstat(fd, &st) == 0 && st.st_dev == byPath.st_dev && st.st_ino == byPath.st_ino) {
            fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK);
            [marked addObject:@(fd)];
        }
    }
    return marked;
}

/// The descriptors that refer to `path` and whether each is marked by MarkDescriptorsForPath.
static NSDictionary<NSNumber *, NSNumber *> * DescriptorsForPath(NSString *path) {
    NSMutableDictionary<NSNumber *, NSNumber *> *descriptors = [NSMutableDictionary dictionary];
    struct stat byPath;
    if (lstat(path.fileSystemRepresentation, &byPath) != 0) {
        return descriptors;
    }
    const int maxFd = getdtablesize();
    for (int fd = 0; fd < maxFd; fd++) {
        struct stat st;
        if (fstat(fd, &st) == 0 && st.st_dev == byPath.st_dev && st.st_ino == byPath.st_ino) {
            descriptors[@(fd)] = @((fcntl(fd, F_GETFL) & O_NONBLOCK) != 0);
        }
    }
    return descriptors;
}

// Simulated protection classes (see BSGSetFileProtectionFunctions), so that the run context's handling of
// NSFileProtectionComplete is tested on any host, including a locked or headless one and the simulator
static NSString *gRunContextPath;
static NSString *gRunContextProtection;
static NSMutableArray<NSArray<NSString *> *> *gRunContextSetProtectionCalls;
static BOOL gRunContextSetProtectionFails;
static NSArray<NSNumber *> *gRunContextMarkedDescriptors;
static BSGFileProtectionFunctions gRunContextPreviousFunctions;
// If set, this file is renamed over the run context file when its protection class is first changed
static NSString *gRunContextReplacement;
// If set, the run context file is removed when its protection class is first changed
static BOOL gRunContextRemove;

static NSString *_Nullable RunContextGetProtection(NSString *path) {
    if (![path isEqualToString:gRunContextPath]) {
        return gRunContextPreviousFunctions.getProtection(path);
    }
    // Called after the file has been opened for the first time
    gRunContextMarkedDescriptors = MarkDescriptorsForPath(path);
    return gRunContextProtection;
}

static BOOL RunContextSetProtection(NSString *path, NSString *protection, NSError **error) {
    if (![path isEqualToString:gRunContextPath]) {
        return gRunContextPreviousFunctions.setProtection(path, protection, error);
    }
    [gRunContextSetProtectionCalls addObject:@[path, protection]];
    if (gRunContextReplacement) {
        rename(gRunContextReplacement.fileSystemRepresentation, path.fileSystemRepresentation);
        gRunContextReplacement = nil;
    }
    if (gRunContextRemove) {
        unlink(path.fileSystemRepresentation);
        gRunContextRemove = NO;
    }
    if (gRunContextSetProtectionFails) {
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteNoPermissionError userInfo:nil];
        }
        return NO;
    }
    gRunContextProtection = protection;
    return YES;
}

/// Calls BSGRunContextInit with the run context file's protection class simulated as `protection`.
static void InitRunContextWithSimulatedProtection(NSString *path, NSString *protection, BOOL setProtectionFails) {
    gRunContextPath = path;
    gRunContextProtection = protection;
    gRunContextSetProtectionCalls = [NSMutableArray array];
    gRunContextSetProtectionFails = setProtectionFails;
    gRunContextMarkedDescriptors = nil;
    // Known before the simulated functions are installed, because other threads may call them straight away
    gRunContextPreviousFunctions = BSGSetFileProtectionFunctions((BSGFileProtectionFunctions){0});
    gRunContextPreviousFunctions = BSGSetFileProtectionFunctions((BSGFileProtectionFunctions){
        .getProtection = RunContextGetProtection,
        .setProtection = RunContextSetProtection,
    });
    BSGRunContextInit(path);
    BSGSetFileProtectionFunctions(gRunContextPreviousFunctions);
    gRunContextPath = nil;
}

- (void)testRunContextFileWithCompleteProtectionIsReopenedAfterTheChange {
    NSString *path = self.runContextPath;
    InitRunContextWithSimulatedProtection(path, NSURLFileProtectionComplete, NO);

    XCTAssertEqualObjects(gRunContextSetProtectionCalls, (@[@[path, NSURLFileProtectionCompleteUnlessOpen]]));
    XCTAssertGreaterThan(gRunContextMarkedDescriptors.count, 0, @"The file should have been opened before its class was read");
    // The descriptor kept open while the file is mapped is the one opened after the change; the first one, opened
    // under NSFileProtectionComplete, and the one used before reinitialising, are closed
    // (Waits first, because something else in the process can hold a descriptor for the file for a moment)
    XCTAssertEqual(WaitForOpenDescriptorCount(path, 1, 10), 1, @"%@", DescribeOpenDescriptorsForPath(path));
    NSDictionary *descriptors = DescriptorsForPath(path);
    XCTAssertEqual(descriptors.count, 1);
    XCTAssertEqualObjects(descriptors.allValues.firstObject, @NO, @"The descriptor kept open should have been reopened");

    // The file is mapped through it
    bsg_runContext->unhandledCount = 0xC1A55;
    XCTAssertEqual(msync(bsg_runContext, sizeof(struct BSGRunContext), MS_SYNC), 0);
    NSData *data = [NSData dataWithContentsOfFile:path];
    XCTAssertEqual(data.length, sizeof(struct BSGRunContext));
    if (data.length < sizeof(struct BSGRunContext)) {
        return;
    }
    XCTAssertEqual(((const struct BSGRunContext *)data.bytes)->unhandledCount, 0xC1A55UL);

    BSGRunContextInit(path);
}

- (void)testRunContextFileWithAnotherProtectionClassIsNotReopened {
    NSString *path = self.runContextPath;
    InitRunContextWithSimulatedProtection(path, NSURLFileProtectionCompleteUntilFirstUserAuthentication, NO);

    XCTAssertEqualObjects(gRunContextSetProtectionCalls, @[]);
    XCTAssertEqual(WaitForOpenDescriptorCount(path, 1, 10), 1, @"%@", DescribeOpenDescriptorsForPath(path));
    NSDictionary *descriptors = DescriptorsForPath(path);
    XCTAssertEqual(descriptors.count, 1);
    XCTAssertEqualObjects(descriptors.allValues.firstObject, @YES, @"The first descriptor should have been kept");

    BSGRunContextInit(path);
}

- (void)testRunContextIsNotRemappedIfTheProtectionCannotBeChanged {
    NSString *path = self.runContextPath;
    BSGRunContextInit(path);
    struct BSGRunContext *const mapped = bsg_runContext;
    XCTAssertEqual(WaitForOpenDescriptorCount(path, 1, 10), 1, @"%@", DescribeOpenDescriptorsForPath(path));

    InitRunContextWithSimulatedProtection(path, NSURLFileProtectionComplete, YES);

    XCTAssertEqual(gRunContextSetProtectionCalls.count, 1);
    // A file that would not stay accessible while the device is locked is not mapped; the previous mapping, and its
    // descriptor, are kept, and the descriptor opened for the failed attempt is closed
    XCTAssertEqual(bsg_runContext, mapped);
    XCTAssertEqual(WaitForOpenDescriptorCount(path, 1, 10), 1, @"%@", DescribeOpenDescriptorsForPath(path));
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:path], @"The run context file must not be deleted");

    BSGRunContextInit(path);
}

- (void)testRunContextFileReplacedWhileItIsOpenedIsOpenedAgain {
    NSString *path = self.runContextPath;
    BSGRunContextInit(path);
    NSString *replacement = [path stringByAppendingString:@".replacement"];
    XCTAssertTrue([NSData.data writeToFile:replacement atomically:NO]);
    struct stat replaced;
    XCTAssertEqual(lstat(replacement.fileSystemRepresentation, &replaced), 0);
    // The file is replaced between the two opens, so the descriptor kept open is the one for the file now at the path
    gRunContextReplacement = replacement;
    InitRunContextWithSimulatedProtection(path, NSURLFileProtectionComplete, NO);
    gRunContextReplacement = nil;

    XCTAssertEqual(gRunContextSetProtectionCalls.count, 1);
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:replacement]);
    XCTAssertEqual(WaitForOpenDescriptorCount(path, 1, 10), 1, @"%@", DescribeOpenDescriptorsForPath(path));
    // The file mapped is the one now at the path
    bsg_runContext->unhandledCount = 0xA6A1;
    XCTAssertEqual(msync(bsg_runContext, sizeof(struct BSGRunContext), MS_SYNC), 0);
    struct stat current;
    XCTAssertEqual(lstat(path.fileSystemRepresentation, &current), 0);
    XCTAssertEqual(current.st_ino, replaced.st_ino);
    NSData *data = [NSData dataWithContentsOfFile:path];
    XCTAssertEqual(data.length, sizeof(struct BSGRunContext));
    if (data.length < sizeof(struct BSGRunContext)) {
        return;
    }
    XCTAssertEqual(((const struct BSGRunContext *)data.bytes)->unhandledCount, 0xA6A1UL);

    BSGRunContextInit(path);
}

- (void)testRunContextFileRemovedWhileItIsOpenedIsOpenedAgain {
    NSString *path = self.runContextPath;
    BSGRunContextInit(path);
    struct stat original;
    XCTAssertEqual(lstat(path.fileSystemRepresentation, &original), 0);
    // The file is removed between the two opens of the first attempt, which therefore fails; the second creates it
    // again and succeeds
    gRunContextRemove = YES;
    InitRunContextWithSimulatedProtection(path, NSURLFileProtectionComplete, NO);
    gRunContextRemove = NO;

    XCTAssertEqual(gRunContextSetProtectionCalls.count, 1);
    XCTAssertEqual(WaitForOpenDescriptorCount(path, 1, 10), 1, @"%@", DescribeOpenDescriptorsForPath(path));
    // The file mapped is the one now at the path
    bsg_runContext->unhandledCount = 0xB1E5;
    XCTAssertEqual(msync(bsg_runContext, sizeof(struct BSGRunContext), MS_SYNC), 0);
    struct stat current;
    XCTAssertEqual(lstat(path.fileSystemRepresentation, &current), 0);
    XCTAssertNotEqual(current.st_ino, original.st_ino);
    NSData *data = [NSData dataWithContentsOfFile:path];
    XCTAssertEqual(data.length, sizeof(struct BSGRunContext));
    if (data.length < sizeof(struct BSGRunContext)) {
        return;
    }
    XCTAssertEqual(((const struct BSGRunContext *)data.bytes)->unhandledCount, 0xB1E5UL);

    BSGRunContextInit(path);
}

#pragma mark Real protection classes

/// Whether the tests that set NSFileProtectionComplete on real files must run rather than be skipped. Set
/// BSG_REQUIRE_FILE_PROTECTION_TESTS=1 (TEST_RUNNER_BSG_REQUIRE_FILE_PROTECTION_TESTS=1 with xcodebuild) on a host
/// whose screen is unlocked, so that this test fails instead of silently skipping.
static BOOL FileProtectionTestsAreRequired(void) {
    return [NSProcessInfo.processInfo.environment[@"BSG_REQUIRE_FILE_PROTECTION_TESTS"] isEqualToString:@"1"];
}

/// Why this host cannot change a real (empty) file from NSFileProtectionComplete to NSFileProtectionCompleteUnlessOpen,
/// or nil if it can. Some macOS versions refuse that change with NSCocoaErrorDomain 513 even while the screen is
/// unlocked (seen on macOS 26.7.2), although NSFileProtectionComplete itself can be set. On such a host
/// BSGDisableNSFileProtectionComplete fails in the same way without these changes, so the test is skipped there.
static API_AVAILABLE(macos(11.0)) NSString *_Nullable RealCompleteFileCannotBeChanged(void) {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    if (![NSData.data writeToFile:path atomically:NO]) {
        return @"a scratch file could not be written";
    }
    NSURL *url = [NSURL fileURLWithPath:path];
    NSError *error = nil;
    NSString *reason = nil;
    if (![url setResourceValue:NSURLFileProtectionComplete forKey:NSURLFileProtectionKey error:&error]) {
        reason = [NSString stringWithFormat:@"setting NSFileProtectionComplete failed with %@ %ld (%@); is the screen "
                  "locked?", error.domain, (long)error.code, error.localizedDescription];
    } else if (![url setResourceValue:NSURLFileProtectionCompleteUnlessOpen forKey:NSURLFileProtectionKey error:&error]) {
        reason = [NSString stringWithFormat:@"changing NSFileProtectionComplete to NSFileProtectionCompleteUnlessOpen "
                  "failed with %@ %ld (%@)", error.domain, (long)error.code, error.localizedDescription];
    }
    [NSFileManager.defaultManager removeItemAtPath:path error:nil];
    return reason;
}

- (void)testDisableNSFileProtectionComplete {
#if !TARGET_OS_OSX || defined(__MAC_11_0)
    if (@available(macOS 11.0, *)) {
        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        XCTAssertTrue([NSData.data writeToFile:path atomically:NO]);
        NSURL *url = [NSURL fileURLWithPath:path];

        // On Apple silicon Macs (and so in the simulator) and on devices, NSFileProtectionComplete can only be set
        // while the screen is unlocked; otherwise this fails with NSCocoaErrorDomain 513 (EPERM). The change this test
        // checks is tried first on a scratch file, because some hosts refuse it.
        NSError *error = nil;
        NSURLFileProtectionType protection = nil;
        NSString *reason = RealCompleteFileCannotBeChanged();
        if (!reason &&
            (![url setResourceValue:NSURLFileProtectionComplete forKey:NSURLFileProtectionKey error:&error] ||
             ![url getResourceValue:&protection forKey:NSURLFileProtectionKey error:&error] ||
             ![protection isEqual:NSURLFileProtectionComplete])) {
            reason = [NSString stringWithFormat:@"the file has %@ (%@ %ld: %@); is the screen locked?",
                      protection, error.domain, (long)error.code, error.localizedDescription];
        }
        if (reason) {
            [NSFileManager.defaultManager removeItemAtPath:path error:nil];
            if (FileProtectionTestsAreRequired()) {
                XCTFail(@"Real protection classes cannot be tested on this host: %@", reason);
                return;
            }
            XCTSkip(@"Real protection classes cannot be tested on this host: %@", reason);
        }
        XCTAssertTrue(BSGDisableNSFileProtectionComplete(path));
        protection = nil;
        [url removeCachedResourceValueForKey:NSURLFileProtectionKey];
        XCTAssertTrue([url getResourceValue:&protection forKey:NSURLFileProtectionKey error:nil]);
        XCTAssertEqualObjects(protection, NSURLFileProtectionCompleteUnlessOpen);

        // Other protection classes are left alone.
        XCTAssertTrue([url setResourceValue:NSURLFileProtectionCompleteUntilFirstUserAuthentication
                                     forKey:NSURLFileProtectionKey error:nil]);
        XCTAssertTrue(BSGDisableNSFileProtectionComplete(path));
        protection = nil;
        [url removeCachedResourceValueForKey:NSURLFileProtectionKey];
        XCTAssertTrue([url getResourceValue:&protection forKey:NSURLFileProtectionKey error:nil]);
        XCTAssertEqualObjects(protection, NSURLFileProtectionCompleteUntilFirstUserAuthentication);

        [NSFileManager.defaultManager removeItemAtPath:path error:nil];
        return;
    }
#endif
    XCTSkip(@"NSURLFileProtectionKey is unavailable");
}

@end
