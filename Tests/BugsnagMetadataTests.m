//
//  BugsnagMetadataTests.m
//  Tests
//
//  Created by Robin Macharg on 12/02/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "BugsnagMetadata.h"
#import "BugsnagMetadataInternal.h"

// MARK: - Expose tested-class internals

@interface BugsnagMetadataTests : XCTestCase
@property BOOL delegateCalled;
@property BugsnagMetadata *metadata;
@end

// MARK: - DummyClass

@interface DummyClass : NSObject <NSCopying> // <NSCopying> allows it to be used as a dictionary key
@property NSString *name;
@end

@implementation DummyClass
@synthesize name;
- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    DummyClass *copy = [DummyClass new];
    copy.name = self.name;
    return copy;
}

@end

// MARK: - Tests

@implementation BugsnagMetadataTests

@synthesize delegateCalled;
@synthesize metadata;

-(void) setUp {
    metadata = [[BugsnagMetadata alloc] init];

    __weak __typeof__(self) weakSelf = self;
    [metadata addObserverUsingBlock:^(BugsnagStateEvent *event) {
        weakSelf.delegateCalled = YES;
    }];
}

- (void)test_addMetadata_withName_creation {
    // Creation
    delegateCalled = NO;
    XCTAssertNotNil(metadata);
    XCTAssertFalse(delegateCalled, "Did not expect the delegate's metadataChanged: method to be called.");
}

- (void)test_addMetadata_withName_create_return {
    // Arbitrary tab name creates and returns itself
    delegateCalled = NO;
    NSMutableDictionary *tab = [[metadata getMetadataFromSection:@"unknown"] mutableCopy];
    XCTAssertNil(tab);
    XCTAssertEqual([[metadata toDictionary] count], 0);
    XCTAssertFalse(delegateCalled, "Didn't expect the delegate's metadataChanged: method to be called.");
}

- (void)test_addMetadata_withName_named_tab_set {
    // Check that the arbitrary named tab was set.
    delegateCalled = NO;
    [metadata addMetadata:@"aValue" withKey:@"foo" toSection:@"SecondTab"];
    XCTAssertEqual([[metadata toDictionary] count], 1);
    XCTAssertTrue(delegateCalled, "Expected the delegate's metadataChanged: method to be called.");
    
    [metadata addMetadata:@"aValue" withKey:@"foo" toSection:@"FirstTab"];
    NSMutableDictionary *tab2 = [[metadata getMetadataFromSection:@"FirstTab"] mutableCopy];
    XCTAssertNotNil(tab2);
    XCTAssertEqual(tab2.count, 1);
    
    [metadata addMetadata:@"anotherValue" withKey:@"bar" toSection:@"FirstTab"];
    tab2 = [[metadata getMetadataFromSection:@"FirstTab"] mutableCopy];
    XCTAssertEqual(tab2.count, 2);
    
    NSDictionary *dict = [metadata toDictionary];
    XCTAssertEqual([dict count], 2);
    
    delegateCalled = NO;
    [metadata clearMetadataFromSection:@"FirstTab"];
    tab2 = [[metadata getMetadataFromSection:@"FirstTab"] mutableCopy];
    XCTAssertEqual(tab2.count, 0);
    XCTAssertTrue(delegateCalled, "Expected the delegate's metadataChanged: method to be called.");
}

- (void)test_addMetadata_withName_invalid_values {
    NSMutableDictionary *tab2 = [[metadata getMetadataFromSection:@"FirstTab"] mutableCopy];
    
    // Adding invalid values should fail silently (and not add the value)
    delegateCalled = NO;
    [metadata addMetadata:[DummyClass new] withKey:@"bar" toSection:@"FirstTab"];
    tab2 = [[metadata getMetadataFromSection:@"FirstTab"] mutableCopy];
    XCTAssertEqual(tab2.count, 0);
    XCTAssertFalse(delegateCalled, "Did not expect the delegate's metadataChanged: method to be called.");
    
    // Again, add valid value
    [metadata addMetadata:@"aValue" withKey:@"foo" toSection:@"FirstTab"];
    tab2 = [[metadata getMetadataFromSection:@"FirstTab"] mutableCopy];
    XCTAssertNotNil(tab2);
    XCTAssertEqual(tab2.count, 1);

    // Adding null - should remove the key
    delegateCalled = NO;
    [metadata addMetadata:nil withKey:@"bar" toSection:@"FirstTab"];
    tab2 = [[metadata getMetadataFromSection:@"FirstTab"] mutableCopy];
    XCTAssertEqual(tab2.count, 1);
    XCTAssertTrue(delegateCalled, "Expected the delegate's metadataChanged: method to be called.");
}

