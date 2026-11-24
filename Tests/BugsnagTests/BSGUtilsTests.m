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
    // The same as testCompleteFileIsReopenedAfterItsProtectionIsChanged, with a real protection class
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    NSData *contents = [@"abc" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertTrue([contents writeToFile:path atomically:NO]);
    // The change this test checks is tried first on a scratch file, because some hosts refuse it
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
    NSURLFileProtectionType protection = nil;
    NSString *reason = BSGSetRealFileProtectionComplete(path);
    BSGSkipUnlessFileProtectionComplete(reason, path);
    // An immutable file can be opened for reading, but its protection class cannot be changed
    XCTAssertEqual(chflags(path.fileSystemRepresentation, UF_IMMUTABLE), 0);

    XCTAssertEqual(BSGOpenFileWithoutCompleteProtection(path, O_RDONLY), -1);
    // A file that was not created by the call is not deleted
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:path]);
    protection = nil;
    [url removeCachedResourceValueForKey:NSURLFileProtectionKey];
    XCTAssertTrue([url getResourceValue:&protection forKey:NSURLFileProtectionKey error:nil]);
    XCTAssertEqualObjects(protection, NSURLFileProtectionComplete);

    chflags(path.fileSystemRepresentation, 0);
    [NSFileManager.defaultManager removeItemAtPath:path error:nil];
}

@end

#pragma mark - Reopening files whose protection class is changed

/// These tests stand in for the file system's protection classes (see BSGSetFileProtectionFunctions), so that the
/// handling of NSFileProtectionComplete is tested on any host, including a locked or headless one and the simulator.
@interface BSGOpenFileWithoutCompleteProtectionTests : BSGTestCase
@property (nonatomic) NSString *directory;
@end

// BSGSetFileProtectionFunctions only exists in debug builds, so the tests that simulate protection classes do too
#if defined(DEBUG) && DEBUG
// The simulated protection class of each path; a path that is not present has none
static NSMutableDictionary<NSString *, NSString *> *gSimulatedProtection;
// The paths and classes passed to SimulatedSetProtection
static NSMutableArray<NSArray<NSString *> *> *gSetProtectionCalls;
// If set, SimulatedSetProtection fails with this error
static NSError *gSetProtectionError;
// Called by SimulatedGetProtection and SimulatedSetProtection with the path, before they do anything else
static void (^gWillGetProtection)(NSString *path);
static void (^gWillSetProtection)(NSString *path);
static BSGFileProtectionFunctions gPreviousProtectionFunctions;
// The directory of the test that is simulating protection classes. The functions are global, so other threads (e.g.
// a feature flag store's retry left over from an earlier test) can call them meanwhile; only the test's own files
// are simulated and recorded, and other paths go to the real functions.
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

// Only the tests that simulate protection classes use these helpers, so they are only in debug builds too

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

/// Sets O_NONBLOCK on the open file description of every descriptor that refers to the file at the path. A
/// descriptor returned by a later open() of the path has its own description, without the flag, so this tells a
/// descriptor that was opened first apart from one that was reopened.
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
#endif

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
    // Known before the simulated functions are installed, because other threads may call them straight away
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

#pragma mark Simulated protection classes

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

    // The POSIX error that caused the failure is passed on, so that it is not mistaken for a locked device (EPERM)
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
    // It was opened with the same access mode, and the file was not truncated
    char buffer[3] = {0};
    XCTAssertEqual(pread(fd, buffer, 3, 0), 3);
    XCTAssertEqual(memcmp(buffer, "abc", 3), 0);
    XCTAssertEqual(pwrite(fd, "xyz", 3, 0), 3);
    close(fd);
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:path], [@"xyz" dataUsingEncoding:NSUTF8StringEncoding]);

    // The same applies to a file created by the call in a directory whose files get NSFileProtectionComplete
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
    // Other code in the test process can read a protection class while these functions are replaced, so only this
    // test's files are recorded
    NSString *directory = self.directory;
    gWillGetProtection = ^(NSString *p) {
        if ([p hasPrefix:directory]) {
            lstat(p.fileSystemRepresentation, &opened);
        }
    };

    // A file that already existed is left as it was, and its descriptor closed
    NSString *existing = [self.directory stringByAppendingPathComponent:@"existing"];
    XCTAssertTrue([[@"abc" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:existing atomically:NO]);
    gSimulatedProtection[existing] = NSURLFileProtectionComplete;
    for (NSNumber *flags in @[@(O_RDONLY), @(O_RDWR), @(O_RDWR | O_CREAT)]) {
        opened = (struct stat){0};
        XCTAssertEqual(BSGOpenFileWithoutCompleteProtection(existing, flags.intValue), -1);
        XCTAssertNotEqual(opened.st_ino, 0);
        NSArray<NSNumber *> *leftOpen = DescriptorsForFile(opened.st_dev, opened.st_ino);
        XCTAssertEqualObjects(leftOpen, @[], @"%@", PathsOfDescriptors(leftOpen));
    }
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:existing], [@"abc" dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertEqualObjects(gSimulatedProtection[existing], NSURLFileProtectionComplete);
}

