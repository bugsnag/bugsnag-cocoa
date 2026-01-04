//
//  BSGJsonCollectionPathTests.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 02/01/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import "BSGTestCase.h"
#import "BSGJsonCollectionPath.h"

@interface BSGJsonCollectionPathTests : BSGTestCase

@property (nonatomic, strong) NSDictionary *data;

@end

@implementation BSGJsonCollectionPathTests

- (void)setUp {
    self.data = [self createTestData];
}

- (void)testIdentityPath {
    BSGJsonCollectionPath *collectionPath = [BSGJsonCollectionPath identityPath];
    
    NSArray *result = [collectionPath extractFromJSON:self.data];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.count, 1);
    XCTAssertEqualObjects((id)result[0], self.data);
}

- (void)testSimplePropertyPath {
    BSGJsonCollectionPath *collectionPath = [BSGJsonCollectionPath pathFromString:@"p1"];
    
    NSArray *result = [collectionPath extractFromJSON:self.data];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.count, 1);
    XCTAssertEqualObjects(result[0], @"v1");
}

- (void)testSimpleArrayPath {
    BSGJsonCollectionPath *collectionPath = [BSGJsonCollectionPath pathFromString:@"a1"];
    
    NSArray *result = [collectionPath extractFromJSON:self.data];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.count, 1);
    XCTAssertEqualObjects(result[0], self.data[@"a1"]);
}

- (void)testSimpleObjectPath {
    BSGJsonCollectionPath *collectionPath = [BSGJsonCollectionPath pathFromString:@"o1"];
    
    NSArray *result = [collectionPath extractFromJSON:self.data];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.count, 1);
    XCTAssertEqualObjects(result[0], self.data[@"o1"]);
}

- (void)testArrayIndexPath {
    BSGJsonCollectionPath *collectionPath = [BSGJsonCollectionPath pathFromString:@"a1.2"];
    
    NSArray *result = [collectionPath extractFromJSON:self.data];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.count, 1);
    XCTAssertEqualObjects(result[0], @"a1-2");
}

- (void)testArrayNegativeIndexPath {
    BSGJsonCollectionPath *collectionPath = [BSGJsonCollectionPath pathFromString:@"a1.-3"];
    
    NSArray *result = [collectionPath extractFromJSON:self.data];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.count, 1);
    XCTAssertEqualObjects(result[0], @"a1-2");
}

- (void)testPropertyInObjectPath {
    BSGJsonCollectionPath *collectionPath = [BSGJsonCollectionPath pathFromString:@"o1.o1-p1"];
    
    NSArray *result = [collectionPath extractFromJSON:self.data];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.count, 1);
    XCTAssertEqualObjects(result[0], @"o1-v1");
}

- (void)testIndexInObjectPath {
    BSGJsonCollectionPath *collectionPath = [BSGJsonCollectionPath pathFromString:@"o1.1"];
    
    NSArray *result = [collectionPath extractFromJSON:self.data];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.count, 1);
    XCTAssertEqualObjects(result[0], @"o1-1");
}

- (void)testNegativeIndexInObjectPath {
    BSGJsonCollectionPath *collectionPath = [BSGJsonCollectionPath pathFromString:@"o1.-2"];
    
    NSArray *result = [collectionPath extractFromJSON:self.data];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.count, 1);
    XCTAssertEqualObjects(result[0], @"o1--2");
}

- (void)testIndexInObjectArrayPath {
    BSGJsonCollectionPath *collectionPath = [BSGJsonCollectionPath pathFromString:@"o2.o2-a1.0"];
    
    NSArray *result = [collectionPath extractFromJSON:self.data];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.count, 1);
    XCTAssertEqualObjects(result[0], @"o2-a1-0");
}

- (void)testIndexInObjectArrayNotExistingPath {
    BSGJsonCollectionPath *collectionPath = [BSGJsonCollectionPath pathFromString:@"o2.o2-a1.1"];
    
    NSArray *result = [collectionPath extractFromJSON:self.data];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.count, 0);
}

- (void)testNumberValueInObjectPath {
    BSGJsonCollectionPath *collectionPath = [BSGJsonCollectionPath pathFromString:@"o2.o2-p1"];
    
    NSArray *result = [collectionPath extractFromJSON:self.data];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.count, 1);
    XCTAssertEqualObjects(result[0], @(42));
}

- (void)testWildcardObjectPath {
    BSGJsonCollectionPath *collectionPath = [BSGJsonCollectionPath pathFromString:@"o1.*"];
    
    NSArray *result = [collectionPath extractFromJSON:self.data];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.count, 5);
    // Results are sorted by key: "-2", "0", "1", "o1-p1", "o1-p2"
    XCTAssertEqualObjects(result[0], @"o1--2");
    XCTAssertEqualObjects(result[1], @"o1-0");
    XCTAssertEqualObjects(result[2], @"o1-1");
    XCTAssertEqualObjects(result[3], @"o1-v1");
    XCTAssertEqualObjects(result[4], @"o1-v2");
}

- (void)testWildcardArrayPath {
    BSGJsonCollectionPath *collectionPath = [BSGJsonCollectionPath pathFromString:@"a1.*"];
    
    NSArray *result = [collectionPath extractFromJSON:self.data];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.count, 5);
    // Array order is preserved: index 0, 1, 2, 3, 4
    XCTAssertEqualObjects(result[0], @"a1-0");
    XCTAssertEqualObjects(result[1], @"a1-1");
    XCTAssertEqualObjects(result[2], @"a1-2");
    XCTAssertEqualObjects(result[3], @"a1-3");
    XCTAssertEqualObjects(result[4], @"a1-4");
}

- (void)testWildcardIndexPath {
    BSGJsonCollectionPath *collectionPath = [BSGJsonCollectionPath pathFromString:@"*.1"];
    
    NSArray *result = [collectionPath extractFromJSON:self.data];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.count, 3);
    // Results are sorted by top-level key: "a1", "a2", "o1"
    XCTAssertEqualObjects(result[0], @"a1-1");
    XCTAssertEqualObjects(result[1], @"a2-1");
    XCTAssertEqualObjects(result[2], @"o1-1");
}

- (NSDictionary *)createTestData {
    return @{
        @"p1": @"v1",
        @"p2": @"v2",
        @"a1": @[@"a1-0", @"a1-1", @"a1-2", @"a1-3", @"a1-4"],
        @"o1": @{
            @"o1-p1": @"o1-v1",
            @"o1-p2": @"o1-v2",
            @"0": @"o1-0",
            @"1": @"o1-1",
            @"-2": @"o1--2",
        },
        @"a2": @[@"a2-0", @"a2-1"],
        @"o2": @{
            @"o2-p1": @(42),
            @"o2-a1": @[@"o2-a1-0"],
            @"o2-a2": @[]
        },
    };
}

@end

