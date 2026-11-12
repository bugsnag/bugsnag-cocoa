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


- (void)testReplaceAllFlags {
    BSGMemoryFeatureFlagStore *store = [[BSGMemoryFeatureFlagStore alloc] init];
    [store addFeatureFlag:@"featureA" withVariant:@"enabled"];
    [store addFeatureFlag:@"featureB" withVariant:nil];

    [store replaceAllFlags:@[[BugsnagFeatureFlag flagWithName:@"featureC" variant:@"checked"],
                             [BugsnagFeatureFlag flagWithName:@"featureA"],
                             [BugsnagFeatureFlag flagWithName:@"featureC" variant:@"unchecked"]]];
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(store),
                          (@[
                            @{@"featureFlag": @"featureC", @"variant": @"unchecked"},
                            @{@"featureFlag": @"featureA"}
                          ]));

    [store replaceAllFlags:@[]];
    XCTAssertTrue(store.isEmpty);
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(store), @[]);
}

- (void)testAddFeatureFlagsWithDuplicateNamesKeepsFirstPositionAndLastVariant {
    BSGMemoryFeatureFlagStore *store = [[BSGMemoryFeatureFlagStore alloc] init];
    [store addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:@"A" variant:@"1"],
                             [BugsnagFeatureFlag flagWithName:@"B"],
                             [BugsnagFeatureFlag flagWithName:@"A" variant:@"2"]]];
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(store),
                          (@[@{@"featureFlag": @"A", @"variant": @"2"}, @{@"featureFlag": @"B"}]));

    [store addFeatureFlags:@[[BugsnagFeatureFlag flagWithName:@"C" variant:@"3"],
                             [BugsnagFeatureFlag flagWithName:@"A"]]];
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(store),
                          (@[@{@"featureFlag": @"A"}, @{@"featureFlag": @"B"}, @{@"featureFlag": @"C", @"variant": @"3"}]));

    // Clearing a name and adding it again puts it at the end
    [store clear:@"A"];
    [store addFeatureFlag:@"A" withVariant:@"4"];
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(store),
                          (@[@{@"featureFlag": @"B"}, @{@"featureFlag": @"C", @"variant": @"3"}, @{@"featureFlag": @"A", @"variant": @"4"}]));
}

- (void)testClearWithNilNameRemovesAllFlags {
    BSGMemoryFeatureFlagStore *store = [[BSGMemoryFeatureFlagStore alloc] init];
    [store addFeatureFlag:@"A" withVariant:@"1"];
    [store addFeatureFlag:@"B" withVariant:nil];
    [store clear:@"missing"];
    XCTAssertEqual(BSGFeatureFlagStoreToJSON(store).count, 2);

    [store clear:nil];
    XCTAssertTrue(store.isEmpty);
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(store), @[]);

    // The store is still usable after being cleared
    [store addFeatureFlag:@"C" withVariant:nil];
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(store), (@[@{@"featureFlag": @"C"}]));
}

- (void)testWithFlagsKeepsTheOrderAndAppliesTheDuplicateNameRule {
    NSArray<BugsnagFeatureFlag *> *flags = @[[BugsnagFeatureFlag flagWithName:@"B" variant:@"1"],
                                             [BugsnagFeatureFlag flagWithName:@"A"],
                                             [BugsnagFeatureFlag flagWithName:@"B" variant:@"2"],
                                             [BugsnagFeatureFlag flagWithName:@"C" variant:@""]];
    NSArray *expected = @[@{@"featureFlag": @"B", @"variant": @"2"},
                          @{@"featureFlag": @"A"},
                          @{@"featureFlag": @"C", @"variant": @""}];

    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON([BSGMemoryFeatureFlagStore withFlags:flags]), expected);
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(BSGFeatureFlagStoreWithFlags(flags)), expected);

    // Each call returns a new store
    BSGMemoryFeatureFlagStore *store = BSGFeatureFlagStoreWithFlags(flags);
    [store clear];
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(BSGFeatureFlagStoreWithFlags(flags)), expected);
}

- (void)testWithFlagsEmpty {
    XCTAssertTrue([BSGMemoryFeatureFlagStore withFlags:@[]].isEmpty);
    XCTAssertTrue(BSGFeatureFlagStoreWithFlags(@[]).isEmpty);
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(BSGFeatureFlagStoreWithFlags(@[])), @[]);
}

- (void)testFromJSONIgnoresInvalidItems {
    NSArray *json = @[@"not a dictionary",
                      @{@"variant": @"no name"},
                      @{@"featureFlag": @1},
                      @{@"featureFlag": @"A", @"variant": @2},
                      @{@"featureFlag": @"B", @"variant": @"b"}];
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(BSGFeatureFlagStoreFromJSON(json)),
                          (@[@{@"featureFlag": @"A"}, @{@"featureFlag": @"B", @"variant": @"b"}]));
    XCTAssertTrue(BSGFeatureFlagStoreFromJSON(@{@"featureFlag": @"A"}).isEmpty);
    XCTAssertTrue(BSGFeatureFlagStoreFromJSON(nil).isEmpty);
}

- (void)testCopyIsIndependent {
    BSGMemoryFeatureFlagStore *store = [[BSGMemoryFeatureFlagStore alloc] init];
    [store addFeatureFlag:@"A" withVariant:@"1"];
    BSGMemoryFeatureFlagStore *copy = [store copy];
    [store addFeatureFlag:@"B" withVariant:nil];
    [copy clear:@"A"];
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(store),
                          (@[@{@"featureFlag": @"A", @"variant": @"1"}, @{@"featureFlag": @"B"}]));
    XCTAssertTrue(copy.isEmpty);
}

@end
