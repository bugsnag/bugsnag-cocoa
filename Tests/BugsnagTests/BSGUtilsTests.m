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
    // Usable for reading and writing
    XCTAssertEqual(pwrite(fd, "abc", 3, 0), 3);
    char buffer[3] = {0};
    XCTAssertEqual(pread(fd, buffer, 3, 0), 3);
    XCTAssertEqual(memcmp(buffer, "abc", 3), 0);
    close(fd);

    // O_EXCL fails for an existing file and leaves it alone
    XCTAssertEqual(BSGOpenFileWithoutCompleteProtection(path, O_RDWR | O_CREAT | O_EXCL), -1);
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:path], [@"abc" dataUsingEncoding:NSUTF8StringEncoding]);

    // An existing file is not truncated
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
    // testCompleteFileIsReopenedAfterItsProtectionIsChanged with a real protection class
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    NSData *contents = [@"abc" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertTrue([contents writeToFile:path atomically:NO]);
    // Tried on a scratch file first, as some hosts refuse the change
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
    // Immutable: readable, but its protection class cannot be changed
    XCTAssertEqual(chflags(path.fileSystemRepresentation, UF_IMMUTABLE), 0);

    XCTAssertEqual(BSGOpenFileWithoutCompleteProtection(path, O_RDONLY), -1);
    // A file the call did not create is not deleted
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

/// Simulates protection classes so NSFileProtectionComplete handling is tested on any host, locked or headless.
@interface BSGOpenFileWithoutCompleteProtectionTests : BSGTestCase
@property (nonatomic) NSString *directory;
@end

// BSGSetFileProtectionFunctions is debug-only, so the simulating tests are too
#if defined(DEBUG) && DEBUG
// Simulated protection class per path; a missing path has none
static NSMutableDictionary<NSString *, NSString *> *gSimulatedProtection;
// The paths and classes passed to SimulatedSetProtection
static NSMutableArray<NSArray<NSString *> *> *gSetProtectionCalls;
// If set, SimulatedSetProtection fails with this error
static NSError *gSetProtectionError;
// Called first by SimulatedGetProtection / SimulatedSetProtection with the path
static void (^gWillGetProtection)(NSString *path);
static void (^gWillSetProtection)(NSString *path);
static BSGFileProtectionFunctions gPreviousProtectionFunctions;
// Only files in this directory are simulated; other threads (e.g. a leftover feature flag store retry) may call the
// global functions meanwhile, and their paths go to the real functions.
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

// Debug-only helpers for the simulating tests

/// The descriptors in this process for the file with this device and inode.
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

/// Marks every descriptor for the file at the path with O_NONBLOCK; a later open() gets its own file description
/// without the flag, so a reopened descriptor can be told apart.
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
    // Store the defaults first: other threads may call the simulated functions as soon as they are installed
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

    // The underlying POSIX error is passed on, so it is not mistaken for a locked device (EPERM)
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
    // Same access mode, not truncated
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
    // Only this test's files are recorded; other code may read protection classes meanwhile
    NSString *directory = self.directory;
    gWillGetProtection = ^(NSString *p) {
        if ([p hasPrefix:directory]) {
            lstat(p.fileSystemRepresentation, &opened);
        }
    };

    // An existing file is left as it was and its descriptor closed
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

- (void)testFileThatCannotBeReopenedIsNotUsed {
    [self simulateProtection];
    NSString *path = [self.directory stringByAppendingPathComponent:@"file"];
    gSimulatedProtection[path] = NSURLFileProtectionComplete;

    // The first descriptor's O_EXLOCK makes the reopen fail (EWOULDBLOCK). The first one, opened under
    // NSFileProtectionComplete, is closed rather than returned: a mapping could fault once the device locks
    errno = 0;
    XCTAssertEqual(BSGOpenFileWithoutCompleteProtection(path, O_RDWR | O_CREAT | O_EXCL | O_EXLOCK | O_NONBLOCK), -1);
    XCTAssertEqual(errno, EWOULDBLOCK, @"The reopen's error should be returned");
    XCTAssertEqualObjects(gSetProtectionCalls, (@[@[path, NSURLFileProtectionCompleteUnlessOpen]]),
                          @"The class must have been changed, so that the file was reopened");
    struct stat st;
    XCTAssertEqual(stat(path.fileSystemRepresentation, &st), 0);
    XCTAssertEqualObjects(DescriptorsForFile(st.st_dev, st.st_ino), @[], @"No descriptor should be left open");
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

    // The caller's retry creates the file at the path
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
    // Another file is renamed over the path between the opens; its protection class was never checked
    gWillSetProtection = ^(NSString *p) {
        rename(other.fileSystemRepresentation, p.fileSystemRepresentation);
    };

    errno = 0;
    XCTAssertEqual(BSGOpenFileWithoutCompleteProtection(path, O_RDWR), -1);
    XCTAssertEqual(errno, EAGAIN, @"The caller can tell that the file at the path changed, and try again");
    XCTAssertEqual(gSetProtectionCalls.count, 1);
    XCTAssertEqualObjects(DescriptorsForFile(original.st_dev, original.st_ino), @[], @"The first descriptor should be closed");
    XCTAssertEqualObjects(DescriptorsForFile(replacement.st_dev, replacement.st_ino), @[], @"The reopened descriptor should be closed");

    // The caller's retry opens the new file and checks its class
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
    // No change needed, so no reopen
    gSimulatedProtection[path] = NSURLFileProtectionCompleteUntilFirstUserAuthentication;
    // Another file is renamed over the path after the open, so the class read is not the descriptor's file's
    gWillGetProtection = ^(NSString *p) {
        rename(other.fileSystemRepresentation, p.fileSystemRepresentation);
    };

    // Save the result and errno before asserting; close an unexpected descriptor
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

    // The caller's retry returns the file now at the path
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

    // Likewise if the file is removed after the open
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

/// The lowest free descriptor, which open() returns next.
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

    // A reopen would not return the lowest free descriptor. Retried because other threads may open descriptors.
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
    // Checks the real functions that the tests above replace. Uses classes other than NSFileProtectionComplete, which
    // can be set while locked, so it runs on locked or headless hosts too.
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

    // The class BSGChangeNSFileProtectionComplete sets is written and read back
    error = nil;
    XCTAssertTrue(defaults.setProtection(path, NSURLFileProtectionCompleteUnlessOpen, &error), @"%@", error);
    XCTAssertEqualObjects(defaults.getProtection(path), NSURLFileProtectionCompleteUnlessOpen);
    NSURLFileProtectionType protection = nil;
    [url removeCachedResourceValueForKey:NSURLFileProtectionKey];
    XCTAssertTrue([url getResourceValue:&protection forKey:NSURLFileProtectionKey error:nil]);
    XCTAssertEqualObjects(protection, NSURLFileProtectionCompleteUnlessOpen);

    // A failure sets an error and leaves the class. Uses a new file, since the first one's class cannot be changed back
    // from NSFileProtectionCompleteUnlessOpen while the screen is locked.
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
