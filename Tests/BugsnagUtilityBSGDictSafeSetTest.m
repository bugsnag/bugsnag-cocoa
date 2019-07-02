//
//  BugsnagUtilityTest.m
//  Tests
//
//  Created by Paul Zabelin on 7/1/19.
//  Copyright © 2019 Bugsnag. All rights reserved.
//

@import XCTest;
#import "BugsnagUtility.h"

@interface BugsnagUtilityBSGDictSafeSetTest : XCTestCase
@property (nonatomic, strong) NSMutableDictionary *dict;
@end

@implementation BugsnagUtilityBSGDictSafeSetTest

- (void)setUp {
    self.dict = [@{} mutableCopy];
}

- (void)tearDown {
    self.dict = nil;
}

- (void)testBSGDictSafeSetNil {
    BSGDictSafeSet(self.dict, @"test", nil);
    XCTAssertEqual(self.dict[@"test"], [NSNull null], @"should store NSNull for nil");
}

- (void)testBSGDictSafeSetNotNil {
    BSGDictSafeSet(self.dict, @"test", @"example");
    XCTAssertEqual(self.dict[@"test"], @"example", @"should store example string");
}

@end