- (void) test_addMetadata_values {
    // Creation
    BugsnagMetadata *metadata = [BugsnagMetadata new];
    XCTAssertNotNil(metadata);
    
    // Don't want to create a tab if none of the values are not valid
    [metadata addMetadata:@{@"aKey" : [DummyClass new]} toSection:@"NewTab"];
    XCTAssertEqual([[metadata dictionary] count], 0);
    [metadata addMetadata:@{@"aKey" : [DummyClass new], @"anotherKey" : [DummyClass new]} toSection:@"NewTab"];
    XCTAssertEqual([[metadata dictionary] count], 0);

    // Tab created if at least one value is valid
    [metadata addMetadata:@{
        @"aKey" : [DummyClass new],
        @"secondKey" : @12345}
                toSection:@"NewTab"];
    XCTAssertEqual([[metadata dictionary] count], 1);
    NSMutableDictionary *tab = [[metadata getMetadataFromSection:@"NewTab"] mutableCopy];
    XCTAssertEqual([tab count], 1);

    [metadata addMetadata:@{ @"thirdKey" : @"FooBarBaz" }
                toSection:@"NewTab"];

    tab = [[metadata getMetadataFromSection:@"NewTab"] mutableCopy];
    XCTAssertEqual([tab count], 2);
    XCTAssertEqual([[metadata dictionary] count], 1);
    
    // Remove [NSNull null] values
    [metadata addMetadata:@{@"thirdKey" : [NSNull null]} toSection:@"NewTab"];
    tab = [[metadata getMetadataFromSection:@"NewTab"] mutableCopy];
    XCTAssertEqual([tab count], 1);
    XCTAssertEqual([[metadata dictionary] count], 1);

    // Addition *AND* removal are possible in a single call
    [metadata addMetadata:@{@"secondKey" : [NSNull null], @"sixthKey" : @"mother"} toSection:@"NewTab"];
    tab = [[metadata getMetadataFromSection:@"NewTab"] mutableCopy];
    XCTAssertEqual([tab count], 1);
    XCTAssertEqual([[metadata dictionary] count], 1);
    
    // Check delegate method gets called
    delegateCalled = NO;
    __weak __typeof__(self) weakSelf = self;
    [metadata addObserverUsingBlock:^(BugsnagStateEvent *event) {
        weakSelf.delegateCalled = YES;
    }];
    [metadata addMetadata:@{@"key" : @"value"} toSection:@"OtherTab"];
    XCTAssertTrue(delegateCalled, "Expected the delegate's metadataChanged: method to be called.");
    delegateCalled = NO;
    [metadata addMetadata:@{@"key" : [NSNull null]} toSection:@"OtherTab"];
    XCTAssertTrue(delegateCalled, "Expected the delegate's metadataChanged: method to be called.");
}

-(void) test_addMetadata_values_invalid_key {
    BugsnagMetadata *metadata = [[BugsnagMetadata alloc] init];
    XCTAssertNotNil(metadata);
    XCTAssertEqual(metadata.dictionary.count, 0);

    // Check for invalid keys
    delegateCalled = NO;
    DummyClass *dummyObj = [DummyClass new];
    dummyObj.name = @"aName";
    
    [metadata addMetadata:@{dummyObj : @"someValue"} toSection:@"invalidKeyTab"];
    XCTAssertEqual(metadata.dictionary.count, 0);
    XCTAssertFalse(delegateCalled);
    
    // Once more with a delegate
    delegateCalled = NO;
    __weak __typeof__(self) weakSelf = self;
    [metadata addObserverUsingBlock:^(BugsnagStateEvent *event) {
        weakSelf.delegateCalled = YES;
    }];
    [metadata addMetadata:@{dummyObj : @"someValue"} toSection:@"invalidKeyTab"];
    XCTAssertEqual(metadata.dictionary.count, 0);
    XCTAssertFalse(delegateCalled);
}

- (void)testDeepCopyWithZone {
    
    BugsnagMetadata *metadata = [BugsnagMetadata new];
    [metadata addMetadata:@"myKey" withKey:@"myValue" toSection:@"section1"];
    
    BugsnagMetadata *clone = [metadata deepCopy];
    XCTAssertNotEqual(metadata, clone);
    
    // Until/unless it's decided otherwise the copy is a shallow one.
    XCTAssertEqualObjects([metadata getMetadataFromSection:@"section1"], [clone getMetadataFromSection:@"section1"]);
}

-(void)testClearMetadataInSectionWithKey {
    BugsnagMetadata *metadata = [BugsnagMetadata new];
    [metadata addMetadata:@"myValue1" withKey:@"myKey1" toSection:@"section1"];
    [metadata addMetadata:@"myValue2" withKey:@"myKey2" toSection:@"section1"];
    [metadata addMetadata:@"myValue3" withKey:@"myKey3" toSection:@"section2"];
    
    XCTAssertEqual([[metadata getMetadataFromSection:@"section1"] count], 2);
    XCTAssertEqual([[metadata getMetadataFromSection:@"section2"] count], 1);
    
    [metadata clearMetadataFromSection:@"section1" withKey:@"myKey1"];
    XCTAssertEqual([[metadata getMetadataFromSection:@"section1"] count], 1);
    XCTAssertNil([[metadata getMetadataFromSection:@"section1"] valueForKey:@"myKey1"]);
    XCTAssertEqual([[metadata getMetadataFromSection:@"section1"] valueForKey:@"myKey2"], @"myValue2");
    
    // The short whole-section version
    // Existing section
    [metadata clearMetadataFromSection:@"section2"];
    XCTAssertNil([metadata getMetadataFromSection:@"section2"]);
    XCTAssertEqual([[metadata getMetadataFromSection:@"section1"] valueForKey:@"myKey2"], @"myValue2");
    
    // nonexistent sections
    [metadata clearMetadataFromSection:@"section3"];
    
    // Add it back in, but different
    [metadata  addMetadata:@"myValue4" withKey:@"myKey4" toSection:@"section2"];
    XCTAssertEqual([[metadata getMetadataFromSection:@"section2"] valueForKey:@"myKey4"], @"myValue4");
}

