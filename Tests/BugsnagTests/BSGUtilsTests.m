//
//  BSGUtilsTests.m
//  Bugsnag
//
//  Created by Nick Dowell on 19/08/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "BSGTestCase.h"

#import "BSGFileProtectionTestHelpers.h"

#import "BSGUtils.h"

#import <fcntl.h>
#import <sys/param.h>
#import <sys/stat.h>
#import <unistd.h>

@interface BSGUtilsTests : BSGTestCase
@end

@implementation BSGUtilsTests

- (void)testPreventInliningConcurrentAccess {
    NSString *tag = @"BSGPreventInlining";
    dispatch_apply(10000,
                   dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0),
                   ^(size_t index) {
        (void)index;
        BSGPreventInlining(tag);
    });
}

- (void)testPreventInliningConcurrentAccessAnotherCheck {
    const NSUInteger workerCount = 16;
    const NSUInteger iterationsPerWorker = 100000;

    dispatch_queue_t queue =
        dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);
    dispatch_group_t group = dispatch_group_create();

    for (NSUInteger worker = 0; worker < workerCount; worker++) {
        dispatch_group_async(group, queue, ^{
            for (NSUInteger iteration = 0;
                 iteration < iterationsPerWorker;
                 iteration++) {
                @autoreleasepool {
                    NSString *value = [NSString stringWithFormat:
                        @"worker-%lu-iteration-%lu",
                        (unsigned long)worker,
                        (unsigned long)iteration];

                    BSGPreventInlining(value);
                }
            }
        });
    }

    XCTAssertEqual(dispatch_group_wait(
        group,
        dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC)),
        0);
}

#if TARGET_OS_IOS

- (void)testBSGStringFromDeviceOrientation {
    XCTAssertEqualObjects(BSGStringFromDeviceOrientation(UIDeviceOrientationPortraitUpsideDown), @"portraitupsidedown");
    XCTAssertEqualObjects(BSGStringFromDeviceOrientation(UIDeviceOrientationPortrait), @"portrait");
    XCTAssertEqualObjects(BSGStringFromDeviceOrientation(UIDeviceOrientationLandscapeRight), @"landscaperight");
    XCTAssertEqualObjects(BSGStringFromDeviceOrientation(UIDeviceOrientationLandscapeLeft), @"landscapeleft");
    XCTAssertEqualObjects(BSGStringFromDeviceOrientation(UIDeviceOrientationFaceUp), @"faceup");
    XCTAssertEqualObjects(BSGStringFromDeviceOrientation(UIDeviceOrientationFaceDown), @"facedown");
    XCTAssertNil(BSGStringFromDeviceOrientation(UIDeviceOrientationUnknown));
    XCTAssertNil(BSGStringFromDeviceOrientation(-1));
    XCTAssertNil(BSGStringFromDeviceOrientation(99));
}

#endif

- (void)testBSGStringFromThermalState {
    XCTAssertEqualObjects(BSGStringFromThermalState(NSProcessInfoThermalStateNominal), @"nominal");
    XCTAssertEqualObjects(BSGStringFromThermalState(NSProcessInfoThermalStateFair), @"fair");
    XCTAssertEqualObjects(BSGStringFromThermalState(NSProcessInfoThermalStateSerious), @"serious");
    XCTAssertEqualObjects(BSGStringFromThermalState(NSProcessInfoThermalStateCritical), @"critical");
    XCTAssertNil(BSGStringFromThermalState((NSProcessInfoThermalState)99));
}

- (void)testCStringWithData {
    char *string = BSGCStringWithData([@"abc" dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertTrue(string != NULL);
    if (string) {
        XCTAssertEqual(strcmp(string, "abc"), 0);
        free(string);
    }
    XCTAssertTrue(BSGCStringWithData(nil) == NULL);
    XCTAssertTrue(BSGCStringWithData(NSData.data) == NULL);
}

- (void)testOpenFileWithoutCompleteProtection {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];

    int fd = BSGOpenFileWithoutCompleteProtection(path, O_RDWR | O_CREAT | O_EXCL);
    XCTAssertNotEqual(fd, -1);
    if (fd == -1) {
        return;
    }
    // Long lived descriptors must not leak into child processes
    XCTAssertTrue(fcntl(fd, F_GETFD) & FD_CLOEXEC);
    struct stat st;
    XCTAssertEqual(fstat(fd, &st), 0);
    XCTAssertEqual(st.st_mode & 0777, 0600);
    // The descriptor is usable for reading and writing
    XCTAssertEqual(pwrite(fd, "abc", 3, 0), 3);
    char buffer[3] = {0};
    XCTAssertEqual(pread(fd, buffer, 3, 0), 3);
    XCTAssertEqual(memcmp(buffer, "abc", 3), 0);
    close(fd);

    // O_EXCL still fails for a file that exists, and the file is left alone
    XCTAssertEqual(BSGOpenFileWithoutCompleteProtection(path, O_RDWR | O_CREAT | O_EXCL), -1);
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:path], [@"abc" dataUsingEncoding:NSUTF8StringEncoding]);

    // An existing file is not truncated when it is reopened
    fd = BSGOpenFileWithoutCompleteProtection(path, O_RDWR | O_CREAT);
    XCTAssertNotEqual(fd, -1);
    if (fd == -1) {
        return;
    }
    XCTAssertEqual(fstat(fd, &st), 0);
    XCTAssertEqual(st.st_size, 3);
    close(fd);

    [NSFileManager.defaultManager removeItemAtPath:path error:nil];
    XCTAssertEqual(BSGOpenFileWithoutCompleteProtection(path, O_RDONLY), -1);
}

