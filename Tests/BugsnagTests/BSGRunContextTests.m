//
//  BSGRunContextTests.m
//  Bugsnag
//
//  Created by Nick Dowell on 14/07/2022.
//  Copyright © 2022 Bugsnag Inc. All rights reserved.
//

#import "BSGTestCase.h"
#import "BSGFileProtectionTestHelpers.h"

#import "BSGFileLocations.h"
#import "BSGRunContext.h"
#import "BSGUtils.h"

#import <fcntl.h>
#import <sys/mman.h>
#import <sys/param.h>
#import <sys/stat.h>
#import <unistd.h>

@interface BSGRunContextTests : BSGTestCase

/// A run context file in its own directory, independent of the SDK's storage folder that other tests may delete.
@property (nonatomic) NSString *runContextPath;

@end

@implementation BSGRunContextTests

- (void)setUp {
    [super setUp];
    // Before BSGRunContextInit() bsg_runContext is a zeroed fallback; an earlier test may already have initialised it
    if (bsg_runContext->structVersion != BSGRUNCONTEXT_VERSION) {
        BSGRunContextInit(BSGFileLocations.current.runContext);
    }
    NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    self.runContextPath = [directory stringByAppendingPathComponent:@"run_context"];
}

- (void)tearDown {
    // Remap the SDK's own run context file for the other tests
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

/// Waits up to `timeout` seconds for `expected` descriptors on `path`, returning the final count. Other code (e.g.
/// Foundation reading attributes) can hold one briefly; a leaked one is still open at the timeout.
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
    // Kept open so NSFileProtectionCompleteUnlessOpen keeps the mapping usable while locked.
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

    // Reinitialising replaces the descriptor without leaking it; the old mapping stays but loses the lock-time
    // guarantee (only tests reinitialise).
    BSGRunContextInit(path);
    XCTAssertEqual(WaitForOpenDescriptorCount(path, 1, 10), 1, @"%@", DescribeOpenDescriptorsForPath(path));
}

#if defined(DEBUG) && DEBUG
// BSGSetFileProtectionFunctions is debug-only, so these tests and their helpers are too.

/// Marks each descriptor for `path` with O_NONBLOCK so it can be told apart from later opens, which get their own
/// file description. Returns the marked descriptors.
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

// Simulated protection classes, so NSFileProtectionComplete handling is tested on any host, locked or headless
static NSString *gRunContextPath;
static NSString *gRunContextProtection;
static NSMutableArray<NSArray<NSString *> *> *gRunContextSetProtectionCalls;
static BOOL gRunContextSetProtectionFails;
static NSArray<NSNumber *> *gRunContextMarkedDescriptors;
static BSGFileProtectionFunctions gRunContextPreviousFunctions;
// If set, renamed over the run context file on the first protection change
static NSString *gRunContextReplacement;
// If set, the run context file is removed on the first protection change
static BOOL gRunContextRemove;

static NSString *_Nullable RunContextGetProtection(NSString *path) {
    if (![path isEqualToString:gRunContextPath]) {
        return gRunContextPreviousFunctions.getProtection(path);
    }
    // Called after the first open
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
    // Called twice: other threads may call the simulated functions (which forward other paths to
    // gRunContextPreviousFunctions) as soon as they are installed, so the defaults must be stored first.
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
    // Only the descriptor opened after the change stays open (waits, as others may hold one briefly)
    XCTAssertEqual(WaitForOpenDescriptorCount(path, 1, 10), 1, @"%@", DescribeOpenDescriptorsForPath(path));
    NSDictionary *descriptors = DescriptorsForPath(path);
    XCTAssertEqual(descriptors.count, 1);
    XCTAssertEqualObjects(descriptors.allValues.firstObject, @NO, @"The descriptor kept open should have been reopened");

    // Mapped through it
    bsg_runContext->unhandledCount = 0xC1A55;
    XCTAssertEqual(msync(bsg_runContext, sizeof(struct BSGRunContext), MS_SYNC), 0);
    NSData *data = [NSData dataWithContentsOfFile:path];
    XCTAssertEqual(data.length, sizeof(struct BSGRunContext));
    if (data.length < sizeof(struct BSGRunContext)) {
        return;
    }
    XCTAssertEqual(((const struct BSGRunContext *)data.bytes)->unhandledCount, 0xC1A55UL);
}

