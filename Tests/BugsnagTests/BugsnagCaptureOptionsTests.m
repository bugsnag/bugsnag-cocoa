//
//  BugsnagCaptureOptionsTests.m
//  Bugsnag
//
//  Created by Daria Bialobrzeska on 02/11/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

//Test default values for BugsnagErrorOptions and BugsnagCaptureOptions
//Test custom values are respected
//Test null handling
//Test each capture flag individually (breadcrumbs, featureFlags, metadata, stacktrace, threads, user)
//Test combinations of flags
//Test that app and device metadata are always captured
//Test that error class/message are always captured
//Test metadata filtering with empty array, null, and specific tabs
//Test backward compatibility (notify without options still captures everything)
//Test that unhandled errors are not affected by ErrorOptions
//Test all notify method signatures work correctly

#import "BSGTestCase.h"

#import "Bugsnag.h"
#import "BugsnagClient+Private.h"
#import "BugsnagConfiguration+Private.h"
#import "BugsnagEvent+Private.h"
#import "BugsnagTestConstants.h"
#import "BugsnagNotifier.h"

@interface BugsnagCaptureOptionsTests : BSGTestCase
@end

@implementation BugsnagCaptureOptionsTests

-(BugsnagClient *)prepareClient {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    BugsnagClient *client = [[BugsnagClient alloc] initWithConfiguration:config];
    [client start];
    [client addMetadata:@"aValue1" withKey:@"aKey1" toSection:@"mySection1"];
    [client leaveBreadcrumbWithMessage:@"my message 1212"];
    [client setUser:@"crazyuser" withEmail:@"crazy@dot.com" andName:@"C.Razy"];
    [client addFeatureFlagWithName:@"Testing" variant:@"unit"];
    return client;
}

- (void)shouldBeAlwaysCaptured:(BugsnagEvent *)event userInfo:(NSDictionary *)userInfo {
    // App and device metadata always captured
    XCTAssertNotNil([event.metadata getMetadataFromSection:@"app"]);
    XCTAssertNotNil([event.metadata getMetadataFromSection:@"device"]);
    // Exception details also always captured
    XCTAssertEqualObjects([event.metadata getMetadataFromSection:@"error" withKey:@"type"], @"nsexception");
    XCTAssertEqualObjects([event.metadata getMetadataFromSection:@"error" withKey:@"reason"], @"reason1");
    NSDictionary *exceptionDetails = [event.metadata getMetadataFromSection:@"error" withKey:@"nsexception"];
    XCTAssertEqualObjects(exceptionDetails[@"name"], @"exception1");
    // Exception's user info unrelated to client's user
    XCTAssertEqualObjects(exceptionDetails[@"userInfo"], userInfo);

    XCTAssertEqualObjects(event.errors[0].errorClass, @"exception1");
    XCTAssertEqualObjects(event.errors[0].errorMessage, @"reason1");
}

-(void)breadcrumbsCheck:(BugsnagEvent *)event client:(BugsnagClient *)client {
    [event.breadcrumbs enumerateObjectsUsingBlock:
           ^(BugsnagBreadcrumb *crumb, NSUInteger index, BOOL *stop)
           {
                BugsnagBreadcrumb *clientCrumb = [client.breadcrumbs objectAtIndex:index];
                XCTAssertTrue([crumb.message isEqualToString:clientCrumb.message]);
           }];
}

-(void)customMetadataCheck:(BugsnagEvent *)event client:(BugsnagClient *)client {
    XCTAssertEqualObjects([client getMetadataFromSection:@"mySection1" withKey:@"aKey1"],
                          [event.metadata getMetadataFromSection:@"mySection1" withKey:@"aKey1"]);
}

-(void)userCheck:(BugsnagEvent *)event {
    XCTAssertEqualObjects(event.user.id, @"crazyuser");
    XCTAssertEqualObjects(event.user.name, @"C.Razy");
    XCTAssertEqualObjects(event.user.email, @"crazy@dot.com");
}

-(void)featureFlagCheck:(BugsnagEvent *)event {
    XCTAssertEqual(event.featureFlags[0].name, @"Testing");
    XCTAssertEqual(event.featureFlags[0].variant, @"unit");
}

- (void)testDefaultErrorOptionsValues {
    BugsnagClient *client = [self prepareClient];

    // by default all fields - breadcrumbs, stacktrace, user info, metadata and threads should be recorded
    BugsnagErrorOptions *options = [[BugsnagErrorOptions alloc] init];

    NSDictionary *userInfo = @{ @"exceptionUser": @"anotheruser"};
    NSException *exception1 = [[NSException alloc] initWithName:@"exception1" reason:@"reason1" userInfo:userInfo];
    [client notify:exception1 options:options block:^BOOL(BugsnagEvent * _Nonnull event) {

        [self shouldBeAlwaysCaptured:event userInfo:userInfo];

        [self customMetadataCheck:event client:client];
        [self breadcrumbsCheck:event client:client];
        [self userCheck:event];
        [self featureFlagCheck:event];
#if BSG_HAVE_MACH_THREADS
        XCTAssertNotNil(event.threads);
#endif
        XCTAssertNotNil(event.errors[0].stacktrace);

        return NO;
    }];
}

