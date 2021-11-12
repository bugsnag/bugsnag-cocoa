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
    
    BSGFeatureFlagStoreAddFeatureFlag(store, @"featureA", @"enabled");
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(store),
                          (@[@{@"featureFlag": @"featureA", @"variant": @"enabled"}]));
    
    BSGFeatureFlagStoreAddFeatureFlags(store, @[[BugsnagFeatureFlag flagWithName:@"featureA"]]);
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(store),
                          @[@{@"featureFlag": @"featureA"}]);
    
    BSGFeatureFlagStoreAddFeatureFlag(store, @"featureB", nil);
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(store),
                          (@[@{@"featureFlag": @"featureA"},
                             @{@"featureFlag": @"featureB"}]));
    
    XCTAssertEqualObjects(BSGFeatureFlagStoreFromJSON(BSGFeatureFlagStoreToJSON(store)),
                          store);
    
    BSGFeatureFlagStoreClear(store, @"featureA");
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(store),
                          @[@{@"featureFlag": @"featureB"}]);
    
    BSGFeatureFlagStoreClear(store, nil);
    XCTAssertEqualObjects(BSGFeatureFlagStoreToJSON(store), @[]);
}

@end