- (void)testRunContextFileWithAnotherProtectionClassIsNotReopened {
    NSString *path = self.runContextPath;
    InitRunContextWithSimulatedProtection(path, NSURLFileProtectionCompleteUntilFirstUserAuthentication, NO);

    XCTAssertEqualObjects(gRunContextSetProtectionCalls, @[]);
    XCTAssertEqual(WaitForOpenDescriptorCount(path, 1, 10), 1, @"%@", DescribeOpenDescriptorsForPath(path));
    NSDictionary *descriptors = DescriptorsForPath(path);
    XCTAssertEqual(descriptors.count, 1);
    XCTAssertEqualObjects(descriptors.allValues.firstObject, @YES, @"The first descriptor should have been kept");
}

- (void)testRunContextIsNotRemappedIfTheProtectionCannotBeChanged {
    NSString *path = self.runContextPath;
    BSGRunContextInit(path);
    struct BSGRunContext *const mapped = bsg_runContext;
    XCTAssertEqual(WaitForOpenDescriptorCount(path, 1, 10), 1, @"%@", DescribeOpenDescriptorsForPath(path));

    InitRunContextWithSimulatedProtection(path, NSURLFileProtectionComplete, YES);

    XCTAssertEqual(gRunContextSetProtectionCalls.count, 1);
    // Not mapped; the previous mapping and descriptor are kept, and the new descriptor is closed
    XCTAssertEqual(bsg_runContext, mapped);
    XCTAssertEqual(WaitForOpenDescriptorCount(path, 1, 10), 1, @"%@", DescribeOpenDescriptorsForPath(path));
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:path], @"The run context file must not be deleted");
}

- (void)testRunContextFileReplacedWhileItIsOpenedIsOpenedAgain {
    NSString *path = self.runContextPath;
    BSGRunContextInit(path);
    NSString *replacement = [path stringByAppendingString:@".replacement"];
    XCTAssertTrue([NSData.data writeToFile:replacement atomically:NO]);
    struct stat replaced;
    XCTAssertEqual(lstat(replacement.fileSystemRepresentation, &replaced), 0);
    // Replaced between the two opens; the retry maps the file now at the path
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
}

- (void)testRunContextFileRemovedWhileItIsOpenedIsOpenedAgain {
    NSString *path = self.runContextPath;
    BSGRunContextInit(path);
    struct stat original;
    XCTAssertEqual(lstat(path.fileSystemRepresentation, &original), 0);
    // Removed between the two opens: the first attempt fails, the retry recreates it
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
}

- (void)testObserversAreAddedOncePerProcess {
    // Each call maps a new file, but observers are added once, so handlers do not multiply
    NSString *path = self.runContextPath;
    BSGRunContextInit(path);
    const unsigned registrations = BSGRunContextObserverRegistrationCount();
    XCTAssertEqual(registrations, 2u, @"The observers and memory pressure source, and the timer, each added once");
    BSGRunContextInit(path);
    BSGRunContextInit(path);
    XCTAssertEqual(BSGRunContextObserverRegistrationCount(), registrations);

#if TARGET_OS_IOS
    // Observed values are still read into each new (zeroed) file
    UIDevice *device = UIDevice.currentDevice;
    XCTAssertEqual(bsg_runContext->batteryLevel, device.batteryLevel);
    XCTAssertEqual(bsg_runContext->batteryState, device.batteryState);
    XCTAssertEqual(bsg_runContext->lastKnownOrientation, device.orientation);
#endif
}

#endif // DEBUG

#pragma mark Real protection classes

- (void)testDisableNSFileProtectionComplete {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    XCTAssertTrue([NSData.data writeToFile:path atomically:NO]);
    NSURL *url = [NSURL fileURLWithPath:path];

    // Needs an unlocked screen; the change is tried on a scratch file first, as some hosts refuse it.
    NSString *reason = BSGRealCompleteFileCannotBeChanged(NSData.data) ?: BSGSetRealFileProtectionComplete(path);
    BSGSkipUnlessFileProtectionComplete(reason, path);
    XCTAssertTrue(BSGDisableNSFileProtectionComplete(path));
    NSURLFileProtectionType protection = nil;
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
}

@end
