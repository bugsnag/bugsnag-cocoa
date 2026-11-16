//
//  BSGAtomicFeatureFlagStoreTests.m
//  Bugsnag
//
//  Created by Robert B on 24/03/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGTestCase.h"
#import "BSGAtomicFeatureFlagStore.h"
#import "WriterTestsSupport.h"
#import "BugsnagFeatureFlag.h"

@interface BSGAtomicFeatureFlagStoreTests : BSGTestCase

@end

@implementation BSGAtomicFeatureFlagStoreTests

- (void)setUp {
    BSGAtomicFeatureFlagStore *store = [BSGAtomicFeatureFlagStore store];
    [store clear];
}

- (void)testStoreIsInitiallyEmpty {
    BSGAtomicFeatureFlagStore *store = [BSGAtomicFeatureFlagStore store];
    
    NSDictionary<NSString *, id> *object = bsg_JSONObject(^(BSG_KSCrashReportWriter *writer) {
        writer->beginObject(writer, "");
        BugsnagFeatureFlagsWriteCrashReport(writer, true);
        writer->endContainer(writer);
    });
    
    XCTAssertEqualObjects(object.allKeys, @[@"featureFlags"]);
    XCTAssertTrue([store isEmpty]);
    
    NSArray<NSDictionary *> *featureFlags = object[@"featureFlags"];
    XCTAssertEqual(featureFlags.count, 0);
}

- (void)testAddMultipleFlagsAtOnce {
    BSGAtomicFeatureFlagStore *store = [BSGAtomicFeatureFlagStore store];
    [store addFeatureFlags:@[
        [BugsnagFeatureFlag flagWithName:@"featureFlagA"],
        [BugsnagFeatureFlag flagWithName:@"featureFlagB" variant:@"testingB"],
        [BugsnagFeatureFlag flagWithName:@"featureFlagC" variant:@"testingC"]
    ]];
    
    NSDictionary<NSString *, id> *object = bsg_JSONObject(^(BSG_KSCrashReportWriter *writer) {
        writer->beginObject(writer, "");
        BugsnagFeatureFlagsWriteCrashReport(writer, true);
        writer->endContainer(writer);
    });
    
    XCTAssertEqualObjects(object.allKeys, @[@"featureFlags"]);
    
    NSArray<NSDictionary *> *featureFlags = object[@"featureFlags"];
    XCTAssertEqual(featureFlags.count, 3);
    
    XCTAssertTrue([featureFlags[0][@"featureFlag"] isEqualToString: @"featureFlagA"]);
    XCTAssertNil(featureFlags[0][@"variant"]);
    
    XCTAssertTrue([featureFlags[1][@"featureFlag"] isEqualToString: @"featureFlagB"]);
    XCTAssertTrue([featureFlags[1][@"variant"] isEqualToString: @"testingB"]);
    
    XCTAssertTrue([featureFlags[2][@"featureFlag"] isEqualToString: @"featureFlagC"]);
    XCTAssertTrue([featureFlags[2][@"variant"] isEqualToString: @"testingC"]);
}