- (void)testFirstDescriptorIsKeptIfTheFileCannotBeReopened {
    [self simulateProtection];
    NSString *path = [self.directory stringByAppendingPathComponent:@"file"];
    gSimulatedProtection[path] = NSURLFileProtectionComplete;

    // The first descriptor holds an exclusive lock, so reopening with O_EXLOCK | O_NONBLOCK fails (EWOULDBLOCK) and
    // the descriptor that was opened first, whose file now has the changed class, is returned instead
    const int fd = BSGOpenFileWithoutCompleteProtection(path, O_RDWR | O_CREAT | O_EXCL | O_EXLOCK | O_NONBLOCK);
    XCTAssertNotEqual(fd, -1);
    if (fd == -1) {
        return;
    }
    XCTAssertEqualObjects(gSetProtectionCalls, (@[@[path, NSURLFileProtectionCompleteUnlessOpen]]),
                          @"The class must have been changed, so that the file was reopened");
    XCTAssertTrue(fcntl(fd, F_GETFD) & FD_CLOEXEC);
    XCTAssertEqual(pwrite(fd, "abc", 3, 0), 3);
    // The lock is still held by the returned descriptor
    errno = 0;
    XCTAssertEqual(open(path.fileSystemRepresentation, O_RDONLY | O_EXLOCK | O_NONBLOCK), -1);
    XCTAssertEqual(errno, EWOULDBLOCK);
    struct stat st;
    XCTAssertEqual(fstat(fd, &st), 0);
    XCTAssertEqualObjects(DescriptorsForFile(st.st_dev, st.st_ino), @[@(fd)], @"Nothing else should be left open");
    close(fd);
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:path], [@"abc" dataUsingEncoding:NSUTF8StringEncoding]);
}

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
    // A different file is renamed over the path between the two opens, so the reopened descriptor would refer to a
    // file whose protection class was never checked
    gWillSetProtection = ^(NSString *p) {
        rename(other.fileSystemRepresentation, p.fileSystemRepresentation);
    };

    errno = 0;
    XCTAssertEqual(BSGOpenFileWithoutCompleteProtection(path, O_RDWR), -1);
    XCTAssertEqual(errno, EAGAIN, @"The caller can tell that the file at the path changed, and try again");
    XCTAssertEqual(gSetProtectionCalls.count, 1);
    XCTAssertEqualObjects(DescriptorsForFile(original.st_dev, original.st_ino), @[], @"The first descriptor should be closed");
    XCTAssertEqualObjects(DescriptorsForFile(replacement.st_dev, replacement.st_ino), @[], @"The reopened descriptor should be closed");

    // Opening it again (as the caller does) opens the file that is now at the path, and checks its class
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

