//
//  BSGUtilsTests.m
//  Bugsnag
//
//  Created by Nick Dowell on 19/08/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "BSGTestCase.h"

#import "BSGUtils.h"

#import <fcntl.h>
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

- (void)testOpenFileWithoutCompleteProtectionKeepsTheFirstDescriptorIfItCannotReopen {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];

    // The first descriptor holds an exclusive lock, so reopening with O_EXLOCK | O_NONBLOCK fails and the
    // descriptor that was opened first is returned instead
    int fd = BSGOpenFileWithoutCompleteProtection(path, O_RDWR | O_CREAT | O_EXCL | O_EXLOCK | O_NONBLOCK);
    XCTAssertNotEqual(fd, -1);
    if (fd != -1) {
        XCTAssertTrue(fcntl(fd, F_GETFD) & FD_CLOEXEC);
        XCTAssertEqual(pwrite(fd, "abc", 3, 0), 3);
        // The lock is still held by the returned descriptor
        XCTAssertEqual(open(path.fileSystemRepresentation, O_RDONLY | O_EXLOCK | O_NONBLOCK), -1);
        XCTAssertEqual(errno, EWOULDBLOCK);
        close(fd);
    }
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:path], [@"abc" dataUsingEncoding:NSUTF8StringEncoding]);
    [NSFileManager.defaultManager removeItemAtPath:path error:nil];
}

- (void)testOpenFileWithoutCompleteProtectionFailsIfTheProtectionCannotBeChanged {
#if !TARGET_OS_OSX || defined(__MAC_11_0)
    if (@available(macOS 11.0, *)) {
        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        XCTAssertTrue([[@"abc" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:path atomically:NO]);
        NSURL *url = [NSURL fileURLWithPath:path];
        NSURLFileProtectionType protection = nil;
        if (![url setResourceValue:NSURLFileProtectionComplete forKey:NSURLFileProtectionKey error:nil] ||
            ![url getResourceValue:&protection forKey:NSURLFileProtectionKey error:nil] ||
            ![protection isEqual:NSURLFileProtectionComplete]) {
            [NSFileManager.defaultManager removeItemAtPath:path error:nil];
            XCTSkip(@"File protection is not supported here");
        }
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
        return;
    }
#endif
    XCTSkip(@"NSURLFileProtectionKey is unavailable");
}

@end

#pragma mark - Review findings

@interface BSGUtilsReviewFindingTests : BSGTestCase
@property (nonatomic) NSString *directory;
@end

@implementation BSGUtilsReviewFindingTests

- (void)setUp {
    [super setUp];
    self.directory = [NSTemporaryDirectory() stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"BSGUtilsReviewFindingTests-%@", NSUUID.UUID.UUIDString]];
    [NSFileManager.defaultManager createDirectoryAtPath:self.directory withIntermediateDirectories:YES attributes:nil error:nil];
}

- (void)tearDown {
    [NSFileManager.defaultManager removeItemAtPath:self.directory error:nil];
    [super tearDown];
}

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

@end