- (void)testAddAndReplace {
    BSGAtomicFeatureFlagStore *store = [BSGAtomicFeatureFlagStore store];

    [store addFeatureFlag:@"featureFlagA" withVariant:@"testingA"];
    [store addFeatureFlag:@"featureFlagB" withVariant:@"testingB"];
    [store addFeatureFlag:@"featureFlagC" withVariant:@"testingC"];
    [store addFeatureFlag:@"featureFlagD" withVariant:@"testingD"];
    [store addFeatureFlag:@"featureFlagA" withVariant:@"testingA2"];
    [store addFeatureFlag:@"featureFlagB" withVariant:@"testingB2"];
    [store addFeatureFlag:@"featureFlagC" withVariant:@"testingC2"];
    [store addFeatureFlag:@"featureFlagB" withVariant:@"testingB3"];
    [store addFeatureFlag:@"featureFlagA" withVariant:@"testingA3"];
    
    NSDictionary<NSString *, id> *object = bsg_JSONObject(^(BSG_KSCrashReportWriter *writer) {
        writer->beginObject(writer, "");
        BugsnagFeatureFlagsWriteCrashReport(writer, true);
        writer->endContainer(writer);
    });
    
    XCTAssertEqualObjects(object.allKeys, @[@"featureFlags"]);
    
    NSArray<NSDictionary *> *featureFlags = object[@"featureFlags"];
    XCTAssertEqual(featureFlags.count, 4);
    
    XCTAssertTrue([featureFlags[0][@"featureFlag"] isEqualToString: @"featureFlagD"]);
    XCTAssertTrue([featureFlags[0][@"variant"] isEqualToString: @"testingD"]);
    
    XCTAssertTrue([featureFlags[1][@"featureFlag"] isEqualToString: @"featureFlagC"]);
    XCTAssertTrue([featureFlags[1][@"variant"] isEqualToString: @"testingC2"]);
    
    XCTAssertTrue([featureFlags[2][@"featureFlag"] isEqualToString: @"featureFlagB"]);
    XCTAssertTrue([featureFlags[2][@"variant"] isEqualToString: @"testingB3"]);
    
    XCTAssertTrue([featureFlags[3][@"featureFlag"] isEqualToString: @"featureFlagA"]);
    XCTAssertTrue([featureFlags[3][@"variant"] isEqualToString: @"testingA3"]);
}

- (void)testAddMultipleAndReplace {
    BSGAtomicFeatureFlagStore *store = [BSGAtomicFeatureFlagStore store];
    [store addFeatureFlags:@[
        [BugsnagFeatureFlag flagWithName:@"featureFlagA"],
        [BugsnagFeatureFlag flagWithName:@"featureFlagB" variant:@"testingB"],
        [BugsnagFeatureFlag flagWithName:@"featureFlagC" variant:@"testingC"]
    ]];
    
    [store addFeatureFlag:@"featureFlagA" withVariant:@"testingA2"];
    [store addFeatureFlag:@"featureFlagB" withVariant:@"testingB2"];
    [store addFeatureFlag:@"featureFlagD" withVariant:@"testingD"];
    [store addFeatureFlag:@"featureFlagC" withVariant:@"testingC2"];
    
    NSDictionary<NSString *, id> *object = bsg_JSONObject(^(BSG_KSCrashReportWriter *writer) {
        writer->beginObject(writer, "");
        BugsnagFeatureFlagsWriteCrashReport(writer, true);
        writer->endContainer(writer);
    });
    
    XCTAssertEqualObjects(object.allKeys, @[@"featureFlags"]);
    
    NSArray<NSDictionary *> *featureFlags = object[@"featureFlags"];
    XCTAssertEqual(featureFlags.count, 4);
    
    XCTAssertTrue([featureFlags[0][@"featureFlag"] isEqualToString: @"featureFlagA"]);
    XCTAssertTrue([featureFlags[0][@"variant"] isEqualToString: @"testingA2"]);
    
    XCTAssertTrue([featureFlags[1][@"featureFlag"] isEqualToString: @"featureFlagB"]);
    XCTAssertTrue([featureFlags[1][@"variant"] isEqualToString: @"testingB2"]);
    
    XCTAssertTrue([featureFlags[2][@"featureFlag"] isEqualToString: @"featureFlagD"]);
    XCTAssertTrue([featureFlags[2][@"variant"] isEqualToString: @"testingD"]);
    
    XCTAssertTrue([featureFlags[3][@"featureFlag"] isEqualToString: @"featureFlagC"]);
    XCTAssertTrue([featureFlags[3][@"variant"] isEqualToString: @"testingC2"]);
}

