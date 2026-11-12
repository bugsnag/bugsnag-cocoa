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

@end
