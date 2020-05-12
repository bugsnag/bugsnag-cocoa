//
//  BugsnagEventPersistenceTest.m
//  Tests
//
//  Created by Jamie Lynch on 11/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "BugsnagEvent.h"
#import "BugsnagAppWithState.h"

@interface BugsnagEvent ()
- (instancetype)initWithKSReport:(NSDictionary *)report;
@end

@interface BugsnagEventPersistLoadTest : XCTestCase
@property NSDictionary *eventData;
@end

/**
 * Verifies that a BugsnagEvent can load information persisted from a handled error.
 *
 * Handled errors store information in the user section of the KSCrashReport. The
 * stored information matches the JSON schema of an Error Reporting API payload.
 */
@implementation BugsnagEventPersistLoadTest

- (void)setUp {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"report" ofType:@"json"];
    NSString *contents = [NSString stringWithContentsOfFile:path
                                                   encoding:NSUTF8StringEncoding
                                                      error:nil];
    NSData *contentData = [contents dataUsingEncoding:NSUTF8StringEncoding];
    self.eventData = [NSJSONSerialization JSONObjectWithData:contentData
                                                     options:0
                                                       error:nil];
}

/**
 * Constructs JSON data used to build a BugsnagEvent from a KSCrashReport
 * @param overrides the overrides that would be persisted in the user section of the report
 * @return a representation of the persisted JSON
 */
- (BugsnagEvent *)generateEventWithOverrides:(NSDictionary *)overrides {
    NSMutableDictionary *event = [self.eventData mutableCopy];
    if (overrides != nil) {
        event[@"user"] = [event[@"user"] mutableCopy];
        event[@"user"][@"event"] = overrides;
    }
    return [[BugsnagEvent alloc] initWithKSReport:event];
}

- (void)testEmptyDict {
    BugsnagEvent *event = [self generateEventWithOverrides:nil];
    XCTAssertNotNil(event);
}

- (void)testContextOverride {
    BugsnagEvent *event = [self generateEventWithOverrides:@{
            @"context": @"Making network request"
    }];
    XCTAssertEqualObjects(@"Making network request", event.context);
}

@end