- (void)testOpenFileWithoutCompleteProtectionChangesARealCompleteFile {
    // As testCompleteFileIsReopenedAfterItsProtectionIsChanged, with a real protection class
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    NSData *contents = [@"abc" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertTrue([contents writeToFile:path atomically:NO]);
    // Tried first on a scratch file, because some hosts refuse the change
    NSString *reason = BSGRealCompleteFileCannotBeChanged(contents) ?: BSGSetRealFileProtectionComplete(path);
    BSGSkipUnlessFileProtectionComplete(reason, path);

    const int fd = BSGOpenFileWithoutCompleteProtection(path, O_RDWR);
    XCTAssertNotEqual(fd, -1);
    NSURL *url = [NSURL fileURLWithPath:path];
    NSURLFileProtectionType protection = nil;
    XCTAssertTrue([url getResourceValue:&protection forKey:NSURLFileProtectionKey error:nil]);
    XCTAssertEqualObjects(protection, NSURLFileProtectionCompleteUnlessOpen);
    if (fd != -1) {
        struct stat byDescriptor, byPath;
        XCTAssertEqual(fstat(fd, &byDescriptor), 0);
        XCTAssertEqual(lstat(path.fileSystemRepresentation, &byPath), 0);
        XCTAssertEqual(byDescriptor.st_ino, byPath.st_ino);
        char buffer[3] = {0};
        XCTAssertEqual(pread(fd, buffer, 3, 0), 3);
        XCTAssertEqual(memcmp(buffer, "abc", 3), 0);
        close(fd);
    }
    [NSFileManager.defaultManager removeItemAtPath:path error:nil];
}

- (void)testOpenFileWithoutCompleteProtectionFailsIfTheProtectionCannotBeChanged {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    XCTAssertTrue([[@"abc" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:path atomically:NO]);
    NSURL *url = [NSURL fileURLWithPath:path];
    NSString *reason = BSGSetRealFileProtectionComplete(path);
    BSGSkipUnlessFileProtectionComplete(reason, path);
    // An immutable file can be opened for reading, but its protection class cannot be changed
    XCTAssertEqual(chflags(path.fileSystemRepresentation, UF_IMMUTABLE), 0);

    XCTAssertEqual(BSGOpenFileWithoutCompleteProtection(path, O_RDONLY), -1);
    // A file that was not created by the call is not deleted
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:path]);
    NSURLFileProtectionType protection = nil;
    [url removeCachedResourceValueForKey:NSURLFileProtectionKey];
    XCTAssertTrue([url getResourceValue:&protection forKey:NSURLFileProtectionKey error:nil]);
    XCTAssertEqualObjects(protection, NSURLFileProtectionComplete);

    chflags(path.fileSystemRepresentation, 0);
    [NSFileManager.defaultManager removeItemAtPath:path error:nil];
}

@end

#pragma mark - Reopening files whose protection class is changed

// BSGSetFileProtectionFunctions is debug-only, so tests that replace those functions are too.

/// Simulates protection classes (via BSGSetFileProtectionFunctions) so NSFileProtectionComplete handling is tested on
/// any host: locked, headless or simulator.
@interface BSGOpenFileWithoutCompleteProtectionTests : BSGTestCase
@property (nonatomic) NSString *directory;
@end

#if defined(DEBUG) && DEBUG
// Simulated protection class per path; absent paths have none
static NSMutableDictionary<NSString *, NSString *> *gSimulatedProtection;
// The paths and classes passed to SimulatedSetProtection
static NSMutableArray<NSArray<NSString *> *> *gSetProtectionCalls;
// If set, SimulatedSetProtection fails with this error
static NSError *gSetProtectionError;
// Called with the path first by SimulatedGetProtection and SimulatedSetProtection
static void (^gWillGetProtection)(NSString *path);
static void (^gWillSetProtection)(NSString *path);
static BSGFileProtectionFunctions gPreviousProtectionFunctions;
// The simulating test's directory. The functions are global and other threads may call them, so only its files are
// simulated and recorded; other paths go to the real functions.
static NSString *gSimulatedDirectory;

static BOOL IsSimulatedPath(NSString *path) {
    NSString *directory = gSimulatedDirectory;
    return directory && [path hasPrefix:[directory stringByAppendingString:@"/"]];
}

static NSString *_Nullable SimulatedGetProtection(NSString *path) {
    if (!IsSimulatedPath(path)) {
        return gPreviousProtectionFunctions.getProtection(path);
    }
    if (gWillGetProtection) {
        gWillGetProtection(path);
    }
    return gSimulatedProtection[path];
}

static BOOL SimulatedSetProtection(NSString *path, NSString *protection, NSError **error) {
    if (!IsSimulatedPath(path)) {
        return gPreviousProtectionFunctions.setProtection(path, protection, error);
    }
    [gSetProtectionCalls addObject:@[path, protection]];
    if (gWillSetProtection) {
        gWillSetProtection(path);
    }
    if (gSetProtectionError) {
        if (error) {
            *error = gSetProtectionError;
        }
        return NO;
    }
    gSimulatedProtection[path] = protection;
    return YES;
}
#endif

/// The descriptors in this process that refer to the file with this device and inode.
static NSArray<NSNumber *> * DescriptorsForFile(dev_t dev, ino_t ino) {
    NSMutableArray<NSNumber *> *descriptors = [NSMutableArray array];
    const int maxFd = getdtablesize();
    for (int fd = 0; fd < maxFd; fd++) {
        struct stat st;
        if (fstat(fd, &st) == 0 && st.st_dev == dev && st.st_ino == ino) {
            [descriptors addObject:@(fd)];
        }
    }
    return descriptors;
}

/// The paths of the descriptors, for failure messages.
static NSArray<NSString *> * PathsOfDescriptors(NSArray<NSNumber *> *descriptors) {
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    for (NSNumber *fd in descriptors) {
        char path[MAXPATHLEN] = {0};
        [paths addObject:fcntl(fd.intValue, F_GETPATH, path) == 0 ? @(path) : @"?"];
    }
    return paths;
}