- (void)testDontCaptureBreadcrumbs {
    BugsnagClient *client = [self prepareClient];

    // Turn off only breadcrumbs
    BugsnagErrorOptions *options = [[BugsnagErrorOptions alloc] init];
    options.capture.breadcrumbs = NO;

    NSDictionary *userInfo = @{ @"exceptionUser": @"anotheruser"};
    NSException *exception1 = [[NSException alloc] initWithName:@"exception1" reason:@"reason1" userInfo:userInfo];
    [client notify:exception1 options:options block:^BOOL(BugsnagEvent * _Nonnull event) {

        [self shouldBeAlwaysCaptured:event userInfo:userInfo];

        [self customMetadataCheck:event client:client];
        XCTAssertNil(event.breadcrumbs);
        [self userCheck:event];
        [self featureFlagCheck:event];
#if BSG_HAVE_MACH_THREADS
        XCTAssertNotNil(event.threads);
#endif
        XCTAssertNotNil(event.errors[0].stacktrace);

        return NO;
    }];
}

- (void)testDontCaptureThreads {
    BugsnagClient *client = [self prepareClient];

    // Turn off only breadcrumbs
    BugsnagErrorOptions *options = [[BugsnagErrorOptions alloc] init];
    options.capture.threads = NO;

    NSDictionary *userInfo = @{ @"exceptionUser": @"anotheruser"};
    NSException *exception1 = [[NSException alloc] initWithName:@"exception1" reason:@"reason1" userInfo:userInfo];
    [client notify:exception1 options:options block:^BOOL(BugsnagEvent * _Nonnull event) {

        [self shouldBeAlwaysCaptured:event userInfo:userInfo];

        [self customMetadataCheck:event client:client];
        [self breadcrumbsCheck:event client:client];
        [self userCheck:event];
        [self featureFlagCheck:event];
#if BSG_HAVE_MACH_THREADS
        XCTAssertNil(event.threads);
#endif
        XCTAssertNotNil(event.errors[0].stacktrace);

        return NO;
    }];
}

- (void)testDontCaptureUser {
    BugsnagClient *client = [self prepareClient];

    // Turn off only breadcrumbs
    BugsnagErrorOptions *options = [[BugsnagErrorOptions alloc] init];
    options.capture.user = NO;

    NSDictionary *userInfo = @{ @"exceptionUser": @"anotheruser"};
    NSException *exception1 = [[NSException alloc] initWithName:@"exception1" reason:@"reason1" userInfo:userInfo];
    [client notify:exception1 options:options block:^BOOL(BugsnagEvent * _Nonnull event) {

        [self shouldBeAlwaysCaptured:event userInfo:userInfo];

        [self customMetadataCheck:event client:client];
        [self breadcrumbsCheck:event client:client];
        XCTAssertNil(event.user);
        [self featureFlagCheck:event];
#if BSG_HAVE_MACH_THREADS
        XCTAssertNotNil(event.threads);
#endif
        XCTAssertNotNil(event.errors[0].stacktrace);

        return NO;
    }];
}

- (void)testDontCaptureFeatureFlags {
    BugsnagClient *client = [self prepareClient];

    // Turn off only breadcrumbs
    BugsnagErrorOptions *options = [[BugsnagErrorOptions alloc] init];
    options.capture.featureFlags = NO;

    NSDictionary *userInfo = @{ @"exceptionUser": @"anotheruser"};
    NSException *exception1 = [[NSException alloc] initWithName:@"exception1" reason:@"reason1" userInfo:userInfo];
    [client notify:exception1 options:options block:^BOOL(BugsnagEvent * _Nonnull event) {

        [self shouldBeAlwaysCaptured:event userInfo:userInfo];

        [self customMetadataCheck:event client:client];
        [self breadcrumbsCheck:event client:client];
        [self userCheck:event];
        XCTAssertTrue([event.featureFlags count] == 0);
#if BSG_HAVE_MACH_THREADS
        XCTAssertNotNil(event.threads);
#endif
        XCTAssertNotNil(event.errors[0].stacktrace);

        return NO;
    }];
}

- (void)testDontCaptureStacktrace {
    BugsnagClient *client = [self prepareClient];

    // Turn off only breadcrumbs
    BugsnagErrorOptions *options = [[BugsnagErrorOptions alloc] init];
    options.capture.stacktrace = NO;

    NSDictionary *userInfo = @{ @"exceptionUser": @"anotheruser"};
    NSException *exception1 = [[NSException alloc] initWithName:@"exception1" reason:@"reason1" userInfo:userInfo];
    [client notify:exception1 options:options block:^BOOL(BugsnagEvent * _Nonnull event) {

        [self shouldBeAlwaysCaptured:event userInfo:userInfo];

        [self customMetadataCheck:event client:client];
        [self breadcrumbsCheck:event client:client];
        [self userCheck:event];
        [self featureFlagCheck:event];
#if BSG_HAVE_MACH_THREADS
        XCTAssertNotNil(event.threads);
#endif
        XCTAssertTrue([event.errors[0].stacktrace count] == 0);

        return NO;
    }];
}

