//
//  BSGMemoryFeatureFlagStoreTests.m
//  Bugsnag
//
//  Created by Nick Dowell on 11/11/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "BSGTestCase.h"

#import "BSGMemoryFeatureFlagStore.h"

@interface BSGMemoryFeatureFlagStoreTests : BSGTestCase

@end

@implementation BSGMemoryFeatureFlagStoreTests

- (void)test {
    BSGMemoryFeatureFlagStore *store = [[BSGMemoryFeatureFlagStore alloc] init];
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(store), @[]);

    [store addFeatureFlag:@"featureC" withVariant:@"checked"];
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(store),
                          (@[@{@"featureFlag": @"featureC", @"variant": @"checked"}]));
    
    [store addFeatureFlag:@"featureA" withVariant:@"enabled"];
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(store),
                          (@[
                            @{@"featureFlag": @"featureC", @"variant": @"checked"},
                            @{@"featureFlag": @"featureA", @"variant": @"enabled"}
                          ]));

    [store addFeatureFlag:@"featureB" withVariant:nil];
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(store),
                          (@[
                            @{@"featureFlag": @"featureC", @"variant": @"checked"},
                            @{@"featureFlag": @"featureA", @"variant": @"enabled"},
                            @{@"featureFlag": @"featureB"}
                          ]));


    [store addFeatureFlags: @[[BugsnagFeatureFlag flagWithName:@"featureA"]]];
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(store),
                          (@[
                            @{@"featureFlag": @"featureC", @"variant": @"checked"},
                            @{@"featureFlag": @"featureA"},
                            @{@"featureFlag": @"featureB"},
                          ]));

    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(BSGFeatureFlagStoreFromJSON(BSGFeatureFlagStoreToJSON(store))),
                          BSGFeatureFlagStoreToJSON(store));
    
    [store clear: @"featureB"];
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(store),
                          (@[
                            @{@"featureFlag": @"featureC", @"variant": @"checked"},
                            @{@"featureFlag": @"featureA"}
                          ]));

    [store clear];
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(store), @[]);
}

- (void)testAddRemoveMany {
    // Tests that rebuildIfTooManyHoles works as expected

    BSGMemoryFeatureFlagStore *store = [[BSGMemoryFeatureFlagStore alloc] init];

    [store addFeatureFlag:@"blah" withVariant:@"testing"];
    for (int j = 0; j < 10; j++) {
        for (int i = 0; i < 1000; i++) {
            NSString *name = [NSString stringWithFormat:@"%d-%d", j, i];
            [store addFeatureFlag:name withVariant:nil];
            if (i < 999) {
                [store clear:name];
            }
        }
    }

    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(store),
                          (@[
                            @{@"featureFlag": @"blah", @"variant": @"testing"},
                            @{@"featureFlag": @"0-999"},
                            @{@"featureFlag": @"1-999"},
                            @{@"featureFlag": @"2-999"},
                            @{@"featureFlag": @"3-999"},
                            @{@"featureFlag": @"4-999"},
                            @{@"featureFlag": @"5-999"},
                            @{@"featureFlag": @"6-999"},
                            @{@"featureFlag": @"7-999"},
                            @{@"featureFlag": @"8-999"},
                            @{@"featureFlag": @"9-999"},
                          ]));
}

- (void)testAddFeatureFlagPerformance {
    BSGMemoryFeatureFlagStore *store = [[BSGMemoryFeatureFlagStore alloc] init];

    __auto_type block = ^{
        for (int i = 0; i < 1000; i++) {
            NSString *name = [NSString stringWithFormat:@"%d", i];
            [store addFeatureFlag:name withVariant:nil];
        }
    };

    block();

    [self measureBlock:block];
}

- (void)testDictionaryPerformance {
    // For comparision to show the best performance possible

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

    __auto_type block = ^{
        for (int i = 0; i < 1000; i++) {
            NSString *name = [NSString stringWithFormat:@"%d", i];
            [dictionary setObject:[NSNull null] forKey:name];
        }
    };

    block();

    [self measureBlock:block];
}

@end