/// Sets O_NONBLOCK on every open file description of the file at the path. A later open() gets a new description
/// without it, so this tells the first descriptor from a reopened one.
static void MarkOpenDescriptors(NSString *path) {
    struct stat st;
    if (lstat(path.fileSystemRepresentation, &st) == 0) {
        for (NSNumber *fd in DescriptorsForFile(st.st_dev, st.st_ino)) {
            fcntl(fd.intValue, F_SETFL, fcntl(fd.intValue, F_GETFL) | O_NONBLOCK);
        }
    }
}

static BOOL IsMarked(int fd) {
    return (fcntl(fd, F_GETFL) & O_NONBLOCK) != 0;
}

@implementation BSGOpenFileWithoutCompleteProtectionTests

- (void)setUp {
    [super setUp];
    self.directory = [NSTemporaryDirectory() stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"BSGOpenFileWithoutCompleteProtectionTests-%@", NSUUID.UUID.UUIDString]];
    [NSFileManager.defaultManager createDirectoryAtPath:self.directory withIntermediateDirectories:YES attributes:nil error:nil];
}

- (void)tearDown {
#if defined(DEBUG) && DEBUG
    [self stopSimulatingProtection];
#endif
    [NSFileManager.defaultManager removeItemAtPath:self.directory error:nil];
    [super tearDown];
}

#if defined(DEBUG) && DEBUG
- (void)simulateProtection {
    gSimulatedDirectory = self.directory;
    gSimulatedProtection = [NSMutableDictionary dictionary];
    gSetProtectionCalls = [NSMutableArray array];
    gSetProtectionError = nil;
    gWillGetProtection = nil;
    gWillSetProtection = nil;
    // Set before installing the simulated functions, which other threads may call at once
    gPreviousProtectionFunctions = BSGSetFileProtectionFunctions((BSGFileProtectionFunctions){0});
    gPreviousProtectionFunctions = BSGSetFileProtectionFunctions((BSGFileProtectionFunctions){
        .getProtection = SimulatedGetProtection,
        .setProtection = SimulatedSetProtection,
    });
}

- (void)stopSimulatingProtection {
    if (gSimulatedProtection) {
        BSGSetFileProtectionFunctions(gPreviousProtectionFunctions);
    }
    gSimulatedDirectory = nil;
    gSimulatedProtection = nil;
    gSetProtectionCalls = nil;
    gSetProtectionError = nil;
    gWillGetProtection = nil;
    gWillSetProtection = nil;
}
#endif

#pragma mark Simulated protection classes

#if defined(DEBUG) && DEBUG
- (void)testOnlyCompleteIsChanged {
    [self simulateProtection];
    NSString *path = [self.directory stringByAppendingPathComponent:@"file"];

    gSimulatedProtection[path] = NSURLFileProtectionComplete;
    BOOL changed = NO;
    XCTAssertTrue(BSGChangeNSFileProtectionComplete(path, &changed));
    XCTAssertTrue(changed);
    XCTAssertEqualObjects(gSetProtectionCalls, (@[@[path, NSURLFileProtectionCompleteUnlessOpen]]));
    XCTAssertEqualObjects(gSimulatedProtection[path], NSURLFileProtectionCompleteUnlessOpen);

    // Once changed, it is not changed again
    XCTAssertTrue(BSGChangeNSFileProtectionComplete(path, &changed));
    XCTAssertFalse(changed);
    XCTAssertEqual(gSetProtectionCalls.count, 1);

    // Other classes, and no class, are left alone
    for (NSString *protection in @[NSURLFileProtectionNone, NSURLFileProtectionCompleteUntilFirstUserAuthentication]) {
        gSimulatedProtection[path] = protection;
        changed = YES;
        XCTAssertTrue(BSGChangeNSFileProtectionComplete(path, &changed));
        XCTAssertFalse(changed);
        XCTAssertEqualObjects(gSimulatedProtection[path], protection);
    }
    [gSimulatedProtection removeObjectForKey:path];
    changed = YES;
    XCTAssertTrue(BSGChangeNSFileProtectionComplete(path, &changed));
    XCTAssertFalse(changed);
    XCTAssertTrue(BSGDisableNSFileProtectionComplete(path));
    XCTAssertEqual(gSetProtectionCalls.count, 1);

    // A failure to change it is reported, and changed is NO
    gSimulatedProtection[path] = NSURLFileProtectionComplete;
    gSetProtectionError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteNoPermissionError userInfo:nil];
    changed = YES;
    XCTAssertFalse(BSGChangeNSFileProtectionComplete(path, &changed));
    XCTAssertFalse(changed);
    XCTAssertFalse(BSGDisableNSFileProtectionComplete(path));
    XCTAssertEqualObjects(gSimulatedProtection[path], NSURLFileProtectionComplete);
}

- (void)testOpenFileReportsWhyTheProtectionCouldNotBeChanged {
    [self simulateProtection];
    NSString *path = [self.directory stringByAppendingPathComponent:@"file"];
    XCTAssertTrue([[@"abc" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:path atomically:NO]);
    gSimulatedProtection[path] = NSURLFileProtectionComplete;

    // The POSIX error is passed on, so it isn't mistaken for a locked device (EPERM)
    NSError *posixError = [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOSPC userInfo:nil];
    gSetProtectionError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteOutOfSpaceError
                                          userInfo:@{NSUnderlyingErrorKey: posixError}];
    errno = 0;
    XCTAssertEqual(BSGOpenFileWithoutCompleteProtection(path, O_RDWR), -1);
    XCTAssertEqual(errno, ENOSPC);

    // Without one, the failure is reported as EPERM
    gSetProtectionError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteNoPermissionError userInfo:nil];
    errno = 0;
    XCTAssertEqual(BSGOpenFileWithoutCompleteProtection(path, O_RDWR), -1);
    XCTAssertEqual(errno, EPERM);
    XCTAssertEqualObjects(gSimulatedProtection[path], NSURLFileProtectionComplete);
}

