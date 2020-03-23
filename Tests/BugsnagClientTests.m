//
//  BugsnagClientTests.m
//  Tests
//
//  Created by Robin Macharg on 18/03/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "Bugsnag.h"
#import "BugsnagClient.h"
#import "BugsnagTestConstants.h"
#import <XCTest/XCTest.h>

@interface BugsnagClientTests : XCTestCase
@end

@interface Bugsnag ()
+ (BugsnagConfiguration *)configuration;
+ (BugsnagClient *)client;
@end

@interface BugsnagClient ()
- (void)orientationChanged:(NSNotification *)notif;
@end

@interface BugsnagBreadcrumb ()
- (NSDictionary *)objectValue;
@end

@implementation BugsnagClientTests

/**
 * A boilerplate helper method to setup Bugsnag
 */
-(void)setUpBugsnagWillCallNotify:(bool)willNotify {
    NSError *error;
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:&error];
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
        XCTAssertEqual(event.apiKey, DUMMY_APIKEY_32CHAR_1);
        
        // Grab the values that end up in the event for later comparison
        eventErrorClass = [event errorClass];
        eventErrorMessage = [event errorMessage];
        eventUnhandled = [event valueForKeyPath:@"handledState.unhandled"] ? YES : NO;
        eventSeverity = BSGFormatSeverity([event severity]);
    }];
    
    // Check that we can change it
    [Bugsnag notify:ex];

    NSDictionary *breadcrumb = [[[[Bugsnag client] configuration] breadcrumbs][1] objectValue];
    NSDictionary *metadata = [breadcrumb valueForKey:@"metaData"];
    
    XCTAssertEqualObjects([breadcrumb valueForKey:@"type"], @"error");
    XCTAssertEqualObjects([breadcrumb valueForKey:@"message"], eventErrorClass);
    XCTAssertEqualObjects([metadata valueForKey:@"errorClass"], eventErrorClass);
    XCTAssertEqualObjects([metadata valueForKey:@"message"], eventErrorMessage);
    XCTAssertEqual((bool)[metadata valueForKey:@"unhandled"], eventUnhandled);
    XCTAssertEqualObjects([metadata valueForKey:@"severity"], eventSeverity);
}

@end