- (void)testClearShouldRemoveAllFlags {
    BSGAtomicFeatureFlagStore *store = [BSGAtomicFeatureFlagStore store];

    [store addFeatureFlag:@"featureFlagA" withVariant:@"testingA"];
    [store addFeatureFlag:@"featureFlagB" withVariant:@"testingB"];
    [store addFeatureFlag:@"featureFlagC" withVariant:@"testingC"];
    [store addFeatureFlag:@"featureFlagD" withVariant:@"testingD"];
    
    [store clear];
    
    NSDictionary<NSString *, id> *object = bsg_JSONObject(^(BSG_KSCrashReportWriter *writer) {
        writer->beginObject(writer, "");
        BugsnagFeatureFlagsWriteCrashReport(writer, true);
        writer->endContainer(writer);
    });
    
    XCTAssertEqualObjects(object.allKeys, @[@"featureFlags"]);
    XCTAssertTrue([store isEmpty]);
    
    NSArray<NSDictionary *> *featureFlags = object[@"featureFlags"];
    XCTAssertEqual(featureFlags.count, 0);
}

- (void)testClearByNameShouldRemoveASingleFlag {
    BSGAtomicFeatureFlagStore *store = [BSGAtomicFeatureFlagStore store];

    [store addFeatureFlag:@"featureFlagA" withVariant:@"testingA"];
    [store addFeatureFlag:@"featureFlagB" withVariant:@"testingB"];
    [store addFeatureFlag:@"featureFlagC" withVariant:@"testingC"];
    [store addFeatureFlag:@"featureFlagD" withVariant:@"testingD"];
    
    [store clear:@"featureFlagB"];
    
    NSDictionary<NSString *, id> *object = bsg_JSONObject(^(BSG_KSCrashReportWriter *writer) {
        writer->beginObject(writer, "");
        BugsnagFeatureFlagsWriteCrashReport(writer, true);
        writer->endContainer(writer);
    });
    
    XCTAssertEqualObjects(object.allKeys, @[@"featureFlags"]);
    
    NSArray<NSDictionary *> *featureFlags = object[@"featureFlags"];
    XCTAssertEqual(featureFlags.count, 3);
    
    XCTAssertTrue([featureFlags[0][@"featureFlag"] isEqualToString: @"featureFlagA"]);
    XCTAssertTrue([featureFlags[0][@"variant"] isEqualToString: @"testingA"]);
    
    XCTAssertTrue([featureFlags[1][@"featureFlag"] isEqualToString: @"featureFlagC"]);
    XCTAssertTrue([featureFlags[1][@"variant"] isEqualToString: @"testingC"]);
    
    XCTAssertTrue([featureFlags[2][@"featureFlag"] isEqualToString: @"featureFlagD"]);
    XCTAssertTrue([featureFlags[2][@"variant"] isEqualToString: @"testingD"]);
}

- (void)testClearByNameShouldRemoveAllFlagsIfNilIsProvided {
    BSGAtomicFeatureFlagStore *store = [BSGAtomicFeatureFlagStore store];

    [store addFeatureFlag:@"featureFlagA" withVariant:@"testingA"];
    [store addFeatureFlag:@"featureFlagB" withVariant:@"testingB"];
    [store addFeatureFlag:@"featureFlagC" withVariant:@"testingC"];
    [store addFeatureFlag:@"featureFlagD" withVariant:@"testingD"];
    
    [store clear:nil];
    
    NSDictionary<NSString *, id> *object = bsg_JSONObject(^(BSG_KSCrashReportWriter *writer) {
        writer->beginObject(writer, "");
        BugsnagFeatureFlagsWriteCrashReport(writer, true);
        writer->endContainer(writer);
    });
    
    XCTAssertEqualObjects(object.allKeys, @[@"featureFlags"]);
    XCTAssertTrue([store isEmpty]);
    
    NSArray<NSDictionary *> *featureFlags = object[@"featureFlags"];
    XCTAssertEqual(featureFlags.count, 0);
}

@end