- (void)testCompleteFileIsReopenedAfterItsProtectionIsChanged {
    [self simulateProtection];
    NSString *path = [self.directory stringByAppendingPathComponent:@"file"];
    XCTAssertTrue([[@"abc" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:path atomically:NO]);
    gSimulatedProtection[path] = NSURLFileProtectionComplete;
    // The descriptor opened before the change is marked
    gWillGetProtection = ^(NSString *p) { MarkOpenDescriptors(p); };

    const int fd = BSGOpenFileWithoutCompleteProtection(path, O_RDWR);
    XCTAssertNotEqual(fd, -1);
    if (fd == -1) {
        return;
    }
    XCTAssertEqualObjects(gSetProtectionCalls, (@[@[path, NSURLFileProtectionCompleteUnlessOpen]]));
    XCTAssertFalse(IsMarked(fd), @"The descriptor returned should have been opened after the change");
    XCTAssertTrue(fcntl(fd, F_GETFD) & FD_CLOEXEC);
    struct stat byDescriptor, byPath;
    XCTAssertEqual(fstat(fd, &byDescriptor), 0);
    XCTAssertEqual(lstat(path.fileSystemRepresentation, &byPath), 0);
    XCTAssertEqual(byDescriptor.st_dev, byPath.st_dev);
    XCTAssertEqual(byDescriptor.st_ino, byPath.st_ino);
    XCTAssertEqualObjects(DescriptorsForFile(byPath.st_dev, byPath.st_ino), @[@(fd)], @"The first descriptor should be closed");
    // Same access mode, and not truncated
    char buffer[3] = {0};
    XCTAssertEqual(pread(fd, buffer, 3, 0), 3);
    XCTAssertEqual(memcmp(buffer, "abc", 3), 0);
    XCTAssertEqual(pwrite(fd, "xyz", 3, 0), 3);
    close(fd);
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:path], [@"xyz" dataUsingEncoding:NSUTF8StringEncoding]);

    // Likewise for a file created in a directory whose files get NSFileProtectionComplete
    NSString *created = [self.directory stringByAppendingPathComponent:@"created"];
    gSimulatedProtection[created] = NSURLFileProtectionComplete;
    const int createdFd = BSGOpenFileWithoutCompleteProtection(created, O_RDWR | O_CREAT | O_EXCL);
    XCTAssertNotEqual(createdFd, -1);
    if (createdFd != -1) {
        XCTAssertFalse(IsMarked(createdFd));
        XCTAssertEqual(fstat(createdFd, &byDescriptor), 0);
        XCTAssertEqual(byDescriptor.st_mode & 0777, 0600);
        XCTAssertEqualObjects(DescriptorsForFile(byDescriptor.st_dev, byDescriptor.st_ino), @[@(createdFd)]);
        close(createdFd);
    }
    XCTAssertEqualObjects(gSimulatedProtection[created], NSURLFileProtectionCompleteUnlessOpen);
}

- (void)testFileWithAnotherProtectionClassIsNotReopened {
    [self simulateProtection];
    gWillGetProtection = ^(NSString *p) { MarkOpenDescriptors(p); };
    NSString *path = [self.directory stringByAppendingPathComponent:@"file"];
    XCTAssertTrue([NSData.data writeToFile:path atomically:NO]);
    for (NSString *protection in @[NSURLFileProtectionCompleteUntilFirstUserAuthentication,
                                   NSURLFileProtectionCompleteUnlessOpen, NSURLFileProtectionNone, @""]) {
        gSimulatedProtection[path] = protection.length ? protection : nil;
        const int fd = BSGOpenFileWithoutCompleteProtection(path, O_RDWR);
        XCTAssertNotEqual(fd, -1);
        if (fd != -1) {
            XCTAssertTrue(IsMarked(fd), @"The first descriptor should be returned for %@", protection);
            close(fd);
        }
    }
    XCTAssertEqualObjects(gSetProtectionCalls, @[]);
}

- (void)testFailureToChangeTheProtectionClass {
    [self simulateProtection];
    gSetProtectionError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteNoPermissionError userInfo:nil];
    __block struct stat opened = {0};
    // Other code may read protection classes meanwhile, so only this test's files are recorded
    NSString *directory = self.directory;
    gWillGetProtection = ^(NSString *p) {
        if ([p hasPrefix:directory]) {
            lstat(p.fileSystemRepresentation, &opened);
        }
    };

    // A file created by the call is deleted, and its descriptor closed
    NSString *created = [self.directory stringByAppendingPathComponent:@"created"];
    gSimulatedProtection[created] = NSURLFileProtectionComplete;
    XCTAssertEqual(BSGOpenFileWithoutCompleteProtection(created, O_RDWR | O_CREAT | O_EXCL), -1);
    XCTAssertEqual(gSetProtectionCalls.count, 1);
    XCTAssertNotEqual(opened.st_ino, 0);
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:created]);
    NSArray<NSNumber *> *leftOpen = DescriptorsForFile(opened.st_dev, opened.st_ino);
    XCTAssertEqualObjects(leftOpen, @[], @"%@", PathsOfDescriptors(leftOpen));

    // An existing file is left as it was, and its descriptor closed
    NSString *existing = [self.directory stringByAppendingPathComponent:@"existing"];
    XCTAssertTrue([[@"abc" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:existing atomically:NO]);
    gSimulatedProtection[existing] = NSURLFileProtectionComplete;
    for (NSNumber *flags in @[@(O_RDONLY), @(O_RDWR), @(O_RDWR | O_CREAT)]) {
        opened = (struct stat){0};
        XCTAssertEqual(BSGOpenFileWithoutCompleteProtection(existing, flags.intValue), -1);
        XCTAssertNotEqual(opened.st_ino, 0);
        leftOpen = DescriptorsForFile(opened.st_dev, opened.st_ino);
        XCTAssertEqualObjects(leftOpen, @[], @"%@", PathsOfDescriptors(leftOpen));
    }
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:existing], [@"abc" dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertEqualObjects(gSimulatedProtection[existing], NSURLFileProtectionComplete);
}

