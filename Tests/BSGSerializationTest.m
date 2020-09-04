//
//  BSGSerializationTest.m
//  Bugsnag-iOSTests
//
//  Created by Karl Stenerud on 04.09.20.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "BSGSerialization.h"

@interface BSGSerializationTest : XCTestCase

@end

@implementation BSGSerializationTest

- (void)testDeserializeJSONBadData {
    id dict = BSGDeserializeJson("{2: 1}");
    XCTAssertNil(dict);
}

@end
