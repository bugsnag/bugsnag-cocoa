//
//  BugsnagClientTests.m
//  Tests
//
//  Created by Robin Macharg on 18/03/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "Bugsnag.h"
#import "BugsnagBreadcrumbs.h"
#import "BugsnagClient.h"
#import "BugsnagClientInternal.h"
#import "BugsnagTestConstants.h"
#import "BugsnagKeys.h"
#import "BugsnagUser.h"
#import <XCTest/XCTest.h>

@interface BugsnagClientTests : XCTestCase
@end

@interface Bugsnag ()
+ (BugsnagConfiguration *)configuration;
+ (BugsnagClient *)client;
@end

@interface BugsnagClient ()
- (void)orientationChanged:(NSNotification *)notif;
@property (nonatomic, strong) BugsnagMetadata *metadata;
@end

@interface BugsnagBreadcrumb ()
- (NSDictionary *)objectValue;
@end

@interface BugsnagConfiguration ()
@property(readonly, strong, nullable) BugsnagBreadcrumbs *breadcrumbs;
@property(readwrite, retain, nullable) BugsnagMetadata *metadata;
@end

NSString *BSGFormatSeverity(BSGSeverity severity);

@implementation BugsnagClientTests

/**
 * A boilerplate helper method to setup Bugsnag
 */
-(void)setUpBugsnagWillCallNotify:(bool)willNotify {
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    if (willNotify) {
        [configuration addOnSendBlock:^bool(BugsnagEvent * _Nonnull event) { return false; }];
    }
    [Bugsnag startBugsnagWithConfiguration:configuration];
}

/**
 * Handled events leave a breadcrumb when notify() is called.  Test that values are inserted
 * correctly.
 */
- (void)testAutomaticNotifyBreadcrumbData {
    
    [self setUpBugsnagWillCallNotify:false];

    NSException *ex = [[NSException alloc] initWithName:@"myName" reason:@"myReason1" userInfo:nil];
    
    __block NSString *eventErrorClass;
    __block NSString *eventErrorMessage;
    __block BOOL eventUnhandled;
    __block NSString *eventSeverity;
    
    // Check that the event is passed the apiKey
    [Bugsnag notify:ex block:^(BugsnagEvent * _Nonnull event) {
        XCTAssertEqualObjects(event.apiKey, DUMMY_APIKEY_32CHAR_1);
        
        // Grab the values that end up in the event for later comparison
        eventErrorClass = event.errors[0].errorClass;
        eventErrorMessage = event.errors[0].errorMessage;
        eventUnhandled = [event valueForKeyPath:@"handledState.unhandled"] ? YES : NO;
        eventSeverity = BSGFormatSeverity([event severity]);
    }];
    
    // Check that we can change it
    [Bugsnag notify:ex];

    NSDictionary *breadcrumb = [[[[Bugsnag client] configuration] breadcrumbs][1] objectValue];
    NSDictionary *metadata = [breadcrumb valueForKey:@"metaData"];
    
    XCTAssertEqualObjects([breadcrumb valueForKey:@"type"], @"error");
    XCTAssertEqualObjects([breadcrumb valueForKey:@"name"], eventErrorClass);
    XCTAssertEqualObjects([metadata valueForKey:@"errorClass"], eventErrorClass);
    XCTAssertEqualObjects([metadata valueForKey:@"name"], eventErrorMessage);
    XCTAssertEqual((bool)[metadata valueForKey:@"unhandled"], eventUnhandled);
    XCTAssertEqualObjects([metadata valueForKey:@"severity"], eventSeverity);
}

/**
 * Test that Client inherits metadata from Configuration on init()
 */
- (void) testClientConfigurationHaveSeparateMetadata {
    [self setUpBugsnagWillCallNotify:false];
    
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    [configuration addMetadata:@{@"exampleKey" : @"exampleValue"} toSection:@"exampleSection"];
    
    BugsnagClient *client = [[BugsnagClient alloc] initWithConfiguration:configuration];
    
    // We expect that the client metadata is the same as the configuration's to start with
    XCTAssertEqualObjects([client getMetadataFromSection:@"exampleSection" withKey:@"exampleKey"],
                          [configuration getMetadataFromSection:@"exampleSection" withKey:@"exampleKey"]);
    XCTAssertNil([client getMetadataFromSection:@"aSection" withKey:@"foo"]);
    [client addMetadata:@{@"foo" : @"bar"} withKey:@"aDict" toSection:@"aSection"];
    XCTAssertNotNil([client getMetadataFromSection:@"aSection" withKey:@"aDict"]);
    
    // Updates to Configuration should not affect Client
    [configuration addMetadata:@{@"exampleKey2" : @"exampleValue2"} toSection:@"exampleSection2"];
    XCTAssertNil([client getMetadataFromSection:@"exampleSection2" withKey:@"exampleKey2"]);
    
    // Updates to Client should not affect Configuration
    [client addMetadata:@{@"exampleKey3" : @"exampleValue3"} toSection:@"exampleSection3"];
    XCTAssertNil([configuration getMetadataFromSection:@"exampleSection3" withKey:@"exampleKey3"]);
}

/**
 * Test that user info is stored and retreived correctly
 */
- (void) testUserInfoStorageRetrieval {
    [self setUpBugsnagWillCallNotify:false];
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    BugsnagClient *client = [[BugsnagClient alloc] initWithConfiguration:configuration];

    [client setUser:@"Jiminy" withEmail:@"jiminy@bugsnag.com" andName:@"Jiminy Cricket"];
    
    XCTAssertEqualObjects([client.metadata getMetadataFromSection:BSGKeyUser withKey:BSGKeyId], @"Jiminy");
    XCTAssertEqualObjects([client.metadata getMetadataFromSection:BSGKeyUser withKey:BSGKeyName], @"Jiminy Cricket");
    XCTAssertEqualObjects([client.metadata getMetadataFromSection:BSGKeyUser withKey:BSGKeyEmail], @"jiminy@bugsnag.com");

    XCTAssertEqualObjects([client user].userId, @"Jiminy");
    XCTAssertEqualObjects([client user].name, @"Jiminy Cricket");
    XCTAssertEqualObjects([client user].emailAddress, @"jiminy@bugsnag.com");
    
    [client setUser:nil withEmail:nil andName:@"Jiminy Cricket"];
    
    XCTAssertNil([client user].userId);
    XCTAssertEqualObjects([client user].name, @"Jiminy Cricket");
    XCTAssertNil([client user].emailAddress);
}

- (void)testMetadataMutability {
    [self setUpBugsnagWillCallNotify:false];
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    BugsnagClient *client = [[BugsnagClient alloc] initWithConfiguration:configuration];
    
    // Immutable in, mutable out
    [client addMetadata:@{@"foo" : @"bar"} toSection:@"section1"];
    NSObject *metadata1 = [client getMetadataFromSection:@"section1"];
    XCTAssertTrue([metadata1 isKindOfClass:[NSMutableDictionary class]]);
    
    // Mutable in, mutable out
    [client addMetadata:[@{@"foo" : @"bar"} mutableCopy] toSection:@"section2"];
    NSObject *metadata2 = [client getMetadataFromSection:@"section2"];
    XCTAssertTrue([metadata2 isKindOfClass:[NSMutableDictionary class]]);
}

@end