- (void)testGetMetadataSectionKey {
    BugsnagMetadata *metadata = [BugsnagMetadata new];
    [metadata addMetadata:@"myValue1" withKey:@"myKey1" toSection:@"section1"];
    [metadata addMetadata:@"myValue2" withKey:@"myKey2" toSection:@"section1"];
    [metadata addMetadata:@"myValue3" withKey:@"myKey3" toSection:@"section2"];
    
    // Test known values
    XCTAssertEqual([metadata getMetadataFromSection:@"section1" withKey:@"myKey1"], @"myValue1");
    XCTAssertEqual([metadata getMetadataFromSection:@"section1" withKey:@"myKey2"], @"myValue2");
    
    // unknown values
    XCTAssertNil([metadata getMetadataFromSection:@"sections1" withKey:@"noKey"]);
    XCTAssertNil([metadata getMetadataFromSection:@"noSection" withKey:@"noKey"]);
}

// MARK: - <BugsnagMetadataDelegate>
- (void)testMetadataMutability {
    BugsnagMetadata *metadata = [BugsnagMetadata new];

    // Immutable in, mutable out
    [metadata addMetadata:@{@"foo" : @"bar"} toSection:@"section1"];
    NSObject *metadata1 = [metadata getMetadataFromSection:@"section1"];
    XCTAssertTrue([metadata1 isKindOfClass:[NSMutableDictionary class]]);

    // Mutable in, mutable out
    [metadata addMetadata:[@{@"foo" : @"bar"} mutableCopy] toSection:@"section2"];
    NSObject *metadata2 = [metadata getMetadataFromSection:@"section2"];
    XCTAssertTrue([metadata2 isKindOfClass:[NSMutableDictionary class]]);
}

- (void)testSanitizeSection {
    BugsnagMetadata *metadata = [[BugsnagMetadata alloc] initWithDictionary:@{
            @"custom": [NSNull null],
            @"foo": @{
                    @"bar": @YES
            }
    }];
    XCTAssertEqual(1, [metadata.dictionary count]);
    XCTAssertTrue([metadata getMetadataFromSection:@"foo" withKey:@"bar"]);
}

- (void)testSanitizeSectionValue {
    BugsnagMetadata *metadata = [[BugsnagMetadata alloc] initWithDictionary:@{
            @"foo": @{
                    @"bar": @YES,
                    @"custom": [NSNull null]
            }
    }];
    XCTAssertEqual(1, [metadata.dictionary count]);
    XCTAssertTrue([metadata getMetadataFromSection:@"foo" withKey:@"bar"]);
}

- (void)testSanitizeNestedDict {
    BugsnagMetadata *metadata = [[BugsnagMetadata alloc] initWithDictionary:@{
            @"foo": @{
                    @"bar": @YES,
                    @"custom": @{
                            @"some_val": [NSNull null]
                    }
            }
    }];
    XCTAssertEqual(1, [metadata.dictionary count]);
    XCTAssertEqualObjects(@{}, [metadata getMetadataFromSection:@"foo" withKey:@"custom"]);
}

- (void)testSanitizeNestedArray {
    BugsnagMetadata *metadata = [[BugsnagMetadata alloc] initWithDictionary:@{
            @"foo": @{
                    @"bar": @YES,
                    @"custom": @[[NSNull null], @"foo"]
            }
    }];
    XCTAssertEqual(1, [metadata.dictionary count]);
    XCTAssertEqualObjects(@[@"foo"], [metadata getMetadataFromSection:@"foo" withKey:@"custom"]);
}

- (void)testSanitizeNestedArrayDict {
    BugsnagMetadata *metadata = [[BugsnagMetadata alloc] initWithDictionary:@{
            @"foo": @{
                    @"bar": @[
                            @[
                                    @{ @"custom": [NSNull null] }
                            ]
                    ]
            }
    }];
    XCTAssertEqual(1, [metadata.dictionary count]);
    NSArray *bar = [metadata getMetadataFromSection:@"foo" withKey:@"bar"];
    NSDictionary *nestedDict = bar[0][0];
    XCTAssertEqual(0, [nestedDict count]);
}

@end
