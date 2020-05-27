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
        [configuration addOnSendErrorBlock:^BOOL(BugsnagEvent *_Nonnull event) {
            return false;
        }];
    }
    [Bugsnag startWithConfiguration:configuration];
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
    [Bugsnag notify:ex block:^BOOL(BugsnagEvent * _Nonnull event) {
        XCTAssertEqualObjects(event.apiKey, DUMMY_APIKEY_32CHAR_1);

        // Grab the values that end up in the event for later comparison
        eventErrorClass = event.errors[0].errorClass;
        eventErrorMessage = event.errors[0].errorMessage;
        eventUnhandled = [event valueForKeyPath:@"handledState.unhandled"] ? YES : NO;
        eventSeverity = BSGFormatSeverity([event severity]);
        return true;
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

    XCTAssertEqualObjects([client user].id, @"Jiminy");
    XCTAssertEqualObjects([client user].name, @"Jiminy Cricket");
    XCTAssertEqualObjects([client user].email, @"jiminy@bugsnag.com");

    [client setUser:nil withEmail:nil andName:@"Jiminy Cricket"];

    XCTAssertNil([client user].id);
    XCTAssertEqualObjects([client user].name, @"Jiminy Cricket");
    XCTAssertNil([client user].email);
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

/**
 * Helper for asserting two BugsnagConfiguration objects are equal
 */
- (void)assertEqualConfiguration:(BugsnagConfiguration *)expected withActual:(BugsnagConfiguration *)actual {
    XCTAssertEqualObjects(expected.apiKey, actual.apiKey);
    XCTAssertEqualObjects(expected.appType, actual.appType);
    XCTAssertEqualObjects(expected.appVersion, actual.appVersion);
    XCTAssertEqual(expected.autoDetectErrors, actual.autoDetectErrors);
    XCTAssertEqual(expected.autoTrackSessions, actual.autoTrackSessions);
    XCTAssertEqualObjects(expected.bundleVersion, actual.bundleVersion);
    XCTAssertEqual(expected.context, actual.context);
    XCTAssertEqual(expected.enabledBreadcrumbTypes, actual.enabledBreadcrumbTypes);
    XCTAssertEqual(expected.enabledErrorTypes.cppExceptions, actual.enabledErrorTypes.cppExceptions);
    XCTAssertEqual(expected.enabledErrorTypes.machExceptions, actual.enabledErrorTypes.machExceptions);
    XCTAssertEqual(expected.enabledErrorTypes.signals, actual.enabledErrorTypes.signals);
    XCTAssertEqual(expected.enabledErrorTypes.unhandledExceptions, actual.enabledErrorTypes.unhandledExceptions);
    XCTAssertEqual(expected.enabledErrorTypes.unhandledRejections, actual.enabledErrorTypes.unhandledRejections);
    XCTAssertEqual(expected.enabledErrorTypes.ooms, actual.enabledErrorTypes.ooms);
    XCTAssertEqual(expected.enabledReleaseStages, actual.enabledReleaseStages);
    XCTAssertEqualObjects(expected.endpoints.notify, actual.endpoints.notify);
    XCTAssertEqualObjects(expected.endpoints.sessions, actual.endpoints.sessions);
    XCTAssertEqual(expected.maxBreadcrumbs, actual.maxBreadcrumbs);
    XCTAssertEqual(expected.persistUser, actual.persistUser);
    XCTAssertEqual([expected.redactedKeys count], [actual.redactedKeys count]);
    XCTAssertEqualObjects([expected.redactedKeys allObjects][0], [actual.redactedKeys allObjects][0]);
    XCTAssertEqualObjects(expected.releaseStage, actual.releaseStage);
    XCTAssertEqual(expected.sendThreads, actual.sendThreads);
}

/**
 * Test creating a client using "startWithApiKey" uses the default configuration values
 */
- (void)testClientStartWithApiKeyMatchesDefaultConfiguration {
    BugsnagConfiguration *defaultConfig = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];

    [Bugsnag startWithApiKey:DUMMY_APIKEY_32CHAR_1];
    BugsnagConfiguration *config = [Bugsnag configuration];

    [self assertEqualConfiguration:defaultConfig withActual:config];
}

/**
 * After starting Bugsnag, any changes to the supplied Configuration should be ignored
 * Instead it should be changed by mutating the returned Configuration from "[Bugsnag configuration]"
 */
- (void)testChangesToConfigurationAreIgnoredAfterCallingStart {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    // Take a copy of our Configuration object so we can compare with it later
    BugsnagConfiguration *initialConfig = [config copy];

    [Bugsnag startWithConfiguration:config];

    // Modify some arbitrary properties
    config.persistUser = !config.persistUser;
    config.maxBreadcrumbs = config.maxBreadcrumbs * 2;
    config.appVersion = @"99.99.99";

    // Ensure the changes haven't been reflected in our copy
    XCTAssertNotEqual(initialConfig.persistUser, config.persistUser);
    XCTAssertNotEqual(initialConfig.maxBreadcrumbs, config.maxBreadcrumbs);
    XCTAssertNotEqualObjects(initialConfig.appVersion, config.appVersion);

    BugsnagConfiguration *configAfter = [Bugsnag configuration];

    [self assertEqualConfiguration:initialConfig withActual:configAfter];
}

@end