- (void)testFileThatCannotBeReopenedIsNotUsed {
    [self simulateProtection];
    NSString *path = [self.directory stringByAppendingPathComponent:@"file"];
    gSimulatedProtection[path] = NSURLFileProtectionComplete;

    // The first descriptor's exclusive lock makes the O_EXLOCK | O_NONBLOCK reopen fail (EWOULDBLOCK). It is closed,
    // not returned: opened under NSFileProtectionComplete, a mapping could fault once locked
    errno = 0;
    XCTAssertEqual(BSGOpenFileWithoutCompleteProtection(path, O_RDWR | O_CREAT | O_EXCL | O_EXLOCK | O_NONBLOCK), -1);
    XCTAssertEqual(errno, EWOULDBLOCK, @"The reopen's error should be returned");
    XCTAssertEqualObjects(gSetProtectionCalls, (@[@[path, NSURLFileProtectionCompleteUnlessOpen]]),
                          @"The class must have been changed, so that the file was reopened");
    // Created by the call (O_EXCL), so deleted, with nothing left open
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:path]);
}
#endif

#pragma mark Real files

#if defined(DEBUG) && DEBUG
/// The lowest free descriptor number, which open() returns next.
- (void)testFileRemovedBeforeItIsReopenedCanBeOpenedAgain {
    [self simulateProtection];
    NSString *path = [self.directory stringByAppendingPathComponent:@"file"];
    XCTAssertTrue([[@"original" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:path atomically:NO]);
    struct stat original;
    XCTAssertEqual(lstat(path.fileSystemRepresentation, &original), 0);
    gSimulatedProtection[path] = NSURLFileProtectionComplete;
    // The file is removed between the two opens
    gWillSetProtection = ^(NSString *p) {
        unlink(p.fileSystemRepresentation);
    };

    errno = 0;
    XCTAssertEqual(BSGOpenFileWithoutCompleteProtection(path, O_RDWR), -1);
    XCTAssertEqual(errno, EAGAIN, @"The caller can tell that the file was removed, and try again");
    XCTAssertEqual(gSetProtectionCalls.count, 1);
    XCTAssertEqualObjects(DescriptorsForFile(original.st_dev, original.st_ino), @[], @"The first descriptor should be closed");

    // Opening it again (as the caller does) creates the file at the path
    gWillSetProtection = nil;
    const int fd = BSGOpenFileWithoutCompleteProtection(path, O_RDWR | O_CREAT);
    XCTAssertNotEqual(fd, -1);
    if (fd != -1) {
        struct stat byDescriptor, byPath;
        XCTAssertEqual(fstat(fd, &byDescriptor), 0);
        XCTAssertEqual(lstat(path.fileSystemRepresentation, &byPath), 0);
        XCTAssertEqual(byDescriptor.st_ino, byPath.st_ino);
        close(fd);
    }
}

- (void)testFileReplacedBeforeItIsReopenedCanBeOpenedAgain {
    [self simulateProtection];
    NSString *path = [self.directory stringByAppendingPathComponent:@"file"];
    NSString *other = [self.directory stringByAppendingPathComponent:@"other"];
    XCTAssertTrue([[@"original" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:path atomically:NO]);
    XCTAssertTrue([[@"replacement" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:other atomically:NO]);
    struct stat original, replacement;
    XCTAssertEqual(lstat(path.fileSystemRepresentation, &original), 0);
    XCTAssertEqual(lstat(other.fileSystemRepresentation, &replacement), 0);
    gSimulatedProtection[path] = NSURLFileProtectionComplete;
    // Another file is renamed over the path between the opens, so the reopened one's class was never checked
    gWillSetProtection = ^(NSString *p) {
        rename(other.fileSystemRepresentation, p.fileSystemRepresentation);
    };

    errno = 0;
    XCTAssertEqual(BSGOpenFileWithoutCompleteProtection(path, O_RDWR), -1);
    XCTAssertEqual(errno, EAGAIN, @"The caller can tell that the file at the path changed, and try again");
    XCTAssertEqual(gSetProtectionCalls.count, 1);
    XCTAssertEqualObjects(DescriptorsForFile(original.st_dev, original.st_ino), @[], @"The first descriptor should be closed");
    XCTAssertEqualObjects(DescriptorsForFile(replacement.st_dev, replacement.st_ino), @[], @"The reopened descriptor should be closed");

    // Opening again (as the caller does) opens the new file and checks its class
    gWillSetProtection = nil;
    gSimulatedProtection[path] = NSURLFileProtectionComplete;
    const int fd = BSGOpenFileWithoutCompleteProtection(path, O_RDWR);
    XCTAssertNotEqual(fd, -1);
    if (fd != -1) {
        struct stat byDescriptor;
        XCTAssertEqual(fstat(fd, &byDescriptor), 0);
        XCTAssertEqual(byDescriptor.st_ino, replacement.st_ino);
        XCTAssertEqualObjects(gSimulatedProtection[path], NSURLFileProtectionCompleteUnlessOpen);
        close(fd);
    }
}
#endif

static int BSGLowestFreeDescriptor(void) {
    int fd = dup(STDIN_FILENO);
    if (fd != -1) {
        close(fd);
    }
    return fd;
}

- (void)testFileIsNotReopenedWhenTheProtectionClassIsNotChanged {
    NSString *path = [self.directory stringByAppendingPathComponent:@"file"];
    XCTAssertTrue([NSData.data writeToFile:path atomically:NO]);
    BOOL changed = YES;
    XCTAssertTrue(BSGChangeNSFileProtectionComplete(path, &changed));
    XCTAssertFalse(changed, @"A file that does not have NSFileProtectionComplete is not changed");

    // A reopen opens a second descriptor before closing the first, so it isn't the lowest free one. Tried a few times,
    // as other threads open descriptors too.
    BOOL reopened = YES;
    for (int attempt = 0; attempt < 5 && reopened; attempt++) {
        const int expected = BSGLowestFreeDescriptor();
        const int fd = BSGOpenFileWithoutCompleteProtection(path, O_RDWR);
        XCTAssertNotEqual(fd, -1);
        if (fd == -1) {
            return;
        }
        reopened = fd != expected;
        close(fd);
    }
    XCTAssertFalse(reopened, @"The file should not have been reopened");

    // Likewise for a file created by the call
    NSString *created = [self.directory stringByAppendingPathComponent:@"created"];
    reopened = YES;
    for (int attempt = 0; attempt < 5 && reopened; attempt++) {
        unlink(created.fileSystemRepresentation);
        const int expected = BSGLowestFreeDescriptor();
        const int fd = BSGOpenFileWithoutCompleteProtection(created, O_RDWR | O_CREAT | O_EXCL);
        XCTAssertNotEqual(fd, -1);
        if (fd == -1) {
            return;
        }
        reopened = fd != expected;
        close(fd);
    }
    XCTAssertFalse(reopened, @"A created file should not have been reopened");
}

- (void)testDescriptorRefersToTheFileAtThePath {
    NSString *path = [self.directory stringByAppendingPathComponent:@"file"];
    const int fd = BSGOpenFileWithoutCompleteProtection(path, O_RDWR | O_CREAT);
    XCTAssertNotEqual(fd, -1);
    if (fd == -1) {
        return;
    }
    struct stat byDescriptor, byPath;
    XCTAssertEqual(fstat(fd, &byDescriptor), 0);
    XCTAssertEqual(lstat(path.fileSystemRepresentation, &byPath), 0);
    XCTAssertEqual(byDescriptor.st_dev, byPath.st_dev);
    XCTAssertEqual(byDescriptor.st_ino, byPath.st_ino);
    close(fd);
}

#pragma mark Creating files

// The error that FailingCreateFile fails with
#if defined(DEBUG) && DEBUG
static int gCreateFileErrno;

static BOOL FailingCreateFile(__unused NSString *path) {
    errno = gCreateFileErrno;
    return NO;
}
#endif

- (void)testCreateFileWithoutCompleteProtection {
    NSString *path = [self.directory stringByAppendingPathComponent:@"created"];
    int fd = BSGCreateFileWithoutCompleteProtection(path, O_RDWR);
    XCTAssertNotEqual(fd, -1);
    if (fd == -1) {
        return;
    }
    XCTAssertTrue(fcntl(fd, F_GETFD) & FD_CLOEXEC);
    struct stat byDescriptor, byPath;
    XCTAssertEqual(fstat(fd, &byDescriptor), 0);
    XCTAssertEqual(lstat(path.fileSystemRepresentation, &byPath), 0);
    XCTAssertEqual(byDescriptor.st_ino, byPath.st_ino);
    XCTAssertTrue(S_ISREG(byDescriptor.st_mode));
    XCTAssertEqual(byDescriptor.st_mode & 0777, 0600);
    XCTAssertEqual(byDescriptor.st_size, 0);
    XCTAssertEqual(pwrite(fd, "abc", 3, 0), 3);
    char buffer[3] = {0};
    XCTAssertEqual(pread(fd, buffer, 3, 0), 3);
    XCTAssertEqual(memcmp(buffer, "abc", 3), 0);
    close(fd);
#if TARGET_OS_IPHONE && !TARGET_OS_MACCATALYST && !TARGET_OS_SIMULATOR
    // The class is chosen at creation: NSFileProtectionCompleteUnlessOpen in a Complete directory, else the inherited
    // class, never Complete. (The simulator ignores requested classes and uses
    // NSFileProtectionCompleteUntilFirstUserAuthentication; the simulated tests below cover it.)
    NSURLFileProtectionType protection = nil;
    [[NSURL fileURLWithPath:path] getResourceValue:&protection forKey:NSURLFileProtectionKey error:nil];
    if (protection) {
        XCTAssertNotEqualObjects(protection, NSURLFileProtectionComplete);
        if (BSGProtectionClassForNewFileInDirectory(self.directory)) {
            XCTAssertEqualObjects(protection, NSURLFileProtectionCompleteUnlessOpen);
        }
    }
#endif

    // A file that exists is neither opened nor changed
    errno = 0;
    XCTAssertEqual(BSGCreateFileWithoutCompleteProtection(path, O_RDWR), -1);
    XCTAssertEqual(errno, EEXIST);
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:path], [@"abc" dataUsingEncoding:NSUTF8StringEncoding]);
}

- (void)testCreateFileRefusesSymbolicLinks {
    NSString *target = [self.directory stringByAppendingPathComponent:@"target"];
    NSString *link = [self.directory stringByAppendingPathComponent:@"link"];
    XCTAssertTrue([[@"target" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:target atomically:NO]);
    XCTAssertEqual(symlink(target.fileSystemRepresentation, link.fileSystemRepresentation), 0);
    XCTAssertEqual(BSGCreateFileWithoutCompleteProtection(link, O_RDWR), -1);
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:target], [@"target" dataUsingEncoding:NSUTF8StringEncoding]);

    // A dangling link is not followed to create a file elsewhere
    NSString *missing = [self.directory stringByAppendingPathComponent:@"missing"];
    NSString *danglingLink = [self.directory stringByAppendingPathComponent:@"dangling"];
    XCTAssertEqual(symlink(missing.fileSystemRepresentation, danglingLink.fileSystemRepresentation), 0);
    XCTAssertEqual(BSGCreateFileWithoutCompleteProtection(danglingLink, O_RDWR), -1);
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:missing]);
}

