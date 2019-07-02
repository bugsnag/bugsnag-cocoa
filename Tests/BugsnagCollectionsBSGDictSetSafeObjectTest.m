//
//  BugsnagCollectionsBSGDictSetSafeObjectTest.m
//  Tests
//
//  Created by Paul Zabelin on 7/1/19.
//  Copyright © 2019 Bugsnag. All rights reserved.
//

@import XCTest;
#import "BugsnagCollections.h"

@interface BugsnagCollectionsBSGDictSetSafeObjectTest : XCTestCase
@property (nonatomic, strong) NSMutableDictionary *dict;
@end

@implementation BugsnagCollectionsBSGDictSetSafeObjectTest

- (void)setUp {
    self.dict = [@{} mutableCopy];
}

- (void)tearDown {
    self.dict = nil;
}

- (void)testBSGDictSetSafeObjectNil {
    BSGDictSetSafeObject(self.dict, nil, @"test");
    XCTAssertEqual(self.dict[@"test"], [NSNull null], @"should store NSNull for nil");
}

- (void)testBSGDictSetSafeObjectNotNil {
    BSGDictSetSafeObject(self.dict, @"example", @"test");
    XCTAssertEqualObjects(self.dict, @{@"test":@"example"}, @"should store example string for the given key");
}

@end