- (void)testFileReplacedOrRemovedBeforeItsProtectionIsReadCanBeOpenedAgain {
    [self simulateProtection];
    NSString *path = [self.directory stringByAppendingPathComponent:@"file"];
    NSString *other = [self.directory stringByAppendingPathComponent:@"other"];
    XCTAssertTrue([[@"original" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:path atomically:NO]);
    XCTAssertTrue([[@"replacement" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:other atomically:NO]);
    struct stat original, replacement;
    XCTAssertEqual(lstat(path.fileSystemRepresentation, &original), 0);
    XCTAssertEqual(lstat(other.fileSystemRepresentation, &replacement), 0);
    // The class read from the path does not need changing, so the file is not reopened
    gSimulatedProtection[path] = NSURLFileProtectionCompleteUntilFirstUserAuthentication;
    // A different file is renamed over the path after it is opened, so the class read is that of the replacement and
    // not of the file that the descriptor refers to
    gWillGetProtection = ^(NSString *p) {
        rename(other.fileSystemRepresentation, p.fileSystemRepresentation);
    };

    // The result and errno are saved before any assertion, and a descriptor returned unexpectedly is closed
    errno = 0;
    int fd = BSGOpenFileWithoutCompleteProtection(path, O_RDWR);
    int openError = errno;
    if (fd != -1) {
        close(fd);
    }
    XCTAssertEqual(fd, -1);
    XCTAssertEqual(openError, EAGAIN, @"The caller can tell that the file at the path changed, and try again");
    XCTAssertEqualObjects(gSetProtectionCalls, @[]);
    XCTAssertEqualObjects(DescriptorsForFile(original.st_dev, original.st_ino), @[], @"The descriptor should be closed");
    XCTAssertEqualObjects(DescriptorsForFile(replacement.st_dev, replacement.st_ino), @[], @"Nothing else should be open");

    // Opening it again (as the caller does) returns a descriptor for the file that is now at the path
    gWillGetProtection = nil;
    fd = BSGOpenFileWithoutCompleteProtection(path, O_RDWR);
    XCTAssertNotEqual(fd, -1);
    if (fd != -1) {
        struct stat byDescriptor;
        XCTAssertEqual(fstat(fd, &byDescriptor), 0);
        XCTAssertEqual(byDescriptor.st_dev, replacement.st_dev);
        XCTAssertEqual(byDescriptor.st_ino, replacement.st_ino);
        close(fd);
    }

    // The same applies if the file is removed after it is opened
    gWillGetProtection = ^(NSString *p) {
        unlink(p.fileSystemRepresentation);
    };
    errno = 0;
    fd = BSGOpenFileWithoutCompleteProtection(path, O_RDWR);
    openError = errno;
    if (fd != -1) {
        close(fd);
    }
    XCTAssertEqual(fd, -1);
    XCTAssertEqual(openError, EAGAIN, @"The caller can tell that the file was removed, and try again");
    XCTAssertEqualObjects(DescriptorsForFile(replacement.st_dev, replacement.st_ino), @[], @"The descriptor should be closed");

    gWillGetProtection = nil;
    fd = BSGOpenFileWithoutCompleteProtection(path, O_RDWR | O_CREAT);
    XCTAssertNotEqual(fd, -1);
    if (fd != -1) {
        struct stat byDescriptor, byPath;
        XCTAssertEqual(fstat(fd, &byDescriptor), 0);
        XCTAssertEqual(lstat(path.fileSystemRepresentation, &byPath), 0);
        XCTAssertEqual(byDescriptor.st_dev, byPath.st_dev);
        XCTAssertEqual(byDescriptor.st_ino, byPath.st_ino);
        close(fd);
    }
}

#endif // DEBUG

#pragma mark Real files

/// The lowest descriptor number that is not in use, which is the one open() returns next.
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

    // Reopening opens a second descriptor before closing the first, so the descriptor returned would not be
    // the lowest free one. Other threads can open descriptors at the same time, so this is tried a few times.
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

    // The same applies to a file created by the call
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
    // The tests above stand in for the file system, so this checks the functions they replace against a real file.
    // NSFileProtectionCompleteUntilFirstUserAuthentication and NSFileProtectionCompleteUnlessOpen, unlike
    // NSFileProtectionComplete, can be set while the screen is locked, so this runs on a locked or headless host
    // too. Only reading NSFileProtectionComplete itself is left to the tests that set it on a real file.
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

    // A class other than NSFileProtectionComplete is read as it is and left alone
    BOOL changed = YES;
    XCTAssertTrue(BSGChangeNSFileProtectionComplete(path, &changed));
    XCTAssertFalse(changed);
    XCTAssertEqualObjects(defaults.getProtection(path), NSURLFileProtectionCompleteUntilFirstUserAuthentication);

    // The class that BSGChangeNSFileProtectionComplete sets is written to the file, and read back
    error = nil;
    XCTAssertTrue(defaults.setProtection(path, NSURLFileProtectionCompleteUnlessOpen, &error), @"%@", error);
    XCTAssertEqualObjects(defaults.getProtection(path), NSURLFileProtectionCompleteUnlessOpen);
    NSURLFileProtectionType protection = nil;
    [url removeCachedResourceValueForKey:NSURLFileProtectionKey];
    XCTAssertTrue([url getResourceValue:&protection forKey:NSURLFileProtectionKey error:nil]);
    XCTAssertEqualObjects(protection, NSURLFileProtectionCompleteUnlessOpen);

    // A failure is reported with an error, and the class is not changed. This uses a new file: while the screen
    // is locked, the first file's class cannot be changed back from NSFileProtectionCompleteUnlessOpen, so
    // changing it back would make the test depend on whether the host's screen is locked.
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