#if defined(DEBUG) && DEBUG
- (void)testCreateFileFailsWhenTheFileCannotBeCreated {
    // A locked device, where the file would have NSFileProtectionComplete
    gCreateFileErrno = EPERM;
    const BSGFileProtectionFunctions previous = BSGSetFileProtectionFunctions((BSGFileProtectionFunctions){
        .createFile = FailingCreateFile,
    });
    NSString *path = [self.directory stringByAppendingPathComponent:@"created"];
    errno = 0;
    const int fd = BSGCreateFileWithoutCompleteProtection(path, O_RDWR);
    const int error = errno;
    BSGSetFileProtectionFunctions(previous);
    XCTAssertEqual(fd, -1);
    XCTAssertEqual(error, EPERM);
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:path]);
}

- (void)testCreatedFileWithCompleteProtectionIsChanged {
    // If the class couldn't be set at creation (e.g. macOS), Complete is changed as for any file
    [self simulateProtection];
    NSString *path = [self.directory stringByAppendingPathComponent:@"created"];
    gSimulatedProtection[path] = NSURLFileProtectionComplete;
    const int fd = BSGCreateFileWithoutCompleteProtection(path, O_RDWR);
    XCTAssertNotEqual(fd, -1);
    XCTAssertEqualObjects(gSetProtectionCalls, (@[@[path, NSURLFileProtectionCompleteUnlessOpen]]));
    if (fd != -1) {
        struct stat byDescriptor, byPath;
        XCTAssertEqual(fstat(fd, &byDescriptor), 0);
        XCTAssertEqual(lstat(path.fileSystemRepresentation, &byPath), 0);
        XCTAssertEqual(byDescriptor.st_ino, byPath.st_ino);
        XCTAssertEqual(byDescriptor.st_mode & 0777, 0600);
        close(fd);
    }

    // If the class can't be changed, the created file is deleted
    NSString *other = [self.directory stringByAppendingPathComponent:@"other"];
    gSimulatedProtection[other] = NSURLFileProtectionComplete;
    gSetProtectionError = [NSError errorWithDomain:NSPOSIXErrorDomain code:EPERM userInfo:nil];
    XCTAssertEqual(BSGCreateFileWithoutCompleteProtection(other, O_RDWR), -1);
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:other]);
}

