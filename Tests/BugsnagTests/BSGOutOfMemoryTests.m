#import <XCTest/XCTest.h>

#import "BSGFileLocations.h"
#import "BSGRunContext.h"
#import "BSG_KSCrashState.h"
#import "BSG_KSSystemInfo.h"
#import "Bugsnag.h"
#import "BugsnagClient+Private.h"
#import "BugsnagConfiguration.h"
#import "BugsnagSystemState.h"
#import "BugsnagTestConstants.h"

@interface BSGOutOfMemoryTests : XCTestCase
@end

@implementation BSGOutOfMemoryTests

- (BugsnagClient *)newClient {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
//    config.autoDetectErrors = NO;
    config.releaseStage = @"MagicalTestingTime";

    BugsnagClient *client = [[BugsnagClient alloc] initWithConfiguration:config];
    [client start];
    return client;
}

/**
 * Test that the generated OOM report values exist and are correct (where that can be tested)
 */
- (void)testOOMFieldsSetCorrectly {
    BugsnagClient *client = [self newClient];
    BugsnagSystemState *systemState = [client systemState];

    client.codeBundleId = @"codeBundleIdHere";
    // The update happens on a bg thread, so let it run.
    [NSThread sleepForTimeInterval:0.01f];

    NSDictionary *state = systemState.currentLaunchState;
    XCTAssertNotNil([state objectForKey:@"app"]);
    XCTAssertNotNil([state objectForKey:@"device"]);
    
    NSDictionary *app = [state objectForKey:@"app"];
    XCTAssertNotNil([app objectForKey:@"bundleVersion"]);
    XCTAssertNotNil([app objectForKey:@"id"]);
    XCTAssertNotNil([app objectForKey:@"version"]);
    XCTAssertNotNil([app objectForKey:@"name"]);
    XCTAssertEqualObjects([app valueForKey:@"codeBundleId"], @"codeBundleIdHere");
    XCTAssertEqualObjects([app valueForKey:@"releaseStage"], @"MagicalTestingTime");
    
    NSDictionary *device = [state objectForKey:@"device"];
    XCTAssertNotNil([device objectForKey:@"osName"]);
    XCTAssertNotNil([device objectForKey:@"osBuild"]);
    XCTAssertNotNil([device objectForKey:@"osVersion"]);
    XCTAssertNotNil([device objectForKey:@"id"]);
    XCTAssertNotNil([device objectForKey:@"model"]);
    XCTAssertNotNil([device objectForKey:@"simulator"]);
    XCTAssertNotNil([device objectForKey:@"wordSize"]);
    XCTAssertEqualObjects([device valueForKey:@"locale"], [[NSLocale currentLocale] localeIdentifier]);
}

-(void)testBadJSONData {
    NSString *stateFilePath = [BSGFileLocations current].systemState;
    NSError* error;
    [@"{1=\"a\"" writeToFile:stateFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    XCTAssertNil(error);

    // Should not crash
    [self newClient];
}

- (void)testLastLaunchTerminatedUnexpectedly {
    const struct BSGRunContext *oldContext = bsg_lastRunContext;
    struct BSGRunContext lastRunContext = {0};
    bsg_lastRunContext = &lastRunContext;
    
    BugsnagSystemState *(^ systemState)() = ^{
        return [[BugsnagSystemState alloc] initWithConfiguration:[[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1]];
    };

    // Debugger active
    
    lastRunContext.isDebuggerAttached = true;
    lastRunContext.isTerminating = true;
    lastRunContext.isForeground = true;
    XCTAssertFalse(systemState().lastLaunchTerminatedUnexpectedly);

    lastRunContext.isDebuggerAttached = true;
    lastRunContext.isTerminating = true;
    lastRunContext.isForeground = false;
    XCTAssertFalse(systemState().lastLaunchTerminatedUnexpectedly);

    lastRunContext.isDebuggerAttached = true;
    lastRunContext.isTerminating = false;
    lastRunContext.isForeground = true;
    XCTAssertFalse(systemState().lastLaunchTerminatedUnexpectedly);

    lastRunContext.isDebuggerAttached = true;
    lastRunContext.isTerminating = false;
    lastRunContext.isForeground = false;
    XCTAssertFalse(systemState().lastLaunchTerminatedUnexpectedly);

    // Debugger inactive

    lastRunContext.isDebuggerAttached = false;
    lastRunContext.isTerminating = true;
    lastRunContext.isForeground = true;
    XCTAssertFalse(systemState().lastLaunchTerminatedUnexpectedly);

    lastRunContext.isDebuggerAttached = false;
    lastRunContext.isTerminating = true;
    lastRunContext.isForeground = false;
    XCTAssertFalse(systemState().lastLaunchTerminatedUnexpectedly);

    lastRunContext.isDebuggerAttached = false;
    lastRunContext.isTerminating = false;
    lastRunContext.isForeground = true;
    XCTAssertTrue(systemState().lastLaunchTerminatedUnexpectedly);

    lastRunContext.isDebuggerAttached = false;
    lastRunContext.isTerminating = false;
    lastRunContext.isForeground = false;
    XCTAssertFalse(systemState().lastLaunchTerminatedUnexpectedly);
    
    bsg_lastRunContext = oldContext;
}

@end
