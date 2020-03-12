//
//  BugsnagPluginTest.m
//  Tests
//
//  Created by Jamie Lynch on 12/03/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "BugsnagTestConstants.h"
#import "Bugsnag.h"
#import "BugsnagConfiguration.h"

@interface BugsnagPluginTest : XCTestCase

@end

@interface BugsnagConfiguration ()
@property(nonatomic, readwrite, strong) NSMutableSet *plugins;
@end

@interface FakePlugin: NSObject<BugsnagPlugin>
@property(nonatomic) BOOL loaded;
@end
@implementation FakePlugin
    - (void)load {
        self.loaded = true;
    }
    - (void)unload {}
@end

@implementation BugsnagPluginTest

- (void)testAddPlugin {
    id<BugsnagPlugin> plugin = [FakePlugin new];
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    [config addPlugin:plugin];
    XCTAssertEqual([config.plugins anyObject], plugin);
}

- (void)testPluginLoaded {
    FakePlugin *plugin = [FakePlugin new];
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1 error:nil];
    [config addPlugin:plugin];
    [Bugsnag startBugsnagWithConfiguration:config];
    XCTAssertTrue(plugin.loaded);
}
@end
