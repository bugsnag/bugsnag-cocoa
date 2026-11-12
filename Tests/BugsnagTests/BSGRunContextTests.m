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
#import <unistd.h>

@interface BSGRunContextTests : BSGTestCase

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

- (void)testRunContextFileStaysOpenWhileMapped {
    NSString *path = BSGFileLocations.current.runContext;

    BSGRunContextInit(path);
    // The descriptor must stay open so that NSFileProtectionCompleteUnlessOpen
    // keeps the mapped file accessible while the device is locked.
    XCTAssertEqual(CountOpenDescriptorsForPath(path), 1);

    // Writes through the mapping must reach the file.
    bsg_runContext->unhandledCount = 0x5EED;
    XCTAssertEqual(msync(bsg_runContext, sizeof(struct BSGRunContext), MS_SYNC), 0);
    NSData *data = [NSData dataWithContentsOfFile:path];
    XCTAssertEqual(data.length, sizeof(struct BSGRunContext));
    XCTAssertEqual(((const struct BSGRunContext *)data.bytes)->unhandledCount, 0x5EEDUL);

    // Reinitialising replaces the descriptor rather than leaking it.
    BSGRunContextInit(path);
    XCTAssertEqual(CountOpenDescriptorsForPath(path), 1);
}

- (void)testDisableNSFileProtectionComplete {
#if !TARGET_OS_OSX || defined(__MAC_11_0)
    if (@available(macOS 11.0, *)) {
        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        XCTAssertTrue([NSData.data writeToFile:path atomically:NO]);
        NSURL *url = [NSURL fileURLWithPath:path];

        NSError *error = nil;
        NSURLFileProtectionType protection = nil;
        if (![url setResourceValue:NSURLFileProtectionComplete forKey:NSURLFileProtectionKey error:&error] ||
            ![url getResourceValue:&protection forKey:NSURLFileProtectionKey error:nil] ||
            ![protection isEqual:NSURLFileProtectionComplete]) {
            [NSFileManager.defaultManager removeItemAtPath:path error:nil];
            XCTSkip(@"File protection is not supported here: %@ %@", protection, error);
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