- (void)testCreatedFileRemovedBeforeItIsReopenedCanBeCreatedAgain {
    [self simulateProtection];
    NSString *path = [self.directory stringByAppendingPathComponent:@"created"];
    gSimulatedProtection[path] = NSURLFileProtectionComplete;
    // The file is removed between the two opens
    __block struct stat created = {0};
    gWillSetProtection = ^(NSString *p) {
        lstat(p.fileSystemRepresentation, &created);
        unlink(p.fileSystemRepresentation);
    };
    errno = 0;
    XCTAssertEqual(BSGCreateFileWithoutCompleteProtection(path, O_RDWR), -1);
    XCTAssertEqual(errno, EAGAIN, @"The caller can tell that the file was removed, and try again");
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:path]);
    XCTAssertNotEqual(created.st_ino, 0);
    XCTAssertEqualObjects(DescriptorsForFile(created.st_dev, created.st_ino), @[], @"The first descriptor should be closed");

    gWillSetProtection = nil;
    const int fd = BSGCreateFileWithoutCompleteProtection(path, O_RDWR);
    XCTAssertNotEqual(fd, -1);
    if (fd != -1) {
        close(fd);
    }
}
#endif

- (void)testOpenFileWithoutFollowingLinks {
    NSString *path = [self.directory stringByAppendingPathComponent:@"file"];
    const int fd = BSGOpenFileWithoutFollowingLinks(path, O_RDWR | O_CREAT);
    XCTAssertNotEqual(fd, -1);
    if (fd == -1) {
        return;
    }
    XCTAssertTrue(fcntl(fd, F_GETFD) & FD_CLOEXEC);
    struct stat st;
    XCTAssertEqual(fstat(fd, &st), 0);
    XCTAssertEqual(st.st_mode & 0777, 0600);
    close(fd);

    // A symlink at the path is refused, dangling or not
    NSString *link = [self.directory stringByAppendingPathComponent:@"link"];
    XCTAssertEqual(symlink(path.fileSystemRepresentation, link.fileSystemRepresentation), 0);
    for (NSNumber *flags in @[@(O_RDONLY), @(O_RDWR), @(O_RDWR | O_CREAT)]) {
        errno = 0;
        XCTAssertEqual(BSGOpenFileWithoutFollowingLinks(link, flags.intValue), -1);
        XCTAssertEqual(errno, ELOOP);
    }
}

#pragma mark Protection class of new files

#if defined(DEBUG) && DEBUG
/// A subdirectory of the test's directory, so its simulated class applies.
- (NSString *)subdirectoryWithSimulatedProtection:(nullable NSString *)protection {
    NSString *subdirectory = [self.directory stringByAppendingPathComponent:@"subdirectory"];
    [NSFileManager.defaultManager createDirectoryAtPath:subdirectory withIntermediateDirectories:YES attributes:nil error:nil];
    gSimulatedProtection[subdirectory] = protection;
    return subdirectory;
}

- (void)testNewFileInACompleteDirectoryIsCreatedWithCompleteUnlessOpen {
    // An app whose default class is NSFileProtectionComplete: the file must not get Complete, even briefly
    [self simulateProtection];
    NSString *directory = [self subdirectoryWithSimulatedProtection:NSURLFileProtectionComplete];
    XCTAssertEqualObjects(BSGProtectionClassForNewFileInDirectory(directory), NSURLFileProtectionCompleteUnlessOpen);

    NSMutableArray<NSString *> *read = [NSMutableArray array];
    gWillGetProtection = ^(NSString *p) { [read addObject:p]; };
    NSString *path = [directory stringByAppendingPathComponent:@"created"];
    const int fd = BSGCreateFileWithoutCompleteProtection(path, O_RDWR);
    XCTAssertNotEqual(fd, -1);
    if (fd != -1) {
        close(fd);
    }
#if TARGET_OS_IPHONE && !TARGET_OS_MACCATALYST
    // The class comes from the directory's at creation
    XCTAssertTrue([read containsObject:directory], @"%@", read);
#endif
}

