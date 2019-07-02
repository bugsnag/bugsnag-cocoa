//
//  BugsnagCollectionsBSGDictInsertIfNotNilTest.m
//  Tests
//
//  Created by Paul Zabelin on 7/2/19.
//  Copyright © 2019 Bugsnag. All rights reserved.
//

@import XCTest;
#import "BugsnagCollections.h"

@interface BugsnagCollectionsBSGDictInsertIfNotNilTest : XCTestCase
@property (nonatomic, strong) NSMutableDictionary* dict;
@property (nonatomic, strong) NSString *key;
@end

@implementation BugsnagCollectionsBSGDictInsertIfNotNilTest

- (void)setUp {
    self.key = @"some key value";
    self.dict = [NSMutableDictionary dictionary];
}

- (void)tearDown {
    self.dict = nil;
    self.key = nil;
}

- (void)testBSGDictInsertIfNotNil_NotNil {
    id object = @"blah";
    BSGDictInsertIfNotNil(self.dict, object, self.key);
    XCTAssertEqual(self.dict[self.key], object, @"should be inserted");
}

- (void)testBSGDictInsertIfNotNil_Nil {
    BSGDictInsertIfNotNil(self.dict, nil, self.key);
    XCTAssertNil(self.dict[self.key], @"should not be inserted");
}

@end