- (void)testMetadataEmptyArray {
    BugsnagClient *client = [self prepareClient];

    // Turn off only breadcrumbs
    BugsnagErrorOptions *options = [[BugsnagErrorOptions alloc] init];
    options.capture.metadata = @[];

    NSDictionary *userInfo = @{ @"exceptionUser": @"anotheruser"};
    NSException *exception1 = [[NSException alloc] initWithName:@"exception1" reason:@"reason1" userInfo:userInfo];
    [client notify:exception1 options:options block:^BOOL(BugsnagEvent * _Nonnull event) {

        [self shouldBeAlwaysCaptured:event userInfo:userInfo];

        XCTAssertNil([event.metadata getMetadataFromSection:@"mySection1"]);
        [self breadcrumbsCheck:event client:client];
        [self userCheck:event];
        [self featureFlagCheck:event];
#if BSG_HAVE_MACH_THREADS
        XCTAssertNotNil(event.threads);
#endif
        XCTAssertNotNil(event.errors[0].stacktrace);

        return NO;
    }];
}

- (void)testMetadataSelectiveCapture {
    BugsnagClient *client = [self prepareClient];
    [client addMetadata:@"aValue2" withKey:@"aKey2" toSection:@"mySection2"];

    // Turn off only breadcrumbs
    BugsnagErrorOptions *options = [[BugsnagErrorOptions alloc] init];
    options.capture.metadata = @[@"mySection1"];

    NSDictionary *userInfo = @{ @"exceptionUser": @"anotheruser"};
    NSException *exception1 = [[NSException alloc] initWithName:@"exception1" reason:@"reason1" userInfo:userInfo];
    [client notify:exception1 options:options block:^BOOL(BugsnagEvent * _Nonnull event) {

        [self shouldBeAlwaysCaptured:event userInfo:userInfo];

        [self customMetadataCheck:event client:client];
        XCTAssertNil([event.metadata getMetadataFromSection:@"mySection2"]);
        [self breadcrumbsCheck:event client:client];
        [self userCheck:event];
        [self featureFlagCheck:event];
#if BSG_HAVE_MACH_THREADS
        XCTAssertNotNil(event.threads);
#endif
        XCTAssertNotNil(event.errors[0].stacktrace);

        return NO;
    }];
}


- (void)testMetadataCombinationOfCaptureFlags {
    BugsnagClient *client = [self prepareClient];
    [client addMetadata:@"aValue2" withKey:@"aKey2" toSection:@"mySection2"];

    // Turn off only breadcrumbs
    BugsnagErrorOptions *options = [[BugsnagErrorOptions alloc] init];
    options.capture.metadata = @[@"mySection1"];
    options.capture.user = NO;
    options.capture.stacktrace = NO;

    NSDictionary *userInfo = @{ @"exceptionUser": @"anotheruser"};
    NSException *exception1 = [[NSException alloc] initWithName:@"exception1" reason:@"reason1" userInfo:userInfo];
    [client notify:exception1 options:options block:^BOOL(BugsnagEvent * _Nonnull event) {

        [self shouldBeAlwaysCaptured:event userInfo:userInfo];

        [self customMetadataCheck:event client:client];
        XCTAssertNil([event.metadata getMetadataFromSection:@"mySection2"]);
        [self breadcrumbsCheck:event client:client];
        XCTAssertNil(event.user);
        [self featureFlagCheck:event];
#if BSG_HAVE_MACH_THREADS
        XCTAssertNotNil(event.threads);
#endif
        XCTAssertTrue([event.errors[0].stacktrace count] == 0);

        return NO;
    }];
}

- (void)testUnlikelyUnhandledShouldHaveEverything {
    BugsnagClient *client = [self prepareClient];

    // everything turned off - should be ignored for unhandled
    BugsnagErrorOptions *options = [[BugsnagErrorOptions alloc] init];
    options.capture.breadcrumbs = NO;
    options.capture.threads = NO;
    options.capture.user = NO;
    options.capture.featureFlags = NO;
    options.capture.stacktrace = NO;
    options.capture.metadata = @[];

    // Not nsexception/nserror so unhandled
    NSString *exception1 = @"stringexc";
    [client notifyErrorOrException:exception1 stackStripDepth:4 options:options block:^BOOL(BugsnagEvent * _Nonnull event) {

        XCTAssertNotNil([event.metadata getMetadataFromSection:@"app"]);
        XCTAssertNotNil([event.metadata getMetadataFromSection:@"device"]);

        [self customMetadataCheck:event client:client];
        [self breadcrumbsCheck:event client:client];
        [self userCheck:event];
        [self featureFlagCheck:event];
#if BSG_HAVE_MACH_THREADS
        XCTAssertNotNil(event.threads);
#endif
        XCTAssertNotNil(event.errors[0].stacktrace);

        return NO;
    }];
}

@end