- (void)testNewFileInAnotherDirectoryKeepsTheInheritedClass {
    // Any class but Complete is kept: CompleteUnlessOpen is stricter than CompleteUntilFirstUserAuthentication, as a
    // closed file couldn't be reopened while locked (e.g. by a background launch)
    [self simulateProtection];
    for (NSString *protection in @[NSURLFileProtectionCompleteUntilFirstUserAuthentication,
                                   NSURLFileProtectionCompleteUnlessOpen, NSURLFileProtectionNone, @""]) {
        NSString *directory = [self subdirectoryWithSimulatedProtection:protection.length ? protection : nil];
        XCTAssertNil(BSGProtectionClassForNewFileInDirectory(directory), @"%@", protection);

        NSString *path = [directory stringByAppendingPathComponent:@"created"];
        unlink(path.fileSystemRepresentation);
        const int fd = BSGCreateFileWithoutCompleteProtection(path, O_RDWR);
        XCTAssertNotEqual(fd, -1, @"%@", protection);
        if (fd != -1) {
            close(fd);
        }
    }
    XCTAssertEqualObjects(gSetProtectionCalls, @[], @"No class should be set on a file that does not have Complete");
}
#endif

- (void)testSymbolicLinkAtThePathIsRefused {
    NSString *target = [self.directory stringByAppendingPathComponent:@"target"];
    NSString *link = [self.directory stringByAppendingPathComponent:@"link"];
    XCTAssertTrue([[@"target" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:target atomically:NO]);
    XCTAssertEqual(symlink(target.fileSystemRepresentation, link.fileSystemRepresentation), 0);

    for (NSNumber *flags in @[@(O_RDONLY), @(O_RDWR), @(O_RDWR | O_CREAT)]) {
        errno = 0;
        XCTAssertEqual(BSGOpenFileWithoutCompleteProtection(link, flags.intValue), -1);
        XCTAssertEqual(errno, ELOOP);
    }
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:target], [@"target" dataUsingEncoding:NSUTF8StringEncoding]);

    // A dangling link is not followed to create a file elsewhere
    NSString *missing = [self.directory stringByAppendingPathComponent:@"missing"];
    NSString *danglingLink = [self.directory stringByAppendingPathComponent:@"dangling"];
    XCTAssertEqual(symlink(missing.fileSystemRepresentation, danglingLink.fileSystemRepresentation), 0);
    XCTAssertEqual(BSGOpenFileWithoutCompleteProtection(danglingLink, O_RDWR | O_CREAT), -1);
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:missing]);
}

#if defined(DEBUG) && DEBUG
- (void)testDefaultProtectionFunctionsReadAndChangeARealFile {
    // Checks the replaced functions against a real file. Unlike Complete, CompleteUntilFirstUserAuthentication and
    // CompleteUnlessOpen can be set while locked, so this runs on locked or headless hosts; reading Complete is left to
    // the real-file tests.
    // Passing no functions keeps the defaults and returns them
    const BSGFileProtectionFunctions defaults = BSGSetFileProtectionFunctions((BSGFileProtectionFunctions){0});
    XCTAssertTrue(defaults.getProtection != NULL && defaults.setProtection != NULL);
    if (!defaults.getProtection || !defaults.setProtection) {
        return;
    }
    NSString *path = [self.directory stringByAppendingPathComponent:@"file"];
    XCTAssertTrue([[@"abc" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:path atomically:NO]);
    NSURL *url = [NSURL fileURLWithPath:path];
    NSError *error = nil;
    if (![url setResourceValue:NSURLFileProtectionCompleteUntilFirstUserAuthentication
                        forKey:NSURLFileProtectionKey error:&error] ||
        ![defaults.getProtection(path) isEqual:NSURLFileProtectionCompleteUntilFirstUserAuthentication]) {
        NSString *reason = [NSString stringWithFormat:@"the file has %@ (%@ %ld)", defaults.getProtection(path),
                            error.domain, (long)error.code];
        if (BSGFileProtectionTestsAreRequired()) {
            XCTFail(@"Protection classes are not supported on this host: %@", reason);
            return;
        }
        XCTSkip(@"Protection classes are not supported on this host: %@", reason);
    }

    // Any other class is read as is and left alone
    BOOL changed = YES;
    XCTAssertTrue(BSGChangeNSFileProtectionComplete(path, &changed));
    XCTAssertFalse(changed);
    XCTAssertEqualObjects(defaults.getProtection(path), NSURLFileProtectionCompleteUntilFirstUserAuthentication);

    // BSGChangeNSFileProtectionComplete's class is written and read back
    error = nil;
    XCTAssertTrue(defaults.setProtection(path, NSURLFileProtectionCompleteUnlessOpen, &error), @"%@", error);
    XCTAssertEqualObjects(defaults.getProtection(path), NSURLFileProtectionCompleteUnlessOpen);
    NSURLFileProtectionType protection = nil;
    [url removeCachedResourceValueForKey:NSURLFileProtectionKey];
    XCTAssertTrue([url getResourceValue:&protection forKey:NSURLFileProtectionKey error:nil]);
    XCTAssertEqualObjects(protection, NSURLFileProtectionCompleteUnlessOpen);

    // A failure is reported with an error and leaves the class unchanged. Uses a new file, since a locked host can't
    // change the first one back from CompleteUnlessOpen.
    NSString *immutablePath = [self.directory stringByAppendingPathComponent:@"immutable"];
    XCTAssertTrue([[@"abc" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:immutablePath atomically:NO]);
    error = nil;
    XCTAssertTrue([[NSURL fileURLWithPath:immutablePath] setResourceValue:NSURLFileProtectionCompleteUntilFirstUserAuthentication
                                                                   forKey:NSURLFileProtectionKey error:&error], @"%@", error);
    XCTAssertEqual(chflags(immutablePath.fileSystemRepresentation, UF_IMMUTABLE), 0);
    error = nil;
    XCTAssertFalse(defaults.setProtection(immutablePath, NSURLFileProtectionCompleteUnlessOpen, &error));
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(defaults.getProtection(immutablePath), NSURLFileProtectionCompleteUntilFirstUserAuthentication);
    chflags(immutablePath.fileSystemRepresentation, 0);
}
#endif

@end
