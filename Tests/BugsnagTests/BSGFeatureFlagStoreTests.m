//
//  BSGFeatureFlagStoreTests.m
//  Bugsnag
//
//  Created by Nick Dowell on 11/11/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "BSGFeatureFlagStore.h"

#import <XCTest/XCTest.h>

@interface BSGFeatureFlagStoreTests : XCTestCase

@end

@implementation BSGFeatureFlagStoreTests

- (void)test {
    BSGFeatureFlagStore *store = [[BSGFeatureFlagStore alloc] init];
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(store), @[]);

    BSGFeatureFlagStoreAddFeatureFlag(store, @"featureC", @"checked");
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(store),
                          (@[@{@"featureFlag": @"featureC", @"variant": @"checked"}]));
    
    BSGFeatureFlagStoreAddFeatureFlag(store, @"featureA", @"enabled");
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(store),
                          (@[
                            @{@"featureFlag": @"featureC", @"variant": @"checked"},
                            @{@"featureFlag": @"featureA", @"variant": @"enabled"}
                          ]));

    BSGFeatureFlagStoreAddFeatureFlag(store, @"featureB", nil);
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(store),
                          (@[
                            @{@"featureFlag": @"featureC", @"variant": @"checked"},
                            @{@"featureFlag": @"featureA", @"variant": @"enabled"},
                            @{@"featureFlag": @"featureB"}
                          ]));


    BSGFeatureFlagStoreAddFeatureFlags(store, @[[BugsnagFeatureFlag flagWithName:@"featureA"]]);
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(store),
                          (@[
                            @{@"featureFlag": @"featureC", @"variant": @"checked"},
                            @{@"featureFlag": @"featureB"},
                            @{@"featureFlag": @"featureA"}
                          ]));

    XCTAssertEqualObjects(BSGFeatureFlagStoreFromJSON(BSGFeatureFlagStoreToJSON(store)),
                          store);
    
    BSGFeatureFlagStoreClear(store, @"featureB");
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(store),
                          (@[
                            @{@"featureFlag": @"featureC", @"variant": @"checked"},
                            @{@"featureFlag": @"featureA"}
                          ]));

    BSGFeatureFlagStoreClear(store, nil);
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(store), @[]);
}

@end
