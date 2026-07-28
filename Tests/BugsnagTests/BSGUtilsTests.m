//
//  BSGUtilsTests.m
//  Bugsnag
//
//  Created by Nick Dowell on 19/08/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "BSGTestCase.h"

#import "BSGUtils.h"

@interface BSGUtilsTests : BSGTestCase
@end

@implementation BSGUtilsTests

- (void)testPreventInliningConcurrentAccess {
    dispatch_apply(10000,
                   dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0),
                   ^(size_t index) {
        @autoreleasepool {
            BSGPreventInlining([NSString stringWithFormat:@"tag-%zu", index]);
        }
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

@end
