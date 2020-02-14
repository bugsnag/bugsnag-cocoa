//
//  BugsnagMetadataTest.m
//  Tests
//
//  Created by Robin Macharg on 28/01/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "BugsnagMetadata.h"
#import <XCTest/XCTest.h>

// MARK: - Expose tested-class internals

@interface BugsnagMetadataTest : XCTestCase <BugsnagMetadataDelegate>
@property BOOL delegateCalled;
@property BugsnagMetadata *metadata;
@end

@interface BugsnagMetadata ()
@property(atomic, strong) NSMutableDictionary *dictionary;
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

@implementation BugsnagMetadataTest

@synthesize delegateCalled;
@synthesize metadata;

-(void) setUp {
    metadata = [[BugsnagMetadata alloc] init];
    XCTAssertNil([metadata delegate]);
    metadata.delegate = self;
}

- (void)test_addAttribute_withName_creation {
    
    // Creation
    delegateCalled = NO;
    XCTAssertNotNil(metadata);
    XCTAssertFalse(delegateCalled, "Did not expect the delegate's metadataChanged: method to be called.");
    
    XCTAssertNotNil([metadata delegate]);
    XCTAssertFalse(delegateCalled, "Did not expect the delegate's metadataChanged: method to be called.");
}

- (void)test_addAttribute_withName_create_return {
    // Arbitrary tab name creates and returns itself
    delegateCalled = NO;
    NSMutableDictionary *tab = [metadata getTab:@"unknown"];
    XCTAssertNotNil(tab);
    XCTAssertEqual(tab.count, 0);
    XCTAssertEqual([[metadata toDictionary] count], 1);
    XCTAssertFalse(delegateCalled, "Expected the delegate's metadataChanged: method to be called.");
}

- (void)test_addAttribute_withName_named_tab_set {
    // Check that the arbitrary named tab was set.
    delegateCalled = NO;
    [metadata addAttribute:@"foo" withValue:@"aValue" toTabWithName:@"SecondTab"];
    XCTAssertEqual([[metadata toDictionary] count], 1);
    XCTAssertTrue(delegateCalled, "Expected the delegate's metadataChanged: method to be called.");
    
    [metadata addAttribute:@"foo" withValue:@"aValue" toTabWithName:@"FirstTab"];
    NSMutableDictionary *tab2 = [metadata getTab:@"FirstTab"];
    XCTAssertNotNil(tab2);
    XCTAssertEqual(tab2.count, 1);
    
    [metadata addAttribute:@"bar" withValue:@"anotherValue" toTabWithName:@"FirstTab"];
    tab2 = [metadata getTab:@"FirstTab"];
    XCTAssertEqual(tab2.count, 2);
    
    NSDictionary *dict = [metadata toDictionary];
    XCTAssertEqual([dict count], 2);
    
    delegateCalled = NO;
    [metadata clearTab:@"FirstTab"];
    tab2 = [metadata getTab:@"FirstTab"];
    XCTAssertEqual(tab2.count, 0);
    XCTAssertTrue(delegateCalled, "Expected the delegate's metadataChanged: method to be called.");
}

- (void)test_addAttribute_withName_invalid_values {
    NSMutableDictionary *tab2 = [metadata getTab:@"FirstTab"];
    
    // Adding invalid values should fail silently (and not add the value)
    delegateCalled = NO;
    [metadata addAttribute:@"bar" withValue:[DummyClass new] toTabWithName:@"FirstTab"];
    tab2 = [metadata getTab:@"FirstTab"];
    XCTAssertEqual(tab2.count, 0);
    XCTAssertTrue(delegateCalled, "Expected the delegate's metadataChanged: method to be called.");
    
    // Again, add valid value
    [metadata addAttribute:@"foo" withValue:@"aValue" toTabWithName:@"FirstTab"];
    tab2 = [metadata getTab:@"FirstTab"];
    XCTAssertNotNil(tab2);
    XCTAssertEqual(tab2.count, 1);

    // The same with null - should fail silently and not add
    delegateCalled = NO;
    [metadata addAttribute:@"bar" withValue:nil toTabWithName:@"FirstTab"];
    tab2 = [metadata getTab:@"FirstTab"];
    XCTAssertEqual(tab2.count, 1);
    XCTAssertTrue(delegateCalled, "Expected the delegate's metadataChanged: method to be called.");

    // Catch unchecked for delegate calls
    XCTAssertTrue(delegateCalled, "Missing metadataChanged: expectation.");
}

-(void) test_addMetadata_values {
    // Creation
    BugsnagMetadata *metadata = [[BugsnagMetadata alloc] init];
    XCTAssertNotNil(metadata);
    
    // Don't want to create a tab if none of the values are not valid
    [metadata addMetadataToSection:@"NewTab" values:@{@"aKey" : [DummyClass new]}];
    XCTAssertEqual([[metadata dictionary] count], 0);
    [metadata addMetadataToSection:@"NewTab" values:@{@"aKey" : [DummyClass new], @"anotherKey" : [DummyClass new]}];
    XCTAssertEqual([[metadata dictionary] count], 0);

    // Tab created if at least one value is valid
    [metadata addMetadataToSection:@"NewTab" values:@{@"aKey" : [DummyClass new], @"secondKey" : @12345}];
    XCTAssertEqual([[metadata dictionary] count], 1);
    NSMutableDictionary *tab = [metadata getTab:@"NewTab"];
    XCTAssertEqual([tab count], 1);
    [metadata addMetadataToSection:@"NewTab" values:@{@"thirdKey" : @"FooBarBaz"}];
    tab = [metadata getTab:@"NewTab"];
    XCTAssertEqual([tab count], 2);
    XCTAssertEqual([[metadata dictionary] count], 1);
    
    // Remove [NSNull null] values
    [metadata addMetadataToSection:@"NewTab" values:@{@"thirdKey" : [NSNull null]}];
    tab = [metadata getTab:@"NewTab"];
    XCTAssertEqual([tab count], 1);
    XCTAssertEqual([[metadata dictionary] count], 1);

    // Addition *AND* removal are possible in a single call
    [metadata addMetadataToSection:@"NewTab" values:@{@"secondKey" : [NSNull null], @"sixthKey" : @"mother"}];
    tab = [metadata getTab:@"NewTab"];
    XCTAssertEqual([tab count], 1);
    XCTAssertEqual([[metadata dictionary] count], 1);
    
    // Check delegate method gets called
    delegateCalled = NO;
    metadata.delegate = self;
    [metadata addMetadataToSection:@"OtherTab" values:@{@"key" : @"value"}];
    XCTAssertTrue(delegateCalled, "Expected the delegate's metadataChanged: method to be called.");
    delegateCalled = NO;
    [metadata addMetadataToSection:@"OtherTab" values:@{@"key" : [NSNull null]}];
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
    
    [metadata addMetadataToSection:@"invalidKeyTab" values:@{dummyObj : @"someValue"}];
    XCTAssertEqual(metadata.dictionary.count, 0);
    XCTAssertFalse(delegateCalled);
    
    // Once more with a delegate
    delegateCalled = NO;
    metadata.delegate = self;
    [metadata addMetadataToSection:@"invalidKeyTab" values:@{dummyObj : @"someValue"}];
    XCTAssertEqual(metadata.dictionary.count, 0);
    XCTAssertTrue(delegateCalled);
}

// MARK: - <BugsnagMetadataDelegate>

- (void)metadataChanged:(BugsnagMetadata * _Nonnull)metadata {
    delegateCalled = YES;
}

@end
